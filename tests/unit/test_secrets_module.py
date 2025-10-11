"""
Unit tests for the secrets Terraform module.
"""

import re
from pathlib import Path


class TestSecretsModule:
    """Test cases for Secrets Terraform module."""

    def test_secrets_module_files_exist(self):
        """Test that all required module files exist."""
        module_path = Path(__file__).parent.parent.parent / "modules" / "secrets"

        assert (module_path / "main.tf").exists()
        assert (module_path / "variables.tf").exists()
        assert (module_path / "outputs.tf").exists()

    def test_secrets_main_tf_content(self):
        """Test that main.tf contains required secrets resources."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check for all required secrets
        assert 'resource "aws_secretsmanager_secret" "snowflake_credentials"' in content
        assert 'resource "aws_secretsmanager_secret" "redis_credentials"' in content

        # Check for IAM roles
        assert 'resource "aws_iam_role" "secrets_access"' in content
        assert 'resource "aws_iam_role" "secrets_rotation"' in content

        # Check for KMS resources
        assert 'resource "aws_kms_key" "secrets"' in content
        assert 'resource "aws_kms_alias" "secrets"' in content

    def test_secrets_naming_convention(self):
        """Test that secrets follow proper naming conventions."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check naming patterns
        assert '"${var.project_name}/${var.environment}/snowflake/credentials"' in content
        assert '"${var.project_name}/${var.environment}/redis/credentials"' in content

        # Check IAM role naming
        assert '"${var.project_name}-${var.environment}-secrets-access-role"' in content
        assert '"${var.project_name}-${var.environment}-secrets-rotation-role"' in content

    def test_secrets_recovery_configuration(self):
        """Test that secrets have proper recovery window configuration."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check recovery window configuration - should be environment-dependent
        recovery_pattern = (
            r'recovery_window_in_days\s*=\s*var\.environment\s*==\s*"prod"\s*\?\s*30\s*:\s*0'
        )
        assert re.search(recovery_pattern, content)

    def test_secrets_kms_encryption(self):
        """Test KMS encryption configuration for secrets."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check conditional KMS encryption
        assert re.search(
            r"kms_key_id\s*=\s*var\.enable_kms_encryption \? aws_kms_key\.secrets\[0\]\.arn : null",
            content,
        )

        # Check KMS key configuration
        assert 'deletion_window_in_days = var.environment == "prod" ? 30 : 7' in content
        assert 'enable_key_rotation     = var.environment == "prod" ? true : false' in content

    def test_secrets_iam_permissions(self):
        """Test IAM role and policy configuration for secrets access."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check ECS and Lambda trust relationship
        assert '"ecs-tasks.amazonaws.com"' in content
        assert '"lambda.amazonaws.com"' in content

        # Check secretsmanager permissions
        assert '"secretsmanager:GetSecretValue"' in content

        # Check that all secrets are included in the policy
        assert "aws_secretsmanager_secret.snowflake_credentials.arn" in content
        assert "aws_secretsmanager_secret.redis_credentials.arn" in content

    def test_secrets_rotation_configuration(self):
        """Test secrets rotation role configuration."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check conditional rotation resources
        assert "count = var.enable_secret_rotation ? 1 : 0" in content

        # Check rotation permissions
        assert '"secretsmanager:DescribeSecret"' in content
        assert '"secretsmanager:PutSecretValue"' in content
        assert '"secretsmanager:UpdateSecretVersionStage"' in content

        # Check CloudWatch logs permissions for rotation Lambda
        assert '"logs:CreateLogGroup"' in content
        assert '"logs:CreateLogStream"' in content
        assert '"logs:PutLogEvents"' in content

    def test_secrets_tagging_configuration(self):
        """Test that secrets are properly tagged."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Check tag merging with purpose-specific tags
        assert "tags = merge(var.tags, {" in content
        assert 'Purpose = "Snowflake credentials"' in content
        assert 'Purpose = "Redis credentials"' in content
        assert 'Purpose = "Secrets encryption"' in content

    def test_secrets_variables_tf_content(self):
        """Test that variables.tf contains all required variables."""
        variables_tf_path = (
            Path(__file__).parent.parent.parent / "modules" / "secrets" / "variables.tf"
        )
        content = variables_tf_path.read_text()

        # Check core variables
        assert 'variable "environment"' in content
        assert 'variable "project_name"' in content
        assert 'variable "enable_secret_rotation"' in content
        assert 'variable "enable_kms_encryption"' in content
        assert 'variable "tags"' in content

        # Check sensitive variable marking
        assert "sensitive   = true" in content

        # Check default values for feature flags
        assert "default     = false" in content  # secret rotation off by default
        assert "default     = true" in content  # KMS encryption on by default

    def test_secrets_outputs_tf_content(self):
        """Test that outputs.tf contains all required outputs."""
        outputs_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "outputs.tf"
        content = outputs_tf_path.read_text()

        # Check secret ARN outputs
        assert 'output "snowflake_credentials_secret_arn"' in content
        assert 'output "redis_credentials_secret_arn"' in content

        # Check secret name outputs
        assert 'output "snowflake_credentials_secret_name"' in content
        assert 'output "redis_credentials_secret_name"' in content

        # Check IAM role outputs
        assert 'output "secrets_access_role_arn"' in content
        assert 'output "secrets_access_role_name"' in content

        # Check KMS outputs with conditional logic
        assert 'output "kms_key_arn"' in content
        assert "var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null" in content

    def test_secrets_environment_specific_configuration(self):
        """Test environment-specific configurations in secrets module."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Production should have longer recovery windows
        recovery_pattern = r'var\.environment\s*==\s*"prod"\s*\?\s*30\s*:\s*0'
        assert re.search(recovery_pattern, content)

        # Production should have longer KMS deletion window
        kms_deletion_pattern = r'var\.environment\s*==\s*"prod"\s*\?\s*30\s*:\s*7'
        assert re.search(kms_deletion_pattern, content)

        # Production should have key rotation enabled
        rotation_pattern = r'var\.environment\s*==\s*"prod"\s*\?\s*true\s*:\s*false'
        assert re.search(rotation_pattern, content)

    def test_secrets_security_best_practices(self):
        """Test that secrets module follows security best practices."""
        main_tf_path = Path(__file__).parent.parent.parent / "modules" / "secrets" / "main.tf"
        content = main_tf_path.read_text()

        # Should not contain any hardcoded secret values
        suspicious_patterns = [
            r'password\s*=\s*"[^$]',  # Hardcoded passwords
            r'secret\s*=\s*"[^$]',  # Hardcoded secrets
            r'key\s*=\s*"[^$]',  # Hardcoded keys (except variables)
        ]

        for pattern in suspicious_patterns:
            matches = re.search(pattern, content, re.IGNORECASE)
            assert (
                not matches
            ), f"Found potential hardcoded secret: {matches.group() if matches else 'None'}"

        # Should use proper IAM principle of least privilege
        assert "secretsmanager:GetSecretValue" in content  # Read-only for apps
        assert "secretsmanager:PutSecretValue" in content  # Write only for rotation

        # Should not grant overly broad permissions
        assert "secretsmanager:*" not in content
        assert (
            '"*"' not in content or "arn:aws:logs:*:*:*" in content
        )  # Only logs should use wildcards
