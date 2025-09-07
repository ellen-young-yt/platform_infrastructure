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
├── environments/              # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── modules/                   # Reusable modules
    ├── networking/
    ├── s3-data-lake/
    ├── ecs-airflow/
    ├── ecs-metabase/
    ├── snowflake-integration/
    ├── lambda-serving/
    ├── monitoring/
    └── secrets/
```

## Getting Started

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Appropriate IAM permissions for creating AWS resources

### Deployment

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Select workspace/environment:**
   ```bash
   terraform workspace new dev    # or staging/prod
   ```

3. **Plan deployment:**
   ```bash
   terraform plan -var-file="environments/dev/terraform.tfvars"
   ```

4. **Apply configuration:**
   ```bash
   terraform apply -var-file="environments/dev/terraform.tfvars"
   ```

### Environment Configuration

Update the `terraform.tfvars` files in each environment directory with your specific values:

- AWS region and availability zones
- Project name and environment
- Snowflake account information
- Notification email addresses
- PagerDuty integration keys

## Module Details

### Networking Module
- Creates VPC with public/private subnets across 3 AZs
- Sets up NAT gateways for outbound internet access
- Configures security groups for ECS and ALB

### S3 Data Lake Module
- Creates buckets for raw data, processed data, and artifacts
- Implements lifecycle policies for cost optimization
- Enables versioning and server-side encryption

### ECS Airflow Module
- Deploys Apache Airflow on ECS Fargate
- Includes webserver and scheduler containers
- Configures IAM roles for S3 and Secrets Manager access

### ECS Metabase Module
- Deploys Metabase on ECS Fargate with ALB
- Includes health checks and auto-scaling configuration
- Supports external database configuration

### Snowflake Integration Module
- Creates IAM roles for Snowflake to access S3
- Sets up S3 stages for data loading
- Manages Snowflake credentials in Secrets Manager

### Lambda Serving Module
- Creates API Gateway and Lambda for ML model serving
- Supports model versioning and A/B testing
- Includes throttling and API key authentication

### Monitoring Module
- Creates CloudWatch dashboards for key metrics
- Sets up alarms for CPU, memory, errors, and latency
- Integrates with SNS for notifications

### Secrets Module
- Manages application secrets in AWS Secrets Manager
- Supports database credentials, API keys, and app config
- Includes KMS encryption and rotation policies

## Security Considerations

- All secrets are stored in AWS Secrets Manager
- S3 buckets have public access blocked by default
- Security groups follow least privilege principle
- KMS encryption is available for additional security
- IAM roles use specific resource ARNs where possible

## Cost Optimization

- ECS services use Fargate Spot for cost savings
- S3 lifecycle policies automatically transition data to cheaper storage classes
- CloudWatch log retention is configured per environment
- NAT gateways are only created where needed

## Monitoring and Alerting

The infrastructure includes comprehensive monitoring:

- **ECS Metrics**: CPU and memory utilization
- **Lambda Metrics**: Duration, errors, and invocations
- **API Gateway Metrics**: 4XX/5XX errors and latency
- **Application Logs**: Error pattern matching and alerting
- **Custom Dashboards**: Environment-specific views

## Customization

To customize the infrastructure:

1. Modify variables in `terraform.tfvars` files
2. Adjust module configurations in `main.tf`
3. Add new modules to the `modules/` directory
4. Update monitoring alarms and thresholds as needed

## Troubleshooting

Common issues and solutions:

1. **ECS tasks not starting**: Check security groups and subnet routing
2. **Secrets not accessible**: Verify IAM role permissions
3. **High costs**: Review resource sizing and lifecycle policies
4. **Deployment failures**: Check AWS service limits and quotas

## Next Steps

After deployment:

1. Configure Airflow DAGs in the ECS cluster
2. Set up Metabase data connections
3. Create Snowflake external stages pointing to S3
4. Deploy ML models to the Lambda serving infrastructure
5. Configure additional monitoring and alerting as needed

## Support

For issues and questions:
- Check the AWS CloudWatch logs
- Review Terraform state and plan output
- Consult AWS documentation for specific services
- Use AWS Support for account-specific issues