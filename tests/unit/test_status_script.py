"""
Unit tests for the status.py script.
"""

import json
from unittest.mock import patch
from pathlib import Path

from terraform_manager import TerraformManager


class TestStatusScript:
    """Test cases for TerraformManager status functionality."""

    def test_terraform_manager_initialization(self, test_environment):
        """Test TerraformManager initializes with correct paths."""
        manager = TerraformManager(test_environment)

        assert manager.environment == test_environment
        assert manager.script_dir == Path(__file__).parent.parent.parent / "scripts"
        assert manager.root_dir == Path(__file__).parent.parent.parent

    @patch("terraform_manager.run_command")
    def test_get_terraform_state_no_resources(self, mock_run_command, test_environment):
        """Test get_terraform_state when no resources exist."""
        manager = TerraformManager(test_environment)

        # Mock empty state
        mock_run_command.return_value = (True, "", "")

        result = manager.get_terraform_state()

        assert result == []

    @patch("terraform_manager.run_command")
    def test_get_terraform_state_success(self, mock_run_command, test_environment):
        """Test successful terraform state retrieval."""
        manager = TerraformManager(test_environment)

        mock_run_command.return_value = (
            True,
            "module.vpc.aws_vpc.main\nmodule.s3.aws_s3_bucket.data_lake",
            "",
        )

        result = manager.get_terraform_state()

        assert result is not None
        assert len(result) == 2
        assert "module.vpc.aws_vpc.main" in result
        assert "module.s3.aws_s3_bucket.data_lake" in result

    @patch("terraform_manager.run_command")
    def test_get_terraform_state_command_failure(self, mock_run_command, test_environment):
        """Test terraform state command failure."""
        manager = TerraformManager(test_environment)

        mock_run_command.return_value = (False, "", "state list failed")

        result = manager.get_terraform_state()

        assert result is None

    @patch("terraform_manager.run_command")
    def test_get_terraform_outputs_success(
        self, mock_run_command, test_environment, sample_terraform_outputs
    ):
        """Test successful terraform outputs retrieval."""
        manager = TerraformManager(test_environment)

        mock_run_command.return_value = (
            True,
            json.dumps(sample_terraform_outputs),
            "",
        )

        result = manager.get_terraform_outputs()

        assert result == sample_terraform_outputs
        assert "vpc_id" in result
        assert result["vpc_id"]["value"] == "vpc-123456"

    @patch("terraform_manager.run_command")
    def test_get_terraform_outputs_failure(self, mock_run_command, test_environment):
        """Test terraform outputs command failure."""
        manager = TerraformManager(test_environment)

        mock_run_command.return_value = (False, "", "outputs failed")

        result = manager.get_terraform_outputs()

        assert "error" in result
        assert "outputs failed" in result["error"]

    @patch("terraform_manager.run_command")
    def test_get_terraform_outputs_invalid_json(self, mock_run_command, test_environment):
        """Test terraform outputs with invalid JSON."""
        manager = TerraformManager(test_environment)

        mock_run_command.return_value = (True, "invalid json", "")

        result = manager.get_terraform_outputs()

        assert "error" in result
