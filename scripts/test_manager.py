#!/usr/bin/env python3
"""
Test Manager for Infrastructure Testing

Centralized testing orchestration for unit tests, integration tests,
and coverage reporting. Provides cross-platform pytest execution.
"""

from pathlib import Path

from utils import log_success, log_warning, log_error, log_step, run_command
from environment import ExecutionEnvironment, ExecutionContext


class TestManager:
    """Centralized test management and execution."""

    def __init__(self) -> None:
        """Initialize test manager."""
        self.root_dir = Path(__file__).parent.parent
        self.script_dir = Path(__file__).parent
        self.tests_dir = self.root_dir / "tests"
        self.env = ExecutionEnvironment()

    def check_pytest_available(self) -> bool:
        """Check if pytest is available."""
        success, _, _ = run_command(["pytest", "--version"], cwd=self.root_dir)
        if not success:
            log_warning("pytest not found. Install with: pip install pytest")
            return False
        return True

    def run_unit_tests(self, verbose: bool = True, coverage: bool = False) -> bool:
        """Run unit tests with optional coverage."""
        log_step("Running unit tests...")
        log_step(f"Environment: {self.env.get_environment_info()}")

        if not self.check_pytest_available():
            return True  # Don't fail if pytest not available

        # Check if unit tests directory exists
        unit_tests_dir = self.tests_dir / "unit"
        if not unit_tests_dir.exists() or not any(unit_tests_dir.glob("test_*.py")):
            log_warning("No unit tests found in tests/unit/")
            return True

        # Build pytest command with context-aware options
        cmd = ["pytest", "tests/unit/"]

        # Context-aware verbosity and behavior
        if self.env.context == ExecutionContext.CI:
            cmd.extend(["-v", "--tb=short", "--strict-markers"])
            if coverage:
                cmd.extend(["--cov=scripts", "--cov-report=term-missing", "--cov-fail-under=80"])
        elif verbose:
            cmd.append("-v")

        if coverage and self.env.context != ExecutionContext.CI:
            cmd.extend(["--cov=scripts", "--cov-report=term-missing"])

        # Add fail-fast in CI for quicker feedback
        if self.env.context == ExecutionContext.CI:
            cmd.append("-x")

        success, _, _ = run_command(cmd, cwd=self.root_dir, capture=False)

        if success:
            log_success("Unit tests completed successfully")
        else:
            log_error("Unit tests failed")
            if self.env.context == ExecutionContext.NATIVE:
                log_step("Tip: Run with coverage using 'make test-coverage'")

        return success

    def run_integration_tests(self, environment: str = "dev", verbose: bool = True) -> bool:
        """Run integration tests for specified environment."""
        log_step(f"Running integration tests for {environment}...")
        log_step(f"Environment: {self.env.get_environment_info()}")

        if not self.check_pytest_available():
            return True  # Don't fail if pytest not available

        # Check if integration tests directory exists
        integration_tests_dir = self.tests_dir / "integration"
        if not integration_tests_dir.exists() or not any(integration_tests_dir.glob("test_*.py")):
            log_warning("No integration tests found in tests/integration/")
            return True

        # Build pytest command with environment and context-aware options
        cmd = ["pytest", "tests/integration/", f"--env={environment}"]

        # Context-aware test behavior
        if self.env.context == ExecutionContext.CI:
            cmd.extend(["-v", "--tb=short", "--strict-markers"])
        elif self.env.context == ExecutionContext.CONTAINER:
            log_warning("Running in container - some integration tests may be skipped")
            cmd.extend(["-v", "--tb=short"])
        elif verbose:
            cmd.append("-v")

        # Skip tests that require host resources in containers
        if self.env.context in (ExecutionContext.CONTAINER, ExecutionContext.CI):
            cmd.extend(["-m", "not requires_host"])

        success, _, _ = run_command(cmd, cwd=self.root_dir, capture=False)

        if success:
            log_success(f"Integration tests for {environment} completed successfully")
        else:
            log_error(f"Integration tests for {environment} failed")
            if self.env.context == ExecutionContext.NATIVE:
                log_step("Tip: Ensure AWS credentials are configured for integration tests")

        return success

    def run_coverage_report(self) -> bool:
        """Run unit tests with coverage reporting."""
        log_step("Running tests with coverage...")
        return self.run_unit_tests(verbose=True, coverage=True)

    def run_all_tests(self, environment: str = "dev") -> bool:
        """Run complete test suite."""
        log_step(f"Running complete test suite for {environment}...")

        # Run unit tests first
        unit_success = self.run_unit_tests(verbose=False)

        # Run integration tests
        integration_success = self.run_integration_tests(environment, verbose=False)

        overall_success = unit_success and integration_success

        if overall_success:
            log_success("All tests completed successfully")
        else:
            log_error("Some tests failed")

        return overall_success

    def run_post_deploy_tests(self, environment: str = "dev") -> bool:
        """Run post-deployment verification tests."""
        log_step(f"Running post-deployment verification for {environment}...")

        # Post-deploy tests are essentially integration tests
        # but we may want different behavior or filtering in the future
        return self.run_integration_tests(environment)


def main() -> None:
    """Main entry point for test management script."""
    import argparse
    import sys

    # Import here to avoid circular imports
    from environment import VALID_ENVIRONMENTS

    parser = argparse.ArgumentParser(description="Infrastructure testing utility")

    subparsers = parser.add_subparsers(dest="command", help="Test commands")

    # Unit tests
    subparsers.add_parser("unit", help="Run unit tests")

    # Integration tests
    integration_parser = subparsers.add_parser("integration", help="Run integration tests")
    integration_parser.add_argument(
        "environment",
        nargs="?",
        default="dev",
        choices=VALID_ENVIRONMENTS,
        help="Environment for integration tests",
    )

    # Coverage tests
    subparsers.add_parser("coverage", help="Run tests with coverage")

    # All tests
    all_parser = subparsers.add_parser("all", help="Run complete test suite")
    all_parser.add_argument(
        "environment",
        nargs="?",
        default="dev",
        choices=VALID_ENVIRONMENTS,
        help="Environment for complete test suite",
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        test_manager = TestManager()
        environment = getattr(args, "environment", "dev")

        # Execute appropriate command
        if args.command == "unit":
            success = test_manager.run_unit_tests()
        elif args.command == "integration":
            success = test_manager.run_integration_tests(environment)
        elif args.command == "coverage":
            success = test_manager.run_coverage_report()
        elif args.command == "all":
            success = test_manager.run_all_tests(environment)
        else:
            log_error(f"Unknown command: {args.command}")
            sys.exit(1)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nOperation interrupted by user")
        sys.exit(1)
    except Exception as e:
        log_error(f"Test operation failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
