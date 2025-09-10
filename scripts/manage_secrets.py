#!/usr/bin/env python3
"""
AWS Secrets Manager Helper Script

This script helps manage secrets after Terraform deployment.
It provides commands to set, get, and update secret values securely.
"""

# SET DATABASE CREDENTIALS
# Example structure for manual update:
# {
#   "username": "your_username",
#   "password": "your_password",
#   "host": "your_host",
#   "port": "5432",
#   "database": "your_database",
#   "engine": "postgres"
# }

# SET REDIS CREDENTIALS
# Example structure for manual update:
# {
#   "host": "your_redis_host",
#   "port": "6379",
#   "password": "your_redis_password",
#   "url": "redis://:your_password@host:6379/0"
# }

# SET API KEYS
# Example structure for manual update:
# {
#   "openai_api_key": "sk-...",
#   "github_token": "ghp_...",
#   "slack_webhook_url": "https://hooks.slack.com/...",
#   "datadog_api_key": "...",
#   "custom_api_keys": {}
# }

import json
import boto3
import argparse
from typing import Dict, Any


class SecretsManager:
    def __init__(self, project_name: str, environment: str, region: str = "us-east-2"):
        self.project_name = project_name
        self.environment = environment
        self.client = boto3.client("secretsmanager", region_name=region)

    def _get_secret_name(self, secret_type: str) -> str:
        """Generate the full secret name based on type"""
        return f"{self.project_name}/{self.environment}/{secret_type}"

    def set_database_credentials(
        self,
        username: str,
        password: str,
        host: str,
        port: int = 5432,
        database: str = "postgres",
        engine: str = "postgres",
    ) -> bool:
        """Set database credentials"""
        secret_name = self._get_secret_name("database/credentials")
        secret_value = {
            "username": username,
            "password": password,
            "host": host,
            "port": str(port),
            "database": database,
            "engine": engine,
        }

        try:
            self.client.put_secret_value(
                SecretId=secret_name, SecretString=json.dumps(secret_value)
            )
            print("[SUCCESS] Database credentials updated successfully")
        except Exception as e:
            print(f"[ERROR] Error updating database credentials: {e}")
            return False
        return True

    def set_api_keys(
        self,
        openai_api_key: str = "",
        github_token: str = "",
        slack_webhook_url: str = "",
        datadog_api_key: str = "",
    ) -> bool:
        """Set API keys and tokens"""
        secret_name = self._get_secret_name("api/keys")
        secret_value = {
            "openai_api_key": openai_api_key,
            "github_token": github_token,
            "slack_webhook_url": slack_webhook_url,
            "datadog_api_key": datadog_api_key,
            "custom_api_keys": {},
        }

        # Remove empty values
        secret_value = {k: v for k, v in secret_value.items() if v or k == "custom_api_keys"}

        try:
            self.client.put_secret_value(
                SecretId=secret_name, SecretString=json.dumps(secret_value)
            )
            print("[SUCCESS] API keys updated successfully")
        except Exception as e:
            print(f"[ERROR] Error updating API keys: {e}")
            return False
        return True

    def set_app_config(
        self,
        secret_key: str,
        jwt_secret: str,
        encryption_key: str,
        session_secret: str,
    ) -> bool:
        """Set application configuration secrets"""
        secret_name = self._get_secret_name("app/config")
        secret_value = {
            "secret_key": secret_key,
            "jwt_secret": jwt_secret,
            "encryption_key": encryption_key,
            "session_secret": session_secret,
            "additional_config": {},
        }

        try:
            self.client.put_secret_value(
                SecretId=secret_name, SecretString=json.dumps(secret_value)
            )
            print("[SUCCESS] App configuration updated successfully")
        except Exception as e:
            print(f"[ERROR] Error updating app configuration: {e}")
            return False
        return True

    def get_secret(self, secret_type: str) -> Dict[str, Any]:
        """Get a secret value"""
        secret_name = self._get_secret_name(secret_type)

        try:
            response = self.client.get_secret_value(SecretId=secret_name)
            result = json.loads(response["SecretString"])
            return result if isinstance(result, dict) else {"error": "Invalid secret format"}
        except Exception as e:
            print(f"[ERROR] Error getting secret {secret_name}: {e}")
            return {"error": str(e)}

    def list_secrets(self) -> None:
        """List all secrets for this project/environment"""
        prefix = f"{self.project_name}/{self.environment}/"

        try:
            paginator = self.client.get_paginator("list_secrets")
            for page in paginator.paginate():
                for secret in page["SecretList"]:
                    if secret["Name"].startswith(prefix):
                        print(f"* {secret['Name']}")
                        print(f"   Description: {secret.get('Description', 'N/A')}")
                        print(f"   Created: {secret['CreatedDate']}")
                        print()
        except Exception as e:
            print(f"[ERROR] Error listing secrets: {e}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage AWS Secrets Manager secrets")
    parser.add_argument("--project", required=True, help="Project name")
    parser.add_argument("--env", required=True, help="Environment (dev/staging/prod)")
    parser.add_argument("--region", help="AWS region")

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Set database credentials
    db_parser = subparsers.add_parser("set-db", help="Set database credentials")
    db_parser.add_argument("--username", required=True, help="Database username")
    db_parser.add_argument("--password", required=True, help="Database password")
    db_parser.add_argument("--host", required=True, help="Database host")
    db_parser.add_argument("--port", type=int, default=5432, help="Database port")
    db_parser.add_argument("--database", default="postgres", help="Database name")
    db_parser.add_argument("--engine", default="postgres", help="Database engine")

    # Set API keys
    api_parser = subparsers.add_parser("set-api", help="Set API keys")
    api_parser.add_argument("--openai-key", help="OpenAI API key")
    api_parser.add_argument("--github-token", help="GitHub token")
    api_parser.add_argument("--slack-webhook", help="Slack webhook URL")
    api_parser.add_argument("--datadog-key", help="Datadog API key")

    # Set app config
    app_parser = subparsers.add_parser("set-app", help="Set app configuration")
    app_parser.add_argument("--secret-key", required=True, help="App secret key")
    app_parser.add_argument("--jwt-secret", required=True, help="JWT secret")
    app_parser.add_argument("--encryption-key", required=True, help="Encryption key")
    app_parser.add_argument("--session-secret", required=True, help="Session secret")

    # Get secret
    get_parser = subparsers.add_parser("get", help="Get secret value")
    get_parser.add_argument(
        "secret_type",
        help="Secret type (database/credentials, api/keys, app/config)",
    )

    # List secrets
    subparsers.add_parser("list", help="List all secrets")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    secrets_manager = SecretsManager(args.project, args.env, args.region)

    if args.command == "set-db":
        secrets_manager.set_database_credentials(
            args.username,
            args.password,
            args.host,
            args.port,
            args.database,
            args.engine,
        )

    elif args.command == "set-api":
        secrets_manager.set_api_keys(
            args.openai_key or "",
            args.github_token or "",
            args.slack_webhook or "",
            args.datadog_key or "",
        )

    elif args.command == "set-app":
        secrets_manager.set_app_config(
            args.secret_key,
            args.jwt_secret,
            args.encryption_key,
            args.session_secret,
        )

    elif args.command == "get":
        secret = secrets_manager.get_secret(args.secret_type)
        if secret:
            # Don't print sensitive values, just keys
            keys = list(secret.keys())
            print(f"Secret keys: {keys}")

    elif args.command == "list":
        secrets_manager.list_secrets()


if __name__ == "__main__":
    main()
