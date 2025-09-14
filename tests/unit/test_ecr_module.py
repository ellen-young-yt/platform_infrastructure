"""
Unit tests for the ECR Terraform module.
"""

import pytest
import re


class TestECRModule:
    """Test cases for ECR module Terraform configuration."""

    @pytest.fixture
    def module_path(self, project_root):
        """Path to ECR module."""
        return project_root / "modules" / "ecr"

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

    def test_ecr_module_files_exist(
        self, module_path, main_tf_path, variables_tf_path, outputs_tf_path
    ):
        """Test that all required ECR module files exist."""
        assert module_path.exists(), "ECR module directory should exist"
        assert main_tf_path.exists(), "main.tf should exist in ECR module"
        assert variables_tf_path.exists(), "variables.tf should exist in ECR module"
        assert outputs_tf_path.exists(), "outputs.tf should exist in ECR module"

    def test_ecr_main_tf_content(self, main_tf_path):
        """Test that main.tf contains required ECR resources."""
        content = main_tf_path.read_text()

        # Check for ECR repository resource
        assert 'resource "aws_ecr_repository" "dbt_project"' in content
        assert re.search(r'image_tag_mutability\s*=\s*"IMMUTABLE"', content)
        assert re.search(r'encryption_type\s*=\s*"KMS"', content)
        assert re.search(r"scan_on_push\s*=\s*true", content)

        # Check for lifecycle policy
        assert 'resource "aws_ecr_lifecycle_policy" "dbt_project"' in content
        assert re.search(r"rulePriority\s*=\s*1", content)
        assert "Keep last 10 images" in content

    def test_ecr_variables_tf_content(self, variables_tf_path):
        """Test that variables.tf contains required variables."""
        content = variables_tf_path.read_text()

        # Check for required variables
        assert 'variable "project_name"' in content
        assert 'variable "environment"' in content
        assert 'variable "tags"' in content

    def test_ecr_outputs_tf_content(self, outputs_tf_path):
        """Test that outputs.tf contains required outputs."""
        content = outputs_tf_path.read_text()

        # Check for required outputs
        assert 'output "dbt_repository_url"' in content
        assert 'output "dbt_repository_arn"' in content
        assert 'output "dbt_repository_name"' in content

    def test_ecr_repository_naming_convention(self, main_tf_path):
        """Test ECR repository follows naming convention."""
        content = main_tf_path.read_text()

        # Check repository name format
        assert re.search(
            r'name\s*=\s*"\$\{var\.project_name\}-\$\{var\.environment\}-dbt"', content
        )

    def test_ecr_lifecycle_policy_configuration(self, main_tf_path):
        """Test ECR lifecycle policy is properly configured."""
        content = main_tf_path.read_text()

        # Check lifecycle policy rules with flexible spacing
        assert re.search(r"countNumber\s*=\s*10", content)  # Keep 10 images
        assert re.search(r"countNumber\s*=\s*1", content)  # Delete after 1 day
        assert re.search(r'tagStatus\s*=\s*"tagged"', content)
        assert re.search(r'tagStatus\s*=\s*"untagged"', content)

    def test_ecr_security_configuration(self, main_tf_path):
        """Test ECR security features are enabled."""
        content = main_tf_path.read_text()

        # Check encryption is enabled
        assert "encryption_configuration" in content
        assert re.search(r'encryption_type\s*=\s*"KMS"', content)

        # Check image scanning is enabled
        assert "image_scanning_configuration" in content
        assert re.search(r"scan_on_push\s*=\s*true", content)

    def test_ecr_tags_configuration(self, main_tf_path):
        """Test ECR resources are properly tagged."""
        content = main_tf_path.read_text()

        # Check tags are merged with provided tags
        assert "merge(var.tags" in content
        assert re.search(
            r'Name\s*=\s*"\$\{var\.project_name\}-\$\{var\.environment\}-dbt-ecr"', content
        )
