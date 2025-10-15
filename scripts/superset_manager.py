#!/usr/bin/env python3
"""
Superset management script for Docker operations.
Handles build, push, and deployment operations for Superset Docker images.
"""

import sys
import argparse

from utils import log_info, log_success, log_error, log_step, run_command
from environment import ExecutionEnvironment


# Initialize environment
env = ExecutionEnvironment()


def get_terraform_output(name: str) -> str:
    """Get terraform output value by name."""
    success, stdout, _ = run_command(["terraform", "output", "-raw", name], cwd=env.root_dir)

    if success and stdout:
        output = stdout.strip()
        # Filter out terraform warnings
        if "Warning" not in output and "\x1b" not in output and "│" not in output:
            return output
    return ""


def build(environment: str) -> int:
    """Build the Superset Docker image."""
    log_step(f"Building Superset Docker image for {environment} environment...")

    image_name = f"ellen-young-yt-{environment}-superset:latest"
    superset_dir = env.root_dir / "superset"

    success = run_command(
        ["docker", "build", "-t", image_name, "."], cwd=superset_dir, capture=False, simple=True
    )

    if success:
        log_success(f"Image built successfully: {image_name}")
        return 0
    else:
        log_error("Failed to build image")
        return 1


def push(environment: str) -> int:
    """Push the Superset Docker image to ECR."""
    log_step(f"Pushing Superset Docker image for {environment} environment...")

    image_name = f"ellen-young-yt-{environment}-superset:latest"

    ecr_url = get_terraform_output("superset_ecr_repository_url")
    if not ecr_url:
        log_error("ECR repository URL not found. Be sure to deploy infrastructure first")
        return 1

    log_info(f"ECR URL: {ecr_url}")

    # Authenticate to ECR
    log_info("Authenticating to ECR...")
    success, password, _ = run_command(
        ["aws", "ecr", "get-login-password", "--region", "us-east-2"], cwd=env.root_dir
    )

    if not success or not password:
        log_error("Failed to get ECR login password")
        return 1

    # Docker login with password via stdin
    success = run_command(
        ["docker", "login", "--username", "AWS", "--password-stdin", ecr_url],
        cwd=env.root_dir,
        capture=True,
        simple=True,
        stdin_input=password.strip(),
    )

    if not success:
        log_error("ECR authentication failed")
        return 1

    log_success("Authenticated to ECR")

    # Tag image
    log_info("Tagging image...")
    success = run_command(
        ["docker", "tag", image_name, f"{ecr_url}:latest"], cwd=env.root_dir, simple=True
    )

    if not success:
        log_error("Failed to tag image")
        return 1

    # Push image
    log_info("Pushing image to ECR...")
    success = run_command(
        ["docker", "push", f"{ecr_url}:latest"], cwd=env.root_dir, capture=False, simple=True
    )

    if success:
        log_success("Image pushed successfully!")
        return 0
    else:
        log_error("Failed to push image")
        return 1


def deploy(environment: str) -> int:
    """Deploy the Superset service to ECS (force new deployment)."""
    log_step(f"Deploying Superset service for {environment} environment...")

    service_name = f"ellen-young-yt-{environment}-superset"

    # Get cluster ARN and extract cluster name
    cluster_arn = get_terraform_output("superset_cluster_arn")
    if not cluster_arn:
        log_error(
            f"Cluster ARN not found. Deploy infrastructure first: make apply ENV={environment}"
        )
        return 1

    # Extract cluster name from ARN (last part after the final '/')
    cluster_name = cluster_arn.split("/")[-1]
    log_info(f"Cluster: {cluster_name}")
    log_info(f"Service: {service_name}")

    # Force ECS service to redeploy
    log_info("Forcing ECS service to redeploy with new image...")
    success = run_command(
        [
            "aws",
            "ecs",
            "update-service",
            "--cluster",
            cluster_name,
            "--service",
            service_name,
            "--force-new-deployment",
        ],
        cwd=env.root_dir,
        simple=True,
    )

    if success:
        log_success("Deployment triggered!")
        log_info(f"Monitor with: make superset-logs ENV={environment}")
        return 0
    else:
        log_error("Failed to update service")
        return 1


def main() -> None:
    """Main entry point with argument parsing."""
    parser = argparse.ArgumentParser(
        description="Manage Superset Docker images and deployments",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python superset_manager.py build dev
  python superset_manager.py push dev
  python superset_manager.py deploy dev
  python superset_manager.py build dev --then push
  python superset_manager.py build dev --then push --then deploy
        """,
    )

    parser.add_argument("action", choices=["build", "push", "deploy"], help="Action to perform")

    parser.add_argument("environment", help="Environment (e.g., dev, staging, prod)")

    parser.add_argument(
        "--then",
        action="append",
        choices=["build", "push", "deploy"],
        help="Additional actions to perform in sequence (can be used multiple times)",
    )

    args = parser.parse_args()

    # Build the list of actions to execute
    actions = [args.action]
    if args.then:
        actions.extend(args.then)

    # Execute each action in sequence
    for action in actions:
        if action == "build":
            result = build(args.environment)
        elif action == "push":
            result = push(args.environment)
        elif action == "deploy":
            result = deploy(args.environment)
        else:
            log_error(f"Unknown action: {action}")
            sys.exit(1)

        # If any action fails, stop execution
        if result != 0:
            log_error(f"Action '{action}' failed, stopping execution")
            sys.exit(result)

    log_success("All operations completed successfully!")


if __name__ == "__main__":
    main()
