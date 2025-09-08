"""
Unit tests for the validate.py script.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
import json

from validate import TerraformValidator

class TestTerraformValidator:
    """Test cases for TerraformValidator class."""
    
    def test_validator_initialization(self, test_environment):
        """Test validator initializes with correct paths."""
        validator = TerraformValidator(test_environment)
        
        assert validator.environment == test_environment
        assert validator.script_dir == Path(__file__).parent.parent.parent / "scripts"
        assert validator.root_dir == Path(__file__).parent.parent.parent
        assert validator.tfvars_file == Path(__file__).parent.parent.parent / f"{test_environment}.tfvars"
        
    def test_run_command_success(self, test_environment):
        """Test successful command execution."""
        validator = TerraformValidator(test_environment)
        
        with patch('subprocess.run') as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = "success"
            mock_run.return_value.stderr = ""
            
            success, stdout, stderr = validator.run_command(["echo", "test"])
            
            assert success is True
            assert stdout == "success"
            assert stderr == ""
            
    def test_run_command_failure(self, test_environment):
        """Test command execution failure."""
        validator = TerraformValidator(test_environment)
        
        with patch('subprocess.run') as mock_run:
            mock_run.return_value.returncode = 1
            mock_run.return_value.stdout = ""
            mock_run.return_value.stderr = "error"
            
            success, stdout, stderr = validator.run_command(["false"])
            
            assert success is False
            assert stdout == ""
            assert stderr == "error"
    
    def test_run_command_not_found(self, test_environment):
        """Test command not found error."""
        validator = TerraformValidator(test_environment)
        
        with patch('subprocess.run', side_effect=FileNotFoundError):
            success, stdout, stderr = validator.run_command(["nonexistent"])
            
            assert success is False
            assert stdout == ""
            assert "Command not found" in stderr
    
    @patch('validate.TerraformValidator.run_command')
    def test_terraform_syntax_success(self, mock_run_command, test_environment):
        """Test successful Terraform syntax validation."""
        validator = TerraformValidator(test_environment)
        
        # Mock successful init and validate
        mock_run_command.side_effect = [
            (True, "", ""),  # terraform init
            (True, "", "")   # terraform validate
        ]
        
        result = validator.test_terraform_syntax()
        
        assert result is True
        assert mock_run_command.call_count == 2
        
    @patch('validate.TerraformValidator.run_command')
    def test_terraform_syntax_init_failure(self, mock_run_command, test_environment):
        """Test Terraform init failure."""
        validator = TerraformValidator(test_environment)
        
        # Mock failed init
        mock_run_command.return_value = (False, "", "init failed")
        
        result = validator.test_terraform_syntax()
        
        assert result is False
        
    @patch('validate.TerraformValidator.run_command')
    def test_terraform_syntax_validate_failure(self, mock_run_command, test_environment):
        """Test Terraform validate failure.""" 
        validator = TerraformValidator(test_environment)
        
        # Mock successful init, failed validate
        mock_run_command.side_effect = [
            (True, "", ""),      # terraform init
            (False, "", "invalid syntax")  # terraform validate
        ]
        
        result = validator.test_terraform_syntax()
        
        assert result is False
        
    @patch('validate.TerraformValidator.run_command')
    def test_terraform_format_check_success(self, mock_run_command, test_environment):
        """Test successful Terraform format check."""
        validator = TerraformValidator(test_environment)
        
        mock_run_command.return_value = (True, "", "")
        
        result = validator.test_terraform_format()
        
        assert result is True
        mock_run_command.assert_called_once_with([
            "terraform", "fmt", "-check", "-recursive"
        ])
        
    @patch('validate.TerraformValidator.run_command')
    def test_terraform_format_check_failure(self, mock_run_command, test_environment):
        """Test Terraform format check failure."""
        validator = TerraformValidator(test_environment)
        
        mock_run_command.return_value = (False, "", "format issues")
        
        result = validator.test_terraform_format()
        
        assert result is False
        
    def test_variables_file_missing(self, test_environment, tmp_path):
        """Test missing variables file."""
        validator = TerraformValidator(test_environment)
        # Override the tfvars_file path to non-existent file
        validator.tfvars_file = tmp_path / "nonexistent.tfvars"
        
        result = validator.test_variables_file()
        
        assert result is False
        
    def test_variables_file_missing_required_vars(self, test_environment, tmp_path):
        """Test variables file missing required variables."""
        validator = TerraformValidator(test_environment)
        
        # Create a tfvars file without required variables
        tfvars_file = tmp_path / "test.tfvars" 
        tfvars_file.write_text("some_var = \"value\"")
        validator.tfvars_file = tfvars_file
        
        result = validator.test_variables_file()
        
        assert result is False
        
    def test_variables_file_valid(self, test_environment, tmp_path):
        """Test valid variables file."""
        validator = TerraformValidator(test_environment)
        
        # Create a tfvars file with all required variables
        tfvars_content = '''
aws_region = "us-east-2"
environment = "dev"
project_name = "test-project"
snowflake_account_id = "test-account"
        '''
        tfvars_file = tmp_path / "test.tfvars"
        tfvars_file.write_text(tfvars_content)
        validator.tfvars_file = tfvars_file
        
        result = validator.test_variables_file()
        
        assert result is True
        
    @patch('validate.TerraformValidator.run_command')
    def test_aws_credentials_success(self, mock_run_command, test_environment):
        """Test successful AWS credentials check."""
        validator = TerraformValidator(test_environment)
        
        mock_identity = {
            "Account": "123456789012",
            "Arn": "arn:aws:iam::123456789012:user/test"
        }
        mock_run_command.return_value = (True, json.dumps(mock_identity), "")
        
        result = validator.test_aws_credentials()
        
        assert result is True
        
    @patch('validate.TerraformValidator.run_command')  
    def test_aws_credentials_failure(self, mock_run_command, test_environment):
        """Test AWS credentials check failure."""
        validator = TerraformValidator(test_environment)
        
        mock_run_command.return_value = (False, "", "credentials not found")
        
        result = validator.test_aws_credentials()
        
        assert result is False
        
    @patch('validate.TerraformValidator.run_command')
    def test_aws_credentials_invalid_json(self, mock_run_command, test_environment):
        """Test AWS credentials with invalid JSON response."""
        validator = TerraformValidator(test_environment)
        
        mock_run_command.return_value = (True, "invalid json", "")
        
        result = validator.test_aws_credentials()
        
        assert result is False