# Platform Infrastructure Deployment Guide

This guide covers deploying the platform infrastructure to AWS using Terraform.

## 🚀 Quick Start

1. **Prerequisites Setup** (see below)
2. **Validate Configuration**: `.\scripts\validate.ps1 -Environment dev`
3. **Plan Deployment**: `.\scripts\deploy.ps1 -Environment dev -Action plan`
4. **Deploy Infrastructure**: `.\scripts\deploy.ps1 -Environment dev -Action apply`

## 📋 Prerequisites

### Required Software

1. **AWS CLI v2+**
   ```powershell
   # Windows (using winget)
   winget install Amazon.AWSCLI
   
   # Or download from: https://aws.amazon.com/cli/
   ```

2. **Terraform 1.0+**
   ```powershell
   # Windows (using Chocolatey)
   choco install terraform
   
   # Or download from: https://www.terraform.io/downloads
   ```

3. **PowerShell 7+ (recommended)** or **Bash** (for Linux/Mac)

### AWS Configuration

1. **Configure AWS Credentials**
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret, Region, and Output format
   ```

2. **Verify AWS Access**
   ```bash
   aws sts get-caller-identity
   # Should show your account ID and user/role ARN
   ```

3. **Required AWS Permissions**
   - EC2, VPC, and networking services
   - ECS and IAM roles
   - S3 bucket management
   - Lambda and API Gateway
   - Secrets Manager
   - CloudWatch

### Environment Configuration

1. **Update terraform.tfvars**
   ```hcl
   # environments/dev/terraform.tfvars
   aws_region           = "us-east-2"
   environment          = "dev"
   project_name         = "your-project-name"
   snowflake_account_id = "YOUR-SNOWFLAKE-ACCOUNT-ID"
   notification_email   = "your-email@example.com"
   ```

## 🛠️ Deployment Scripts

### Primary Deployment Script

**PowerShell (Windows):**
```powershell
# Plan deployment
.\scripts\deploy.ps1 -Environment dev -Action plan

# Apply deployment
.\scripts\deploy.ps1 -Environment dev -Action apply

# Apply without confirmation (use with caution)
.\scripts\deploy.ps1 -Environment dev -Action apply -AutoApprove

# Destroy infrastructure
.\scripts\deploy.ps1 -Environment dev -Action destroy
```

**Bash (Linux/Mac):**
```bash
# Make script executable
chmod +x scripts/deploy.sh

# Plan deployment
./scripts/deploy.sh dev plan

# Apply deployment
./scripts/deploy.sh dev apply

# Apply without confirmation
./scripts/deploy.sh dev apply --auto-approve

# Destroy infrastructure
./scripts/deploy.sh dev destroy
```

### Validation Script

```powershell
# Validate configuration before deployment
.\scripts\validate.ps1 -Environment dev
```

This checks:
- Terraform syntax and formatting
- Required variables
- AWS credentials
- Security best practices
- Cost estimates

### Status Script

```powershell
# Check current infrastructure status
.\scripts\status.ps1 -Environment dev
```

Shows:
- Deployed resources
- Access information
- Cost estimates
- Quick commands

## 💰 Cost Management

### Estimated Daily Costs (Dev Environment)

| Service | Cost/Day | Cost/Month | Notes |
|---------|----------|------------|-------|
| NAT Gateway | $1.50 | $45 | Single gateway (optimized) |
| ECS Fargate | $0.40 | $12 | Small containers (256 CPU/512MB) |
| Secrets Manager | $0.05 | $1.60 | 4 secrets |
| Other (S3, Lambda, etc.) | $0.17 | $5 | Pay-per-use |
| **Total** | **$2.12** | **$63.60** | **Well under budget!** |

### Cost Optimization Features

- ✅ Single NAT Gateway (vs 3) saves $90/month
- ✅ No ALB in dev environment saves $23/month  
- ✅ Small ECS container sizes for dev
- ✅ FARGATE_SPOT for additional savings
- ✅ S3 intelligent tiering and lifecycle policies

### Cost Monitoring

```powershell
# Always check status before leaving resources running
.\scripts\status.ps1 -Environment dev

# Destroy when not in use
.\scripts\deploy.ps1 -Environment dev -Action destroy
```

## 🏗️ Infrastructure Components

### Core Services

1. **Networking**
   - VPC with public/private subnets
   - Single NAT Gateway (cost-optimized)
   - Security groups

2. **ECS Services**
   - Airflow (scheduler + webserver)
   - Metabase (without ALB in dev)

3. **Data Storage**
   - S3 data lake with lifecycle policies
   - Snowflake integration

4. **Serverless**
   - Lambda functions for ML serving
   - API Gateway for model endpoints

5. **Security & Secrets**
   - AWS Secrets Manager
   - IAM roles with least privilege

6. **Monitoring**
   - CloudWatch dashboards and alarms

## 🔧 Post-Deployment Steps

### 1. Verify Deployment

```powershell
# Check all resources are created
.\scripts\status.ps1 -Environment dev
```

### 2. Configure Snowflake Integration

Use the Terraform outputs to configure Snowflake:
```sql
-- In Snowflake, create storage integration
CREATE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<role_arn_from_output>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket_name_from_output>/');
```

### 3. Access Services

**Airflow:**
- Check ECS service status in AWS Console
- Use ECS Exec or port forwarding for access

**Metabase (Dev):**
```bash
# Get ECS task ARN
aws ecs list-tasks --cluster ellen-young-yt-dev-metabase --service-name ellen-young-yt-dev-metabase

# Use ECS Exec for access (requires session manager)
aws ecs execute-command --cluster <cluster-name> --task <task-arn> --container metabase --interactive --command "/bin/sh"
```

**Lambda API:**
- API Gateway endpoint shown in outputs
- Test with curl or Postman

## 🚨 Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   ```powershell
   # Clear .terraform directory and reinitialize
   Remove-Item -Recurse -Force .terraform
   terraform init
   ```

2. **AWS Credentials Issues**
   ```bash
   # Verify credentials
   aws sts get-caller-identity
   
   # Reconfigure if needed
   aws configure
   ```

3. **Terraform State Issues**
   ```powershell
   # Check state
   terraform state list
   
   # If corrupted, may need to reimport resources
   ```

4. **Resource Already Exists**
   ```bash
   # Import existing resource
   terraform import <resource_type>.<name> <aws_resource_id>
   ```

### Getting Help

1. **Check Terraform Logs**
   ```bash
   export TF_LOG=DEBUG
   terraform plan
   ```

2. **AWS CloudTrail** - Check for API errors
3. **AWS Support** - For AWS-specific issues

## 🔄 CI/CD Migration

This manual deployment setup is designed to easily migrate to CI/CD:

### GitHub Actions Example

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['platform_infrastructure/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: hashicorp/setup-terraform@v2
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-2
    - name: Terraform Deploy
      run: |
        cd platform_infrastructure
        ./scripts/deploy.sh dev apply --auto-approve
```

### Required Secrets for CI/CD

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY` 
- Any sensitive terraform variables

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [ECS Service Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [Snowflake AWS Integration](https://docs.snowflake.com/en/user-guide/data-load-s3.html)

---

**⚠️ Remember to destroy resources when not in use to avoid unnecessary costs!**

```powershell
.\scripts\deploy.ps1 -Environment dev -Action destroy
```