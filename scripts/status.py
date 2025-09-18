#!/usr/bin/env python3
"""
Simple Terraform status script.

Usage: python simple_status.py <environment>
Example: python simple_status.py dev
"""

import json
import argparse
from terraform_manager import TerraformManager
from environment import VALID_ENVIRONMENTS, ExecutionEnvironment, ExecutionContext
from utils import log_step


def main() -> None:
    """Main entry point for status script."""
    parser = argparse.ArgumentParser(description="Check Terraform infrastructure status")
    parser.add_argument(
        "environment",
        choices=VALID_ENVIRONMENTS,
        help=f"Environment to check ({', '.join(VALID_ENVIRONMENTS)})",
    )
    parser.add_argument("--json", action="store_true", help="Output status as JSON")

    args = parser.parse_args()

    # Show environment context information
    env = ExecutionEnvironment()

    # Create manager and get status
    manager = TerraformManager(args.environment)
    status = manager.get_infrastructure_status(args.environment)

    # Add environment context to status
    status["execution_environment"] = {
        "platform": env.platform.name.lower(),
        "context": env.context.name.lower(),
        "description": env.get_environment_info(),
    }

    # Context-aware output formatting
    if args.json or env.context == ExecutionContext.CI:
        # JSON output for CI or when explicitly requested
        print(json.dumps(status, indent=2))
    else:
        # Human-readable output for native environments
        log_step(f"Execution Environment: {env.get_environment_info()}")
        print(f"\n📊 Infrastructure Status for {args.environment}:")
        print(f"  🏗️  Workspace selected: {status.get('workspace_selected', 'Unknown')}")
        print(f"  📦 Resources: {len(status.get('resources', []))}")
        print(f"  🔧 Outputs: {len(status.get('outputs', {}))}")

        if status.get("resources"):
            print("  📋 Resource types:")
            resource_types = set()
            for resource in status["resources"]:
                resource_type = resource.split(".")[0] if "." in resource else resource
                resource_types.add(resource_type)
            for resource_type in sorted(resource_types):
                count = sum(1 for r in status["resources"] if r.startswith(resource_type + "."))
                print(f"    {resource_type}: {count}")

        if "error" in status:
            print(f"  ❌ Error: {status['error']}")

            # Context-specific troubleshooting
            if env.context == ExecutionContext.NATIVE:
                print("\n💡 Troubleshooting tips:")
                print("  - Ensure AWS credentials are configured")
                print("  - Check Terraform workspace initialization: make init")
                print("  - Verify network connectivity to AWS")


if __name__ == "__main__":
    main()
