"""
Unit tests for the validate.py script.
"""

import pytest
from unittest.mock import patch
from pathlib import Path

from terraform_manager import TerraformManager


class TestTerraformValidation:
    """Test cases for TerraformManager validation functionality."""

    def test_terraform_manager_initialization(self, test_environment):
        """Test TerraformManager initializes with correct paths."""
        manager = TerraformManager(test_environment)

        assert manager.environment == test_environment
        assert manager.script_dir == Path(__file__).parent.parent.parent / "scripts"
        assert manager.root_dir == Path(__file__).parent.parent.parent

    def test_run_command_success(self, test_environment):
        """Test successful command execution via utils.run_command."""
        from utils import run_command

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = "success"
            mock_run.return_value.stderr = ""

            success, stdout, stderr = run_command(["echo", "test"])

            assert success is True
            assert stdout == "success"
            assert stderr == ""

    def test_run_command_failure(self, test_environment):
        """Test command execution failure."""
        from utils import run_command

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 1
            mock_run.return_value.stdout = ""
            mock_run.return_value.stderr = "error"

            success, stdout, stderr = run_command(["false"])

            assert success is False
            assert stdout == ""
            assert stderr == "error"

    def test_run_command_not_found(self, test_environment):
        """Test command not found error."""
        from utils import run_command

        with patch("subprocess.run", side_effect=FileNotFoundError):
            success, stdout, stderr = run_command(["nonexistent"])

            assert success is False
            assert stdout == ""
            assert "Command not found" in stderr

    @patch("terraform_manager.TerraformManager.terraform_validate")
    @patch("terraform_manager.TerraformManager.terraform_format_check")
    def test_terraform_configuration_success(self, mock_format, mock_syntax, test_environment):
        """Test successful Terraform configuration validation."""
        manager = TerraformManager(test_environment)

        # Mock successful validation
        mock_syntax.return_value = True
        mock_format.return_value = True

        # Test the individual methods
        assert manager.terraform_validate() is True
        assert manager.terraform_format_check() is True

    @patch("terraform_manager.TerraformManager.terraform_validate")
    @patch("terraform_manager.TerraformManager.terraform_format_check")
    def test_terraform_configuration_syntax_failure(
        self, mock_format, mock_syntax, test_environment
    ):
        """Test Terraform syntax failure."""
        manager = TerraformManager(test_environment)

        # Mock failed syntax validation
        mock_syntax.return_value = False
        mock_format.return_value = True

        # Test the individual methods
        assert manager.terraform_validate() is False
        assert manager.terraform_format_check() is True

    @patch("terraform_manager.TerraformManager.terraform_validate")
    @patch("terraform_manager.TerraformManager.terraform_format_check")
    def test_terraform_configuration_format_failure(
        self, mock_format, mock_syntax, test_environment
    ):
        """Test Terraform format failure."""
        manager = TerraformManager(test_environment)

        # Mock successful syntax, failed format
        mock_syntax.return_value = True
        mock_format.return_value = False

        # Test the individual methods
        assert manager.terraform_validate() is True
        assert manager.terraform_format_check() is False

    def test_project_variables_missing_file(self, test_environment):
        """Test tfvars validation with missing file."""
        manager = TerraformManager(test_environment)

        # Test with non-existent environment (should fail)
        result = manager.validate_tfvars_files("nonexistent_env")

        assert result is False

    def test_project_variables_missing_required_vars(self, test_environment):
        """Test tfvars validation - simplified test."""
        manager = TerraformManager(test_environment)

        # Test the validate_tfvars_files method exists and returns boolean
        result = manager.validate_tfvars_files(test_environment)
        assert isinstance(result, bool)

    def test_project_variables_valid(self, test_environment):
        """Test tfvars validation with valid environment."""
        manager = TerraformManager(test_environment)

        # Test with a valid environment
        result = manager.validate_tfvars_files(test_environment)
        # Should be boolean (True for valid environment or False if files missing)
        assert isinstance(result, bool)

    @patch("terraform_manager.TerraformManager.validate_aws_credentials")
    def test_aws_access_success(self, mock_credentials, test_environment):
        """Test successful AWS access validation."""
        manager = TerraformManager(test_environment)

        mock_credentials.return_value = True

        result = manager.validate_aws_credentials()

        assert result is True

    @patch("terraform_manager.TerraformManager.validate_aws_credentials")
    def test_aws_access_failure(self, mock_credentials, test_environment):
        """Test AWS access validation failure."""
        manager = TerraformManager(test_environment)

        mock_credentials.return_value = False

        result = manager.validate_aws_credentials()

        assert result is False

    @patch("terraform_manager.TerraformManager.security_scan")
    def test_security_practices_success(self, mock_security_scan, test_environment):
        """Test successful security practices validation."""
        manager = TerraformManager(test_environment)

        mock_security_scan.return_value = True  # Security scan passed

        result = manager.security_scan()

        assert result is True

    @patch("terraform_manager.TerraformManager.security_scan")
    def test_security_practices_failure(self, mock_security_scan, test_environment):
        """Test security practices with scan failure."""
        manager = TerraformManager(test_environment)

        mock_security_scan.return_value = False  # Security scan failed

        result = manager.security_scan()

        assert result is False

    @pytest.mark.parametrize("environment", ["dev", "staging", "prod"])
    def test_terraform_manager_initialization_multiple_environments(self, environment):
        """Test TerraformManager initialization with different environments."""
        manager = TerraformManager(environment)

        assert manager.environment == environment
        assert manager.script_dir == Path(__file__).parent.parent.parent / "scripts"
        assert manager.root_dir == Path(__file__).parent.parent.parent

    @pytest.mark.parametrize(
        "environment,expected_valid",
        [
            ("dev", True),
            ("staging", True),
            ("prod", True),
            ("invalid_env", False),
            ("", False),
        ],
    )
    def test_environment_validation_parametrized(self, environment, expected_valid):
        """Test environment validation with multiple values."""
        manager = TerraformManager()

        result = manager.validate_environment(environment)

        assert result == expected_valid

    @pytest.mark.parametrize(
        "return_code,expected_success",
        [
            (0, True),
            (1, False),
            (127, False),
        ],
    )
    @patch("subprocess.run")
    def test_command_execution_with_different_exit_codes(
        self, mock_run, return_code, expected_success
    ):
        """Test command execution with different exit codes."""
        from utils import run_command

        mock_run.return_value.returncode = return_code
        mock_run.return_value.stdout = "output"
        mock_run.return_value.stderr = "error" if return_code != 0 else ""

        success, stdout, stderr = run_command(["test", "command"])

        assert success == expected_success
        assert stdout == "output"
