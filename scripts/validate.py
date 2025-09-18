#!/usr/bin/env python3
"""
Simple Terraform validation script.

Usage: python simple_validate.py <environment>
Example: python simple_validate.py dev
"""

import sys
import argparse
from terraform_manager import TerraformManager
from environment import VALID_ENVIRONMENTS


def main() -> None:
    """Main entry point for validation script."""
    parser = argparse.ArgumentParser(description="Validate Terraform configuration")
    parser.add_argument(
        "environment",
        choices=VALID_ENVIRONMENTS,
        help=f"Environment to validate ({', '.join(VALID_ENVIRONMENTS)})",
    )

    args = parser.parse_args()

    # Create manager and run validation
    manager = TerraformManager(args.environment)

    if manager.validate_prerequisites(args.environment):
        print("\nValidation completed successfully!")
        sys.exit(0)
    else:
        print("\nValidation failed!")
        sys.exit(1)


if __name__ == "__main__":
    main()
