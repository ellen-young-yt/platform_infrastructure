"""
Unit tests for the IAM Terraform module.
"""

import pytest
import re


class TestIAMModule:
    """Test cases for IAM module Terraform configuration."""

    @pytest.fixture
    def module_path(self, project_root):
        """Path to IAM module."""
        return project_root / "modules" / "iam"

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

    def test_iam_module_files_exist(
        self, module_path, main_tf_path, variables_tf_path, outputs_tf_path
    ):
        """Test that all required IAM module files exist."""
        assert module_path.exists(), "IAM module directory should exist"
        assert main_tf_path.exists(), "main.tf should exist in IAM module"
        assert variables_tf_path.exists(), "variables.tf should exist in IAM module"
        assert outputs_tf_path.exists(), "outputs.tf should exist in IAM module"

    def test_iam_main_tf_content(self, main_tf_path):
        """Test that main.tf contains required IAM resources."""
        content = main_tf_path.read_text()

        # Check for IAM roles
        assert 'resource "aws_iam_role" "ecs_execution_role"' in content
        assert 'resource "aws_iam_role" "ecs_task_role"' in content

        # Check for policy attachments
        assert 'resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy"' in content
        assert 'resource "aws_iam_role_policy_attachment" "ecs_execution_policy"' in content
        assert 'resource "aws_iam_role_policy_attachment" "ecs_task_policy"' in content

        # Check for custom policies
        assert 'resource "aws_iam_policy" "ecs_execution_policy"' in content
        assert 'resource "aws_iam_policy" "ecs_task_policy"' in content

    def test_iam_base_policies(self, main_tf_path):
        """Test base policies are properly configured."""
        content = main_tf_path.read_text()

        # Check base policies are loaded from JSON file
        assert (
            'base_policies = jsondecode(file("${path.module}/policies/base-policies.json"))'
            in content
        )

    def test_iam_service_specific_policies(self, main_tf_path):
        """Test service-specific policies are defined."""
        content = main_tf_path.read_text()

        # Check DBT policies are loaded from template file
        assert (
            'dbt_policies = jsondecode(templatefile("${path.module}/policies/dbt-policies.json.tftpl"'  # noqa: E501
            in content
        )
        assert (
            'airflow_policies = jsondecode(templatefile("${path.module}/policies/airflow-policies.json.tftpl"'  # noqa: E501
            in content
        )
        assert (
            'superset_policies = jsondecode(templatefile("${path.module}/policies/superset-policies.json.tftpl"'  # noqa: E501
            in content
        )

    def test_iam_role_trust_policies(self, main_tf_path):
        """Test IAM roles have correct trust policies."""
        content = main_tf_path.read_text()

        # Check ECS task trust relationship with flexible spacing
        assert re.search(r'Service\s*=\s*"ecs-tasks\.amazonaws\.com"', content)
        assert re.search(r'Action\s*=\s*"sts:AssumeRole"', content)
        assert re.search(r'Effect\s*=\s*"Allow"', content)

    def test_iam_execution_role_policy_attachment(self, main_tf_path):
        """Test execution role has AWS managed policy attached."""
        content = main_tf_path.read_text()

        # Check AWS managed policy attachment using data source
        assert 'data "aws_iam_policy" "ecs_task_execution_role_policy"' in content
        assert "policy_arn = data.aws_iam_policy.ecs_task_execution_role_policy.arn" in content

    def test_iam_custom_policy_configuration(self, main_tf_path):
        """Test custom policy is properly configured."""
        content = main_tf_path.read_text()

        # Check custom policy structure
        assert "policy = jsonencode({" in content
        assert re.search(r'Version\s*=\s*"2012-10-17"', content)
        assert re.search(r"Statement\s*=\s*local.service_policies", content)

    def test_iam_service_policy_selection(self, main_tf_path):
        """Test service policies are selected based on service type."""
        content = main_tf_path.read_text()

        # Check service policy lookup
        assert "service_policies = concat(" in content
        assert "local.base_policies," in content
        assert "lookup({" in content
        assert re.search(r"dbt\s*=\s*local.dbt_policies", content)
        assert re.search(r"airflow\s*=\s*local.airflow_policies", content)
        assert re.search(r"superset\s*=\s*local.superset_policies", content)
        assert "}, var.service_type, [])" in content

    def test_iam_variables_tf_content(self, variables_tf_path):
        """Test that variables.tf contains required variables."""
        content = variables_tf_path.read_text()

        # Check for required variables
        assert 'variable "service_name"' in content
        assert 'variable "service_type"' in content
        assert 'variable "environment"' in content
        assert 'variable "project_name"' in content
        assert 'variable "common_tags"' in content
        assert 'variable "data_lake_bucket_arn"' in content
        assert 'variable "processed_data_bucket_arn"' in content
        assert 'variable "artifacts_bucket_arn"' in content

    def test_iam_outputs_tf_content(self, outputs_tf_path):
        """Test that outputs.tf contains required outputs."""
        content = outputs_tf_path.read_text()

        # Check for required outputs
        assert 'output "ecs_execution_role_arn"' in content
        assert 'output "ecs_task_role_arn"' in content
        assert 'output "ecs_execution_role_name"' in content
        assert 'output "ecs_task_role_name"' in content

    def test_iam_naming_convention(self, main_tf_path):
        """Test IAM resources follow naming convention."""
        content = main_tf_path.read_text()

        # Check role naming conventions
        assert 'name = "${var.service_name}-${var.environment}-execution-role"' in content
        assert 'name = "${var.service_name}-${var.environment}-task-role"' in content
        # Check policy naming conventions (execution policy only created for DBT services)
        assert 'name        = "${var.service_name}-${var.environment}-execution-policy"' in content
        assert 'name        = "${var.service_name}-${var.environment}-task-policy"' in content

    def test_iam_resource_tagging(self, main_tf_path):
        """Test IAM resources are properly tagged."""
        content = main_tf_path.read_text()

        # Check tag merging
        assert "tags = merge(var.common_tags, {" in content
        assert re.search(r'Module\s*=\s*"iam"', content)
        assert re.search(r"Environment\s*=\s*var.environment", content)

    def test_iam_s3_bucket_permissions(self, main_tf_path):
        """Test S3 bucket permissions are properly configured."""
        content = main_tf_path.read_text()

        # Check S3 permissions use bucket ARN variables in template files
        assert "data_lake_bucket_arn      = var.data_lake_bucket_arn" in content
        assert "processed_data_bucket_arn = var.processed_data_bucket_arn" in content
        assert "artifacts_bucket_arn      = var.artifacts_bucket_arn" in content
