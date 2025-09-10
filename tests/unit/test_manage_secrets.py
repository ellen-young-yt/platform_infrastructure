"""
Unit tests for the manage-secrets.py script.
"""

import json
from unittest.mock import Mock, patch

from manage_secrets import SecretsManager


class TestSecretsManager:
    """Test cases for SecretsManager class."""

    def test_secrets_manager_initialization(
        self, test_project_name, test_environment, mock_aws_region
    ):
        """Test SecretsManager initializes correctly."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            assert secrets_manager.project_name == test_project_name
            assert secrets_manager.environment == test_environment
            mock_boto3.assert_called_once_with("secretsmanager", region_name=mock_aws_region)

    def test_get_secret_name(self, test_project_name, test_environment, mock_aws_region):
        """Test secret name generation."""
        with patch("boto3.client"):
            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            secret_name = secrets_manager._get_secret_name("database/credentials")
            expected_name = f"{test_project_name}/{test_environment}/database/credentials"

            assert secret_name == expected_name

    def test_set_database_credentials_success(
        self, test_project_name, test_environment, mock_aws_region
    ):
        """Test successful database credentials setting."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            mock_client.put_secret_value.return_value = {}

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.set_database_credentials(
                username="testuser",
                password="testpass",
                host="testhost.com",
                port=5432,
                database="testdb",
                engine="postgres",
            )

            assert result is True
            mock_client.put_secret_value.assert_called_once()

            # Check the call arguments
            call_args = mock_client.put_secret_value.call_args
            assert (
                call_args[1]["SecretId"]
                == f"{test_project_name}/{test_environment}/database/credentials"
            )

            # Verify the secret content
            secret_data = json.loads(call_args[1]["SecretString"])
            assert secret_data["username"] == "testuser"
            assert secret_data["password"] == "testpass"
            assert secret_data["host"] == "testhost.com"
            assert secret_data["port"] == "5432"
            assert secret_data["database"] == "testdb"
            assert secret_data["engine"] == "postgres"

    def test_set_database_credentials_failure(
        self, test_project_name, test_environment, mock_aws_region
    ):
        """Test database credentials setting failure."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            mock_client.put_secret_value.side_effect = Exception("AWS Error")

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.set_database_credentials(
                username="testuser", password="testpass", host="testhost.com"
            )

            assert result is False

    def test_set_api_keys_success(self, test_project_name, test_environment, mock_aws_region):
        """Test successful API keys setting."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            mock_client.put_secret_value.return_value = {}

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.set_api_keys(
                openai_api_key="sk-test123", github_token="ghp_test456"
            )

            assert result is True

            # Check the call arguments
            call_args = mock_client.put_secret_value.call_args
            secret_data = json.loads(call_args[1]["SecretString"])
            assert secret_data["openai_api_key"] == "sk-test123"
            assert secret_data["github_token"] == "ghp_test456"
            assert "custom_api_keys" in secret_data

    def test_set_api_keys_filters_empty_values(
        self, test_project_name, test_environment, mock_aws_region
    ):
        """Test API keys setting filters out empty values."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            mock_client.put_secret_value.return_value = {}

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.set_api_keys(
                openai_api_key="sk-test123",
                github_token="",  # Empty value should be filtered
                slack_webhook_url="",  # Empty value should be filtered
            )

            assert result is True

            # Check the call arguments
            call_args = mock_client.put_secret_value.call_args
            secret_data = json.loads(call_args[1]["SecretString"])
            assert secret_data["openai_api_key"] == "sk-test123"
            assert "github_token" not in secret_data
            assert "slack_webhook_url" not in secret_data
            assert "custom_api_keys" in secret_data  # This should always be present

    def test_get_secret_success(self, test_project_name, test_environment, mock_aws_region):
        """Test successful secret retrieval."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client

            mock_secret_data = {"username": "testuser", "password": "testpass"}
            mock_client.get_secret_value.return_value = {
                "SecretString": json.dumps(mock_secret_data)
            }

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.get_secret("database/credentials")

            assert result == mock_secret_data
            mock_client.get_secret_value.assert_called_once()

    def test_get_secret_failure(self, test_project_name, test_environment, mock_aws_region):
        """Test secret retrieval failure."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client
            mock_client.get_secret_value.side_effect = Exception("Secret not found")

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            result = secrets_manager.get_secret("database/credentials")

            assert "error" in result
            assert "Secret not found" in result["error"]

    def test_list_secrets_success(self, test_project_name, test_environment, mock_aws_region):
        """Test successful secrets listing."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client

            # Mock paginator
            mock_paginator = Mock()
            mock_client.get_paginator.return_value = mock_paginator
            mock_paginator.paginate.return_value = [
                {
                    "SecretList": [
                        {
                            "Name": f"{test_project_name}/{test_environment}/database/credentials",
                            "Description": "Database credentials",
                            "CreatedDate": "2023-01-01T00:00:00Z",
                        },
                        {
                            "Name": f"{test_project_name}/{test_environment}/api/keys",
                            "Description": "API keys",
                            "CreatedDate": "2023-01-02T00:00:00Z",
                        },
                        {
                            "Name": "other-project/dev/secret",  # Should be filtered out
                            "Description": "Other secret",
                            "CreatedDate": "2023-01-03T00:00:00Z",
                        },
                    ]
                }
            ]

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            # Capture stdout to test the output
            with patch("builtins.print") as mock_print:
                secrets_manager.list_secrets()

            # Should print 2 secrets (filtering out the other project)
            print_calls = [
                call for call in mock_print.call_args_list if call[0] and call[0][0].startswith("*")
            ]
            assert len(print_calls) == 2

    def test_list_secrets_failure(self, test_project_name, test_environment, mock_aws_region):
        """Test secrets listing failure."""
        with patch("boto3.client") as mock_boto3:
            mock_client = Mock()
            mock_boto3.return_value = mock_client

            # Mock paginator failure
            mock_paginator = Mock()
            mock_client.get_paginator.return_value = mock_paginator
            mock_paginator.paginate.side_effect = Exception("Access denied")

            secrets_manager = SecretsManager(test_project_name, test_environment, mock_aws_region)

            # Should not raise an exception, but handle it gracefully
            secrets_manager.list_secrets()
