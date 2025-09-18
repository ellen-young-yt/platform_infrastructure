#!/usr/bin/env python3
"""
Simple management utility for common tasks.

Usage: python simple_manage.py <command>
"""

import sys
import argparse
from terraform_manager import TerraformManager
from environment import VALID_ENVIRONMENTS, environment
from utils import setup_environment, format_all, lint_all, generate_docs, log_error, log_info


def main() -> None:
    """Main entry point for management script."""
    parser = argparse.ArgumentParser(description="Infrastructure management utility")

    subparsers = parser.add_subparsers(dest="command", help="Management commands")

    # Infrastructure operations
    plan_parser = subparsers.add_parser("plan", help="Create Terraform execution plan")
    plan_parser.add_argument(
        "environment",
        nargs="?",
        default="dev",
        choices=VALID_ENVIRONMENTS,
        help="Environment to plan",
    )

    init_parser = subparsers.add_parser("init", help="Initialize Terraform")
    init_parser.add_argument(
        "environment",
        nargs="?",
        default="dev",
        choices=VALID_ENVIRONMENTS,
        help="Environment to initialize",
    )
    init_parser.add_argument(
        "--no-workspace",
        action="store_true",
        help="Skip workspace selection after initialization",
    )

    # Security scan
    subparsers.add_parser("security-scan", help="Run security scanning")

    # AWS check
    subparsers.add_parser("check-aws", help="Check AWS credentials")

    # Clean
    subparsers.add_parser("clean", help="Clean temporary files")

    # Format
    subparsers.add_parser("format", help="Format code")

    # Lint
    subparsers.add_parser("lint", help="Lint code")

    # Setup
    setup_parser = subparsers.add_parser("setup", help="Setup development environment")
    setup_parser.add_argument("--clean", action="store_true", help="Clean existing environment")

    # Docs
    subparsers.add_parser("docs", help="Generate documentation")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        # Get environment for commands that need it
        env_name = getattr(args, "environment", "dev")
        manager = TerraformManager(env_name)

        # Execute appropriate command
        if args.command == "plan":
            log_info(f"Creating Terraform plan for {env_name}...")
            # Only generate plan file in CI context (needed for deployment workflow)
            from environment import ExecutionContext

            plan_file = f"{env_name}.tfplan" if environment.context == ExecutionContext.CI else None
            success = (
                manager.terraform_init(env_name)
                and manager.select_terraform_workspace(env_name)
                and manager.terraform_plan(env_name, plan_file)
            )

        elif args.command == "init":
            log_info(f"Initializing Terraform for {env_name}...")
            select_workspace = not args.no_workspace
            success = manager.terraform_init(env_name, select_workspace=select_workspace)

        elif args.command == "security-scan":
            success = manager.security_scan()
        elif args.command == "check-aws":
            success = manager.validate_aws_credentials()
        elif args.command == "clean":
            success = manager.clean_temporary_files()
        elif args.command == "format":
            success = format_all()
        elif args.command == "lint":
            success = lint_all()
        elif args.command == "setup":
            success = setup_environment(args.clean)
        elif args.command == "docs":
            success = generate_docs()
        else:
            log_error(f"Unknown command: {args.command}")
            sys.exit(1)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nOperation interrupted by user")
        sys.exit(1)
    except Exception as e:
        log_error(f"Operation failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
