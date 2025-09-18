"""
Pytest configuration and shared fixtures for infrastructure tests.
"""

import sys
import pytest
from pathlib import Path

# Add scripts directory to Python path for importing
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from environment import ExecutionEnvironment, ExecutionContext  # noqa: E402


@pytest.fixture
def project_root():
    """Get the project root directory."""
    return Path(__file__).parent.parent


@pytest.fixture
def scripts_dir(project_root):
    """Get the scripts directory."""
    return project_root / "scripts"


@pytest.fixture
def test_environment():
    """Default test environment."""
    return "dev"


@pytest.fixture
def test_project_name():
    """Default test project name."""
    return "ellen-young-yt"


@pytest.fixture
def mock_aws_region():
    """Mock AWS region for testing."""
    return "us-east-2"


@pytest.fixture
def execution_environment():
    """Get ExecutionEnvironment instance for testing."""
    return ExecutionEnvironment()


@pytest.fixture
def is_ci_environment(execution_environment):
    """Check if running in CI environment."""
    return execution_environment.context == ExecutionContext.CI


@pytest.fixture
def is_container_environment(execution_environment):
    """Check if running in container environment."""
    return execution_environment.context in (ExecutionContext.CONTAINER, ExecutionContext.CI)


@pytest.fixture
def sample_terraform_outputs():
    """Sample Terraform outputs for testing."""
    return {
        "vpc_id": {"value": "vpc-123456"},
        "vpc_cidr_block": {"value": "10.0.0.0/16"},
        "private_subnet_ids": {"value": ["subnet-123", "subnet-456"]},
        "public_subnet_ids": {"value": ["subnet-789", "subnet-abc"]},
        "data_lake_bucket_id": {"value": "test-bucket"},
        "api_gateway_url": {"value": "https://api.example.com/dev"},
    }


def pytest_addoption(parser):
    """Add custom command line options."""
    parser.addoption(
        "--env",
        action="store",
        default="dev",
        help="Environment to run integration tests against",
    )


@pytest.fixture
def environment(request):
    """Get environment from command line or use default."""
    return request.config.getoption("--env")


# Configure pytest to run unit tests by default, integration tests only when explicitly requested
def pytest_collection_modifyitems(config, items):
    """Modify test collection based on directory and execution environment."""
    env = ExecutionEnvironment()

    if config.getoption("--env") or "integration" in config.invocation_params.dir.name:
        # Running integration tests explicitly
        return

    # Filter out integration tests by default
    integration_tests = []
    unit_tests = []

    for item in items:
        if "integration" in str(item.fspath):
            integration_tests.append(item)
        else:
            unit_tests.append(item)

    # Skip integration tests in CI unless explicitly requested
    if env.context == ExecutionContext.CI and not config.getoption("--env"):
        items[:] = unit_tests
    # Only modify if we're running from root and didn't specify integration
    elif not config.getoption("--env") and integration_tests:
        items[:] = unit_tests
