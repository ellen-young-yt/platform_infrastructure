# Platform Infrastructure

This Terraform configuration sets up a modern data, analytics, and machine learning infrastructure on AWS for the ellen-young-yt project. The infrastructure supports three environments: dev, staging, and prod.

## Architecture Overview

The infrastructure consists of the following modules:

- **networking**: VPC, subnets, security groups, NAT gateways
- **s3-data-lake**: S3 buckets for data storage with proper lifecycle policies
- **ecs-airflow**: Self-deployed Airflow on ECS for workflow orchestration
- **ecs-metabase**: Self-deployed Metabase on ECS for business intelligence
- **snowflake-integration**: IAM roles and S3 stages for Snowflake integration
- **lambda-serving**: Lambda functions and API Gateway for ML model serving
- **monitoring**: CloudWatch dashboards, alarms, and SNS notifications
- **secrets**: AWS Secrets Manager for secure credential storage

## Directory Structure

```
platform_infrastructure/
├── main.tf                    # Root configuration
├── variables.tf               # Root variables
├── outputs.tf                 # Root outputs
├── Makefile                   # Cross-platform automation
├── requirements.txt           # Python dependencies
├── pyproject.toml             # Python tool configurations
├── .pre-commit-config.yaml    # Code quality hooks
├── .checkov.yml               # Security scanning configuration
├── CLAUDE.md                  # Project instructions for Claude Code
├── .github/workflows/         # CI/CD pipelines
│   └── pr-tests.yml
├── environments/              # Environment-specific configurations
│   ├── dev.tfvars            # Development environment variables
│   ├── staging.tfvars        # Staging environment variables
│   └── prod.tfvars           # Production environment variables
├── modules/                   # Reusable modules
│   ├── networking/
│   ├── s3-data-lake/
│   ├── ecs-airflow/
│   ├── ecs-metabase/
│   ├── snowflake-integration/
│   ├── lambda-serving/
│   ├── monitoring/
│   └── secrets/
├── scripts/                   # Cross-platform Python scripts
│   ├── deploy.py             # Deployment automation
│   ├── status.py             # Infrastructure status
│   ├── validate.py           # Configuration validation
│   └── manage_secrets.py     # Secrets management
├── dev-scripts/               # Development utilities
│   └── set-secrets.py        # Local secrets setup
└── tests/                     # Test suite
    ├── conftest.py           # Test configuration
    ├── fixtures/             # Test data and mock outputs
    ├── unit/                 # Unit tests (fast)
    └── integration/          # Integration tests (slow)
```


## Module Details

- **networking**: Creates VPC with public/private subnets, NAT gateways, and security groups across 3 AZs
- **s3-data-lake**: Creates S3 buckets with lifecycle policies, versioning, and encryption for data storage
- **ecs-airflow**: Deploys Apache Airflow webserver and scheduler on ECS Fargate with S3/Secrets access
- **ecs-metabase**: Deploys Metabase on ECS Fargate with ALB, health checks, and auto-scaling
- **snowflake-integration**: Creates IAM roles and S3 stages for Snowflake data loading with managed credentials
- **lambda-serving**: Creates API Gateway and Lambda for ML model serving with throttling and authentication
- **monitoring**: Creates CloudWatch dashboards, alarms, and SNS notifications for comprehensive observability
- **secrets**: Manages application secrets in AWS Secrets Manager with KMS encryption and rotation

## Security Considerations

- All secrets are stored in AWS Secrets Manager
- S3 buckets have public access blocked by default
- Security groups follow least privilege principle
- KMS encryption is available for additional security
- IAM roles use specific resource ARNs where possible


## Monitoring and Alerting

The infrastructure includes comprehensive monitoring:

- **ECS Metrics**: CPU and memory utilization
- **Lambda Metrics**: Duration, errors, and invocations
- **API Gateway Metrics**: 4XX/5XX errors and latency
- **Application Logs**: Error pattern matching and alerting
- **Custom Dashboards**: Environment-specific views

## Quick Deployment Guide

### Development Environment Setup

1. **Setup development environment (includes pre-commit hooks):**
   ```bash
   make setup
   ```

2. **Validate configuration:**
   ```bash
   make validate ENV=dev
   ```

3. **Plan deployment:**
   ```bash
   make plan ENV=dev
   ```

4. **Deploy infrastructure:**
   ```bash
   make apply ENV=dev
   ```

5. **Check status:**
   ```bash
   make status ENV=dev
   ```

6. **Destroy when done:**
   ```bash
   make destroy ENV=dev
   ```

### Cross-Platform Scripts

All deployment operations work on both Windows and Linux via Python scripts:

- **Direct usage:** `python scripts/deploy.py <action> <environment>`
- **Available actions:** `plan`, `apply`, `destroy`
- **Auto-approve:** Add `--auto-approve` flag for automation

### Testing and CI/CD

- **Unit tests:** `make test-unit`
- **Integration tests:** `make test-integration ENV=dev`
- **All tests for environment:** `make test ENV=dev`
- **Code quality checks:** `make lint`
- **Security scanning:** `make security-scan`
- **Pre-commit hooks:** `make pre-commit`
- **Test CI pipeline locally:** `make lint && make validate && make test-unit && make pre-commit && make security-scan`
- **GitHub Actions:** Automatic PR testing with security scans

### Available Make Commands

Run `make help` to see all available commands:

- **setup**: Setup development environment (virtual env + dependencies + pre-commit hooks)
- **validate**: Validate Terraform configuration
- **lint**: Run code formatting, linting, and security checks
- **plan**: Create Terraform execution plan
- **apply**: Apply Terraform changes
- **destroy**: Destroy Terraform infrastructure
- **status**: Show current infrastructure status
- **test-unit**: Run unit tests (fast, no external dependencies)
- **test-integration**: Run integration tests (requires ENV to be set)
- **security-scan**: Run security scanning with Checkov
- **pre-commit**: Run pre-commit hooks
- **clean**: Clean up temporary files
- **check-aws**: Verify AWS credentials and permissions

### Key Configuration Files

- **environments/*.tfvars** - Environment-specific settings (AWS region, project name, Snowflake account, notification email)
- **pyproject.toml** - Python tool configurations (pytest, black, mypy, coverage)
- **requirements.txt** - Dependencies for development and deployment scripts
- **.pre-commit-config.yaml** - Code quality hooks and security scanning
- **.checkov.yml** - Security scanning configuration and exclusions
