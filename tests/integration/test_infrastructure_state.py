"""
Integration tests for deployed infrastructure.

These tests run against real AWS resources and require:
1. Valid AWS credentials
2. Infrastructure deployed in the target environment
3. ENV environment variable set

Run with: make test-integration ENV=dev
"""

import pytest
import boto3
import json
import sys
from pathlib import Path
from botocore.exceptions import ClientError, NoCredentialsError

# Add scripts directory to Python path for importing
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from environment import ExecutionContext  # noqa: E402


@pytest.mark.integration
class TestInfrastructureState:
    """Integration tests for infrastructure state."""

    @pytest.fixture(autouse=True)
    def setup_aws_client(self, environment, execution_environment):
        """Setup AWS clients for testing with context awareness."""
        try:
            self.env = execution_environment
            self.session = boto3.Session()
            self.s3_client = self.session.client("s3")
            self.iam_client = self.session.client("iam")
            self.ecs_client = self.session.client("ecs")
            self.sm_client = self.session.client("secretsmanager")
            self.ec2_client = self.session.client("ec2")

            # Verify credentials work
            identity = self.session.client("sts").get_caller_identity()

            # Log execution context for debugging
            print(f"Integration tests running in: {self.env.get_environment_info()}")
            print(f"AWS Account: {identity.get('Account', 'Unknown')}")

        except NoCredentialsError:
            if self.env.context == ExecutionContext.CI:
                pytest.skip("AWS credentials not configured in CI - check secrets configuration")
            else:
                pytest.skip("AWS credentials not configured - run 'aws configure'")
        except ClientError as e:
            if self.env.context == ExecutionContext.CI:
                pytest.skip(f"AWS credentials invalid in CI: {e}")
            else:
                pytest.skip(f"AWS credentials invalid - check 'aws configure': {e}")

    def test_s3_data_lake_bucket_exists(self, environment, test_project_name):
        """Test that the S3 data lake bucket exists and is accessible."""
        bucket_name = f"{test_project_name}-{environment}-data-lake"

        try:
            response = self.s3_client.head_bucket(Bucket=bucket_name)
            assert response["ResponseMetadata"]["HTTPStatusCode"] == 200

            # Test bucket location
            location = self.s3_client.get_bucket_location(Bucket=bucket_name)
            assert "LocationConstraint" in location

        except ClientError as e:
            if e.response["Error"]["Code"] == "404":
                pytest.fail(f"S3 bucket {bucket_name} does not exist")
            else:
                pytest.fail(f"Failed to access S3 bucket {bucket_name}: {e}")

    def test_s3_bucket_versioning_enabled(self, environment, test_project_name):
        """Test that S3 bucket has versioning enabled."""
        bucket_name = f"{test_project_name}-{environment}-data-lake"

        try:
            response = self.s3_client.get_bucket_versioning(Bucket=bucket_name)
            assert response.get("Status") == "Enabled", "S3 bucket versioning should be enabled"

        except ClientError as e:
            pytest.fail(f"Failed to get bucket versioning: {e}")

    def test_secrets_manager_secrets_exist(self, environment, test_project_name):
        """Test that required secrets exist in Secrets Manager."""
        required_secrets = [
            f"{test_project_name}/{environment}/snowflake/credentials",
            f"{test_project_name}/{environment}/redis/credentials",
        ]

        for secret_name in required_secrets:
            try:
                response = self.sm_client.describe_secret(SecretId=secret_name)
                assert response["Name"] == secret_name
                assert "CreatedDate" in response

            except ClientError as e:
                if e.response["Error"]["Code"] == "ResourceNotFoundException":
                    pytest.fail(f"Required secret {secret_name} does not exist")
                else:
                    pytest.fail(f"Failed to access secret {secret_name}: {e}")

    def test_iam_snowflake_role_exists(self, environment, test_project_name):
        """Test that the Snowflake IAM role exists."""
        role_name = f"{test_project_name}-{environment}-snowflake-role"

        try:
            response = self.iam_client.get_role(RoleName=role_name)
            assert response["Role"]["RoleName"] == role_name
            assert "AssumeRolePolicyDocument" in response["Role"]

            # Check that assume role policy allows Snowflake
            assume_policy = response["Role"]["AssumeRolePolicyDocument"]
            statements = assume_policy.get("Statement", [])

            snowflake_principal_found = False
            for statement in statements:
                principals = statement.get("Principal", {})
                if isinstance(principals, dict) and "AWS" in principals:
                    aws_principals = principals["AWS"]
                    if isinstance(aws_principals, str):
                        aws_principals = [aws_principals]
                    # Look for Snowflake account in principals
                    if any("703671920640" in principal for principal in aws_principals):
                        snowflake_principal_found = True
                        break

            assert snowflake_principal_found, "Snowflake should be allowed to assume the role"

        except ClientError as e:
            if e.response["Error"]["Code"] == "NoSuchEntity":
                pytest.fail(f"Snowflake IAM role {role_name} does not exist")
            else:
                pytest.fail(f"Failed to access IAM role {role_name}: {e}")

    def test_vpc_exists_and_configured(self, environment, test_project_name):
        """Test that VPC exists with correct configuration."""
        # Find VPC by name tag
        vpc_name = f"{test_project_name}-{environment}-vpc"

        try:
            response = self.ec2_client.describe_vpcs(
                Filters=[
                    {"Name": "tag:Name", "Values": [vpc_name]},
                    {"Name": "state", "Values": ["available"]},
                ]
            )

            vpcs = response.get("Vpcs", [])
            assert len(vpcs) == 1, f"Expected exactly one VPC named {vpc_name}, found {len(vpcs)}"

            vpc = vpcs[0]
            assert vpc["State"] == "available"

            # Check CIDR block is reasonable
            cidr_block = vpc["CidrBlock"]
            assert cidr_block.startswith(
                "10."
            ), f"VPC CIDR should be in private range, got {cidr_block}"

        except ClientError as e:
            pytest.fail(f"Failed to describe VPCs: {e}")

    def test_subnets_exist_in_multiple_azs(self, environment, test_project_name):
        """Test that subnets exist across multiple availability zones."""
        vpc_name = f"{test_project_name}-{environment}-vpc"

        try:
            # First get the VPC ID
            vpc_response = self.ec2_client.describe_vpcs(
                Filters=[{"Name": "tag:Name", "Values": [vpc_name]}]
            )

            if not vpc_response["Vpcs"]:
                pytest.skip(f"VPC {vpc_name} not found")

            vpc_id = vpc_response["Vpcs"][0]["VpcId"]

            # Get subnets in this VPC
            subnet_response = self.ec2_client.describe_subnets(
                Filters=[
                    {"Name": "vpc-id", "Values": [vpc_id]},
                    {"Name": "state", "Values": ["available"]},
                ]
            )

            subnets = subnet_response.get("Subnets", [])
            assert len(subnets) >= 3, f"Expected at least 3 subnets, found {len(subnets)}"

            # Check that subnets are in different AZs
            availability_zones = set(subnet["AvailabilityZone"] for subnet in subnets)
            assert (
                len(availability_zones) >= 2
            ), f"Subnets should be in multiple AZs, found: {availability_zones}"

            # Check for public subnets
            public_subnets = [s for s in subnets if s.get("MapPublicIpOnLaunch", False)]

            assert (
                len(public_subnets) >= 3
            ), f"Should have at least 3 public subnets, found {len(public_subnets)}"

        except ClientError as e:
            pytest.fail(f"Failed to describe subnets: {e}")

    @pytest.mark.slow
    def test_ecs_clusters_exist(self, environment, test_project_name):
        """Test that ECS clusters exist and are active."""
        expected_clusters = [
            f"{test_project_name}-{environment}-airflow",
            f"{test_project_name}-{environment}-superset",
        ]

        try:
            for cluster_name in expected_clusters:
                response = self.ecs_client.describe_clusters(clusters=[cluster_name])

                clusters = response.get("clusters", [])
                if not clusters:
                    pytest.fail(f"ECS cluster {cluster_name} not found")

                cluster = clusters[0]
                assert (
                    cluster["status"] == "ACTIVE"
                ), f"Cluster {cluster_name} should be ACTIVE, got {cluster['status']}"

        except ClientError as e:
            pytest.fail(f"Failed to describe ECS clusters: {e}")

    def test_terraform_state_accessibility(self, environment):
        """Test that Terraform state is accessible and valid."""

        # Skip in container environments where Terraform may not be properly configured
        if hasattr(self, "env") and self.env.context in (
            ExecutionContext.CONTAINER,
            ExecutionContext.CI,
        ):
            pytest.skip("Terraform state test skipped in container/CI environment")

        try:
            # Use environment-aware command execution
            from utils import run_command

            # Ensure we're in the correct terraform workspace
            workspace_success, _, workspace_stderr = run_command(
                ["terraform", "workspace", "select", environment], capture=True
            )
            if not workspace_success:
                pytest.fail(
                    f"Failed to select terraform workspace '{environment}': {workspace_stderr}"
                )

            # Run terraform show to validate state
            show_success, stdout, stderr = run_command(["terraform", "show", "-json"], capture=True)
            if not show_success:
                pytest.fail(f"Terraform show failed: {stderr}")

            state_data = json.loads(stdout)

            # Basic validation of state structure
            assert "values" in state_data, "Terraform state should contain values"

            root_module = state_data["values"].get("root_module", {})
            resources = root_module.get("resources", [])

            # Also check child modules for resources (common with modular Terraform)
            child_modules = root_module.get("child_modules", [])
            for child_module in child_modules:
                resources.extend(child_module.get("resources", []))

            assert len(resources) > 0, "Should have resources in Terraform state"

            # Check for key resource types
            resource_types = set(resource["type"] for resource in resources)
            expected_types = {
                "aws_vpc",
                "aws_s3_bucket",
                "aws_secretsmanager_secret",
            }

            found_types = expected_types.intersection(resource_types)
            assert (
                len(found_types) > 0
            ), f"Expected resource types {expected_types}, found {resource_types}"

        except json.JSONDecodeError:
            pytest.fail("Invalid JSON returned from terraform show")
        except FileNotFoundError:
            if hasattr(self, "env") and self.env.context == ExecutionContext.NATIVE:
                pytest.skip("Terraform not available - ensure it's installed")
            else:
                pytest.skip("Terraform not available in this environment")
        except Exception as e:
            if hasattr(self, "env") and self.env.context == ExecutionContext.NATIVE:
                pytest.fail(f"Terraform command failed: {e}")
            else:
                pytest.skip(f"Terraform test skipped due to environment limitations: {e}")
