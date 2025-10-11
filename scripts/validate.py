#!/usr/bin/env python3
"""
Simple Terraform validation script.

Usage: python simple_validate.py <environment>
Example: python simple_validate.py dev
"""

import sys
import argparse
from terraform_manager import TerraformManager
from environment import VALID_ENVIRONMENTS, ExecutionEnvironment
from utils import log_step


def main() -> None:
    """Main entry point for validation script."""
    parser = argparse.ArgumentParser(description="Validate Terraform configuration")
    parser.add_argument(
        "environment",
        choices=VALID_ENVIRONMENTS,
        help=f"Environment to validate ({', '.join(VALID_ENVIRONMENTS)})",
    )

    args = parser.parse_args()

    # Show environment context information
    env = ExecutionEnvironment()
    log_step(f"Validation Environment: {env.get_environment_info()}")

    # Create manager and run validation
    manager = TerraformManager(args.environment)

    if manager.validate_prerequisites(args.environment):
        print("\n[SUCCESS] Validation completed successfully!")
        sys.exit(0)
    else:
        print("\n[FAILED] Validation failed!")

        # Provide context-specific troubleshooting tips
        from environment import ExecutionContext

        if env.context == ExecutionContext.NATIVE:
            print("\n[INFO] Troubleshooting tips:")
            print("  - Ensure AWS credentials are configured: aws configure")
            print("  - Check Terraform installation: terraform --version")
            print("  - Verify network connectivity to AWS")
        elif env.context == ExecutionContext.CI:
            print("\n[INFO] CI troubleshooting:")
            print("  - Check AWS credentials in secrets")
            print("  - Verify workflow environment variables")

        sys.exit(1)


if __name__ == "__main__":
    main()
