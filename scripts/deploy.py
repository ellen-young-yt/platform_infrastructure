#!/usr/bin/env python3
"""
Simple Terraform deployment script.

Usage: python simple_deploy.py <environment> [--auto-approve] [--skip-validation]
Example: python simple_deploy.py dev
"""

import sys
import argparse
from terraform_manager import TerraformManager
from environment import VALID_ENVIRONMENTS


def main() -> None:
    """Main entry point for deployment script."""
    parser = argparse.ArgumentParser(description="Deploy Terraform infrastructure")
    parser.add_argument(
        "environment",
        choices=VALID_ENVIRONMENTS,
        help=f"Environment to deploy ({', '.join(VALID_ENVIRONMENTS)})",
    )
    parser.add_argument("--auto-approve", action="store_true", help="Skip confirmation prompts")
    parser.add_argument(
        "--skip-validation", action="store_true", help="Skip prerequisite validation"
    )
    parser.add_argument(
        "--destroy", action="store_true", help="Destroy infrastructure instead of deploying"
    )

    args = parser.parse_args()

    # Create manager
    manager = TerraformManager(args.environment)

    if args.destroy:
        success = manager.destroy_infrastructure(args.environment, confirm=args.auto_approve)
    else:
        success = manager.deploy_infrastructure(
            args.environment, auto_approve=args.auto_approve, skip_validation=args.skip_validation
        )

    if success:
        print("\nOperation completed successfully!")
        sys.exit(0)
    else:
        print("\nOperation failed!")
        sys.exit(1)


if __name__ == "__main__":
    main()
