"""
Unit tests for the ECS-DBT Terraform module.
"""

import pytest
import re


class TestECSDbtModule:
    """Test cases for ECS-DBT module Terraform configuration."""

    @pytest.fixture
    def module_path(self, project_root):
        """Path to ECS-DBT module."""
        return project_root / "modules" / "ecs-dbt"

    @pytest.fixture
    def main_tf_path(self, module_path):
        """Path to main.tf file."""
        return module_path / "main.tf"

    @pytest.fixture
    def variables_tf_path(self, module_path):
        """Path to variables.tf file."""
        return module_path / "variables.tf"

    @pytest.fixture
    def outputs_tf_path(self, module_path):
        """Path to outputs.tf file."""
        return module_path / "outputs.tf"

    def test_ecs_dbt_module_files_exist(
        self, module_path, main_tf_path, variables_tf_path, outputs_tf_path
    ):
        """Test that all required ECS-DBT module files exist."""
        assert module_path.exists(), "ECS-DBT module directory should exist"
        assert main_tf_path.exists(), "main.tf should exist in ECS-DBT module"
        assert variables_tf_path.exists(), "variables.tf should exist in ECS-DBT module"
        assert outputs_tf_path.exists(), "outputs.tf should exist in ECS-DBT module"

    def test_ecs_dbt_main_tf_content(self, main_tf_path):
        """Test that main.tf contains required ECS resources."""
        content = main_tf_path.read_text()

        # Check for ECS cluster
        assert 'resource "aws_ecs_cluster" "dbt"' in content
        assert "containerInsights" in content
        assert 'var.environment == "prod" ? "enabled" : "disabled"' in content

        # Check for capacity providers
        assert 'resource "aws_ecs_cluster_capacity_providers" "dbt"' in content
        assert 'capacity_providers = ["FARGATE", "FARGATE_SPOT"]' in content

        # Check for task definition
        assert 'resource "aws_ecs_task_definition" "dbt"' in content
        assert 'requires_compatibilities = ["FARGATE"]' in content

    def test_ecs_dbt_task_definition_configuration(self, main_tf_path):
        """Test ECS task definition is properly configured."""
        content = main_tf_path.read_text()

        # Check task configuration with flexible spacing
        assert re.search(r'network_mode\s*=\s*"awsvpc"', content)
        assert re.search(r"cpu\s*=\s*var.task_cpu", content)
        assert re.search(r"memory\s*=\s*var.task_memory", content)
        assert re.search(r"execution_role_arn\s*=\s*var.execution_role_arn", content)
        assert re.search(r"task_role_arn\s*=\s*var.task_role_arn", content)

        # Check container configuration with flexible spacing
        assert re.search(r"name\s*=\s*var.container_name", content)
        assert re.search(r"image\s*=\s*var.image_uri", content)
        assert re.search(r"essential\s*=\s*true", content)

    def test_ecs_dbt_secrets_configuration(self, main_tf_path):
        """Test ECS task secrets are properly configured."""
        content = main_tf_path.read_text()

        # Check secrets configuration
        assert "secrets = [" in content
        assert re.search(r'name\s*=\s*"SNOWFLAKE_CREDENTIALS"', content)
        assert re.search(r"valueFrom\s*=\s*var.database_secret_name", content)
        assert re.search(r'name\s*=\s*"DBT_PROFILES_CONFIG"', content)
        assert re.search(r"valueFrom\s*=\s*var.app_config_secret_name", content)
        assert re.search(r'name\s*=\s*"API_KEYS"', content)
        assert re.search(r"valueFrom\s*=\s*var.api_keys_secret_name", content)

    def test_ecs_dbt_logging_configuration(self, main_tf_path):
        """Test ECS logging is properly configured."""
        content = main_tf_path.read_text()

        # Check CloudWatch logging
        assert "logConfiguration = {" in content
        assert 'logDriver = "awslogs"' in content
        assert re.search(r'"awslogs-group"\s*=\s*local.log_group_name', content)
        assert re.search(r'"awslogs-region"\s*=\s*data.aws_region.current.name', content)
        assert re.search(r'"awslogs-stream-prefix"\s*=\s*"ecs"', content)

    def test_ecs_dbt_variables_tf_content(self, variables_tf_path):
        """Test that variables.tf contains required variables."""
        content = variables_tf_path.read_text()

        # Check for required variables
        assert 'variable "service_name"' in content
        assert 'variable "container_name"' in content
        assert 'variable "environment"' in content
        assert 'variable "project_name"' in content
        assert 'variable "image_uri"' in content
        assert 'variable "task_cpu"' in content
        assert 'variable "task_memory"' in content
        assert 'variable "execution_role_arn"' in content
        assert 'variable "task_role_arn"' in content

    def test_ecs_dbt_outputs_tf_content(self, outputs_tf_path):
        """Test that outputs.tf contains required outputs."""
        content = outputs_tf_path.read_text()

        # Check for required outputs
        assert 'output "cluster_name"' in content
        assert 'output "cluster_arn"' in content
        assert 'output "task_definition_arn"' in content

    def test_ecs_dbt_naming_convention(self, main_tf_path):
        """Test ECS resources follow naming convention."""
        content = main_tf_path.read_text()

        # Check cluster naming
        assert re.search(
            r'name\s*=\s*"\$\{var\.project_name\}-\$\{var\.environment\}-dbt"', content
        )
        # Check task definition family naming - make space-agnostic
        assert re.search(r'family\s*=\s*"\$\{var\.service_name\}-\$\{var\.environment\}"', content)

    def test_ecs_dbt_capacity_providers(self, main_tf_path):
        """Test ECS capacity providers are properly configured."""
        content = main_tf_path.read_text()

        # Check capacity provider strategy
        assert "default_capacity_provider_strategy {" in content
        assert re.search(r"base\s*=\s*1", content)
        assert re.search(r"weight\s*=\s*100", content)
        assert re.search(r'capacity_provider\s*=\s*"FARGATE"', content)

    def test_ecs_dbt_environment_variables(self, main_tf_path):
        """Test environment variables are properly configured."""
        content = main_tf_path.read_text()

        # Check environment variables configuration - structural patterns (keep as-is)
        assert "environment = [" in content
        assert "for key, value in var.environment_variables" in content

        # Check assignment patterns - make space-agnostic
        assert re.search(r"name\s*=\s*key", content)
        assert re.search(r"value\s*=\s*value", content)
