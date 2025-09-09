"""
Unit tests for the status.py script.
"""

import json
from unittest.mock import patch
from pathlib import Path

from status import InfrastructureStatus


class TestInfrastructureStatus:
    """Test cases for InfrastructureStatus class."""

    def test_status_initialization(self, test_environment):
        """Test InfrastructureStatus initializes with correct paths."""
        status = InfrastructureStatus(test_environment)

        assert status.environment == test_environment
        assert status.script_dir == Path(__file__).parent.parent.parent / "scripts"
        assert status.root_dir == Path(__file__).parent.parent.parent
        assert (
            status.tfvars_file == Path(__file__).parent.parent.parent / f"{test_environment}.tfvars"
        )

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_state_no_file(self, mock_run_command, test_environment, tmp_path):
        """Test get_terraform_state when no state file exists."""
        status = InfrastructureStatus(test_environment)
        status.root_dir = tmp_path  # Override to use temp directory

        result = status.get_terraform_state()

        assert result is None
        mock_run_command.assert_not_called()

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_state_success(self, mock_run_command, test_environment, tmp_path):
        """Test successful terraform state retrieval."""
        status = InfrastructureStatus(test_environment)
        status.root_dir = tmp_path

        # Create a dummy state file
        state_file = tmp_path / "terraform.tfstate"
        state_file.write_text('{"version": 4}')

        mock_run_command.return_value = (
            True,
            "module.vpc.aws_vpc.main\nmodule.s3.aws_s3_bucket.data_lake",
            "",
        )

        result = status.get_terraform_state()

        assert result is not None
        assert len(result) == 2
        assert "module.vpc.aws_vpc.main" in result
        assert "module.s3.aws_s3_bucket.data_lake" in result

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_state_command_failure(
        self, mock_run_command, test_environment, tmp_path
    ):
        """Test terraform state command failure."""
        status = InfrastructureStatus(test_environment)
        status.root_dir = tmp_path

        # Create a dummy state file
        state_file = tmp_path / "terraform.tfstate"
        state_file.write_text('{"version": 4}')

        mock_run_command.return_value = (False, "", "state list failed")

        result = status.get_terraform_state()

        assert result is None

    def test_show_resource_counts_empty(self, test_environment):
        """Test show_resource_counts with empty resource list."""
        status = InfrastructureStatus(test_environment)

        with patch("builtins.print") as mock_print:
            status.show_resource_counts([])

        # Should print warning about no resources
        warning_calls = [
            call for call in mock_print.call_args_list if "No resources found" in str(call)
        ]
        assert len(warning_calls) > 0

    def test_show_resource_counts_with_resources(self, test_environment):
        """Test show_resource_counts with actual resources."""
        status = InfrastructureStatus(test_environment)

        resources = [
            "module.vpc.aws_vpc.main",
            "module.vpc.aws_subnet.private[0]",
            "module.vpc.aws_subnet.private[1]",
            "module.s3.aws_s3_bucket.data_lake",
            "module.secrets.aws_secretsmanager_secret.db_creds",
        ]

        with patch("builtins.print") as mock_print:
            status.show_resource_counts(resources)

        # Check that it prints resource counts
        print_calls = [str(call) for call in mock_print.call_args_list]
        resource_summary_found = any("module" in call for call in print_calls)
        total_found = any("Total resources: 5" in call for call in print_calls)

        assert resource_summary_found
        assert total_found

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_outputs_success(
        self, mock_run_command, test_environment, sample_terraform_outputs
    ):
        """Test successful terraform outputs retrieval."""
        status = InfrastructureStatus(test_environment)

        mock_run_command.return_value = (
            True,
            json.dumps(sample_terraform_outputs),
            "",
        )

        result = status.get_terraform_outputs()

        assert result == sample_terraform_outputs
        assert "vpc_id" in result
        assert result["vpc_id"]["value"] == "vpc-123456"

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_outputs_failure(self, mock_run_command, test_environment):
        """Test terraform outputs command failure."""
        status = InfrastructureStatus(test_environment)

        mock_run_command.return_value = (False, "", "outputs failed")

        result = status.get_terraform_outputs()

        assert "error" in result
        assert "outputs failed" in result["error"]

    @patch("status.InfrastructureStatus.run_command")
    def test_get_terraform_outputs_invalid_json(self, mock_run_command, test_environment):
        """Test terraform outputs with invalid JSON."""
        status = InfrastructureStatus(test_environment)

        mock_run_command.return_value = (True, "invalid json", "")

        result = status.get_terraform_outputs()

        assert "error" in result

    def test_show_access_information_empty(self, test_environment):
        """Test show_access_information with no outputs."""
        status = InfrastructureStatus(test_environment)

        with patch("builtins.print") as mock_print:
            status.show_access_information({})

        warning_calls = [
            call for call in mock_print.call_args_list if "No outputs available" in str(call)
        ]
        assert len(warning_calls) > 0

    def test_show_access_information_with_data(self, test_environment, sample_terraform_outputs):
        """Test show_access_information with actual outputs."""
        status = InfrastructureStatus(test_environment)

        with patch("builtins.print") as mock_print:
            status.show_access_information(sample_terraform_outputs)

        # Check that it prints the outputs
        print_calls = [str(call) for call in mock_print.call_args_list]
        vpc_info_found = any("vpc_id" in call for call in print_calls)

        assert vpc_info_found

    def test_show_access_information_truncates_long_values(self, test_environment):
        """Test that long values get truncated in output."""
        status = InfrastructureStatus(test_environment)

        long_outputs = {"long_value": {"value": "x" * 100}}  # 100 character string

        with patch("builtins.print") as mock_print:
            status.show_access_information(long_outputs)

        print_calls = [str(call) for call in mock_print.call_args_list]
        truncated_found = any("..." in call for call in print_calls)

        assert truncated_found

    def test_show_cost_estimate(self, test_environment):
        """Test cost estimate display."""
        status = InfrastructureStatus(test_environment)

        with patch("builtins.print") as mock_print:
            status.show_cost_estimate()

        print_calls = [str(call) for call in mock_print.call_args_list]
        cost_info_found = any("$1.50/day" in call for call in print_calls)
        warning_found = any("destroy resources" in call.lower() for call in print_calls)

        assert cost_info_found
        assert warning_found

    def test_show_quick_commands(self, test_environment):
        """Test quick commands display."""
        status = InfrastructureStatus(test_environment)

        with patch("builtins.print") as mock_print:
            status.show_quick_commands()

        print_calls = [str(call) for call in mock_print.call_args_list]
        deploy_cmd_found = any("deploy.py apply" in call for call in print_calls)
        validate_cmd_found = any("validate.py" in call for call in print_calls)

        assert deploy_cmd_found
        assert validate_cmd_found

    def test_show_quick_commands_dev_specific(self, test_environment):
        """Test quick commands includes dev-specific info."""
        status = InfrastructureStatus("dev")  # Specifically test dev environment

        with patch("builtins.print") as mock_print:
            status.show_quick_commands()

        print_calls = [str(call) for call in mock_print.call_args_list]
        metabase_info_found = any("Metabase" in call for call in print_calls)

        assert metabase_info_found
