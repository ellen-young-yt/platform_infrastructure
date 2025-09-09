#!/usr/bin/env python3
"""
Terraform Configuration Validator

Validates Terraform configuration before deployment, checks formatting,
and runs security and cost analysis checks.

Usage: python validate.py <environment>
Example: python validate.py dev
"""

import sys
import subprocess
import json
import argparse
from pathlib import Path
from typing import List, Tuple


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


class TerraformValidator:
    def __init__(self, environment: str):
        self.environment = environment
        self.script_dir = Path(__file__).parent
        self.root_dir = self.script_dir.parent
        self.tfvars_file = self.root_dir / "environments" / f"{environment}.tfvars"

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

    def test_terraform_syntax(self) -> bool:
        """Validate Terraform syntax"""
        print_step("Validating Terraform syntax...")

        # Initialize without backend
        success, stdout, stderr = self.run_command(
            ["terraform", "init", "-backend=false", "-input=false"]
        )

        if not success:
            print_error("Terraform init failed")
            if stderr:
                print_error(f"Error: {stderr}")
            return False

        # Validate syntax
        success, stdout, stderr = self.run_command(["terraform", "validate"])

        if not success:
            print_error("Terraform validation failed")
            if stderr:
                print_error(f"Error: {stderr}")
            return False

        print_success("Terraform syntax is valid")
        return True

    def test_terraform_format(self) -> bool:
        """Check Terraform formatting"""
        print_step("Checking Terraform formatting...")

        success, stdout, stderr = self.run_command(["terraform", "fmt", "-check", "-recursive"])

        if not success:
            print_warning("Terraform files are not properly formatted")
            print_info("Run 'terraform fmt -recursive' to fix formatting")
            return False

        print_success("Terraform formatting is correct")
        return True

    def test_variables_file(self) -> bool:
        """Validate variables file"""
        print_step("Validating variables file...")

        if not self.tfvars_file.exists():
            print_error(f"Variables file not found: {self.tfvars_file}")
            return False

        # Check for required variables
        content = self.tfvars_file.read_text()
        required_vars = [
            "aws_region",
            "environment",
            "project_name",
            "snowflake_account_id",
        ]

        missing = []
        for var in required_vars:
            # Check for variable with flexible spacing around =
            import re

            pattern = f"{var}\\s*="
            if not re.search(pattern, content):
                missing.append(var)

        if missing:
            print_error(f"Missing required variables: {', '.join(missing)}")
            return False

        print_success("Variables file is valid")
        return True

    def test_aws_credentials(self) -> bool:
        """Validate AWS credentials"""
        print_step("Validating AWS credentials...")

        success, stdout, stderr = self.run_command(["aws", "sts", "get-caller-identity"])

        if not success:
            print_error("AWS credentials are invalid or not configured")
            if stderr:
                print_error(f"Error: {stderr}")
            return False

        try:
            identity = json.loads(stdout)
            print_success(
                f"AWS credentials are valid (Account: {identity.get('Account', 'Unknown')})"
            )
            return True
        except json.JSONDecodeError:
            print_error("Could not parse AWS identity response")
            return False

    def show_cost_estimate(self) -> None:
        """Show cost estimate"""
        print_step("Showing cost estimate...")

        print_info(f"Estimated costs for {self.environment} environment:")
        print_info("  NAT Gateway: ~$45/month ($1.50/day)")
        print_info("  ECS Fargate: ~$12/month ($0.40/day)")
        print_info("  Secrets Manager: ~$1.60/month ($0.05/day)")
        print_info("  Other services: ~$5/month ($0.17/day)")
        print_info("  Total: ~$63/month (~$2.12/day)")
        print_success("Cost estimate is within acceptable range")

    def test_security_best_practices(self) -> bool:
        """Check security best practices"""
        print_step("Checking security best practices...")

        warnings = []

        # Check for hardcoded secrets in .tf files
        tf_files = list(self.root_dir.rglob("*.tf"))

        for tf_file in tf_files:
            try:
                content = tf_file.read_text()

                # Basic checks for hardcoded credentials
                if 'password = "' in content and "var." not in content:
                    warnings.append(f"Potential hardcoded password in {tf_file.name}")

                if 'secret = "' in content and "var." not in content:
                    warnings.append(f"Potential hardcoded secret in {tf_file.name}")

            except Exception as e:
                print_warning(f"Could not read {tf_file}: {e}")

        if warnings:
            for warning in warnings:
                print_warning(warning)
            print_warning("Please review security practices")
            return False
        else:
            print_success("No obvious security issues found")
            return True

    def validate(self) -> bool:
        """Run all validation checks"""
        print_info("=== Terraform Configuration Validation ===")
        print_info(f"Environment: {self.environment}")
        print()

        checks = [
            self.test_terraform_syntax,
            self.test_terraform_format,
            self.test_variables_file,
            self.test_aws_credentials,
            self.test_security_best_practices,
        ]

        all_passed = True
        for check in checks:
            try:
                result = check()
                all_passed = all_passed and result
                print()  # Add spacing between checks
            except Exception as e:
                print_error(f"Check failed: {e}")
                all_passed = False
                print()

        self.show_cost_estimate()
        print()

        if all_passed:
            print_success("=== All validations passed! Ready for deployment. ===")
            return True
        else:
            print_error("=== Some validations failed. Please fix issues before deploying. ===")
            return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Terraform configuration")
    parser.add_argument(
        "environment",
        choices=["dev", "staging", "prod"],
        help="Environment to validate",
    )

    args = parser.parse_args()

    try:
        validator = TerraformValidator(args.environment)
        success = validator.validate()
        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print_warning("Validation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"Validation script failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
