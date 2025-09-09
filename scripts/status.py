#!/usr/bin/env python3
"""
Infrastructure Status Checker

Shows the current status of deployed infrastructure, including resource counts,
costs, and access information.

Usage: python status.py <environment>
Example: python status.py dev
"""

import sys
import subprocess
import json
import argparse
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional
from collections import Counter


class Colors:
    """ANSI color codes for cross-platform colored output"""

    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BLUE = "\033[94m"
    RESET = "\033[0m"


def print_success(message: str) -> None:
    print(f"{Colors.GREEN}[SUCCESS]{Colors.RESET} {message}")


def print_error(message: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.RESET} {message}")


def print_warning(message: str) -> None:
    print(f"{Colors.YELLOW}[WARNING]{Colors.RESET} {message}")


def print_info(message: str) -> None:
    print(f"{Colors.CYAN}[INFO]{Colors.RESET} {message}")


def print_step(message: str) -> None:
    print(f"{Colors.BLUE}[STEP]{Colors.RESET} {message}")


class InfrastructureStatus:
    def __init__(self, environment: str):
        self.environment = environment
        self.script_dir = Path(__file__).parent
        self.root_dir = self.script_dir.parent
        self.tfvars_file = self.root_dir / f"{environment}.tfvars"

    def run_command(self, cmd: List[str], cwd: Path | None = None) -> Tuple[bool, str, str]:
        """Run a command and return success, stdout, stderr"""
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd or self.root_dir,
                capture_output=True,
                text=True,
                check=False,
            )
            return result.returncode == 0, result.stdout, result.stderr
        except FileNotFoundError:
            return False, "", f"Command not found: {cmd[0]}"

    def get_terraform_state(self) -> Optional[List[str]]:
        """Get list of resources from Terraform state"""
        print_step("Checking Terraform state...")

        # Check if state file exists
        state_file = self.root_dir / "terraform.tfstate"
        if not state_file.exists():
            print_warning("No Terraform state found - infrastructure not deployed")
            return None

        # Get state list
        success, stdout, stderr = self.run_command(["terraform", "state", "list"])

        if not success:
            print_warning("Could not read Terraform state")
            if stderr:
                print_warning(f"Error: {stderr}")
            return None

        resources = [line.strip() for line in stdout.strip().split("\n") if line.strip()]
        return resources

    def show_resource_counts(self, resources: List[str]) -> None:
        """Show summary of resource counts by type"""
        if not resources:
            print_warning("No resources found")
            return

        print_step("Resource Summary:")

        # Count resources by type
        resource_types = []
        for resource in resources:
            if "." in resource:
                resource_type = resource.split(".")[0]
                resource_types.append(resource_type)

        counts = Counter(resource_types)

        for resource_type in sorted(counts.keys()):
            print_info(f"  {resource_type}: {counts[resource_type]}")

        print_info(f"  Total resources: {len(resources)}")

    def get_terraform_outputs(self) -> Dict[str, Any]:
        """Get Terraform outputs"""
        print_step("Getting Terraform outputs...")

        success, stdout, stderr = self.run_command(["terraform", "output", "-json"])

        if not success:
            print_warning("Could not get Terraform outputs")
            if stderr:
                print_warning(f"Error: {stderr}")
            return {"error": stderr or "Could not get Terraform outputs"}

        try:
            result = json.loads(stdout)
            return result if isinstance(result, dict) else {}
        except json.JSONDecodeError as e:
            print_warning(f"Could not parse Terraform outputs: {e}")
            return {"error": str(e)}

    def show_access_information(self, outputs: Dict[str, Any]) -> None:
        """Show access information from outputs"""
        if not outputs or "error" in outputs:
            print_warning("No outputs available")
            return

        print_step("Access Information:")

        for key in sorted(outputs.keys()):
            output = outputs[key]
            if isinstance(output, dict) and output.get("sensitive"):
                print_info(f"  {key}: <sensitive>")
            else:
                value = output.get("value") if isinstance(output, dict) else output

                # Truncate long values
                if isinstance(value, str) and len(value) > 80:
                    print_info(f"  {key}: {value[:77]}...")
                else:
                    print_info(f"  {key}: {value}")

    def show_cost_estimate(self) -> None:
        """Show current cost estimate"""
        print_step("Current cost estimate...")

        print_info("Estimated daily costs for active resources:")
        print_info("  NAT Gateway: ~$1.50/day")
        print_info("  ECS Fargate (if running): ~$0.40/day")
        print_info("  Secrets Manager: ~$0.05/day")
        print_info("  Other services: ~$0.17/day")
        print_info("  Estimated total: ~$2.12/day")
        print()
        print_warning("Remember to destroy resources when not needed!")

    def show_quick_commands(self) -> None:
        """Show helpful commands"""
        print_step("Quick commands:")

        print_info(f"Deploy/Update: python scripts/deploy.py apply {self.environment}")
        print_info(f"Plan changes: python scripts/deploy.py plan {self.environment}")
        print_info(f"Destroy all: python scripts/deploy.py destroy {self.environment}")
        print_info(f"Validate config: python scripts/validate.py {self.environment}")

        if self.environment == "dev":
            print_info("")
            print_info("Access Metabase (dev): Use ECS port forwarding (see outputs)")
            print_info("Access Airflow: Check ECS service in AWS Console")

    def show_status(self) -> None:
        """Show complete infrastructure status"""
        print_info("=== Infrastructure Status ===")
        print_info(f"Environment: {self.environment}")
        print()

        resources = self.get_terraform_state()

        if resources:
            print_success("Infrastructure is deployed")
            print()
            self.show_resource_counts(resources)
            print()

            outputs = self.get_terraform_outputs()
            self.show_access_information(outputs)
            print()

            self.show_cost_estimate()
        else:
            print_warning("Infrastructure is not deployed")
            print_info(
                f"Run deployment script to deploy: "
                f"python scripts/deploy.py apply {self.environment}"
            )

        print()
        self.show_quick_commands()


def main() -> None:
    parser = argparse.ArgumentParser(description="Show infrastructure status")
    parser.add_argument(
        "environment",
        choices=["dev", "staging", "prod"],
        help="Environment to check",
    )

    args = parser.parse_args()

    try:
        status_checker = InfrastructureStatus(args.environment)
        status_checker.show_status()

    except KeyboardInterrupt:
        print_warning("Status check interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"Status check failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
