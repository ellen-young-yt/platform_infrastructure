# Superset Custom Docker Image

This directory contains the custom Docker image configuration for Apache Superset deployment on AWS ECS.

## Overview

Following [Apache Superset's official recommendations](https://superset.apache.org/docs/installation/docker-builds/), we extend the base `apache/superset` image to:

1. Install the PostgreSQL driver (`psycopg2-binary`) for the metadata database
2. Include a custom `superset_config.py` for production configuration
3. Use environment variables for sensitive configuration (injected from AWS Secrets Manager)

## Files

- **Dockerfile** - Extends `apache/superset:4.1.1` with PostgreSQL driver
- **superset_config.py** - Python configuration file following Superset best practices
- **README.md** - This file

## Building the Image

### Prerequisites

- Docker installed locally or in CI/CD
- AWS CLI configured with appropriate permissions
- Access to the ECR repository

### Build and Push to ECR

```bash
# Set variables
AWS_REGION=us-east-2
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ellen-young-yt-dev-superset
IMAGE_TAG=latest

# Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPOSITORY}

# Build the image
cd docker
docker build -t superset-custom:${IMAGE_TAG} .

# Tag for ECR
docker tag superset-custom:${IMAGE_TAG} ${ECR_REPOSITORY}:${IMAGE_TAG}

# Push to ECR
docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
```

### Using Make (Recommended)

```bash
# Build and push in one command
make docker-build ENV=dev

# Or use the full workflow
make docker-push ENV=dev
```

## Configuration

### Environment Variables Required

The following environment variables **must** be injected by ECS from AWS Secrets Manager:

#### Database Configuration (from `superset/rds-credentials`)
- `DATABASE_USER` - PostgreSQL username
- `DATABASE_PASSWORD` - PostgreSQL password
- `DATABASE_HOST` - RDS endpoint hostname
- `DATABASE_PORT` - PostgreSQL port (default: 5432)
- `DATABASE_DB` - Database name

#### Application Configuration (from `superset/app-config`)
- `SECRET_KEY` - Flask secret key (required for session management)

### Optional Environment Variables

- `ENVIRONMENT` - Set to "dev" for development mode (default: production)

## Configuration File Details

### superset_config.py

This file is loaded by Superset via the `SUPERSET_CONFIG_PATH` environment variable set in the Dockerfile.

**Key Features:**
- Validates all required environment variables on startup
- Constructs `SQLALCHEMY_DATABASE_URI` from injected secrets
- Configures connection pooling and timeouts
- Sets security headers and CSRF protection
- Enables proxy fix for load balancer integration
- Configures feature flags

**Security:**
- No secrets hardcoded in the image
- All sensitive values injected at runtime
- Validates required configuration before startup

## Deployment

The custom image is deployed via Terraform in the `modules/ecs-superset` module:

1. **ECR Repository** - Created by `modules/ecr` module
2. **ECS Task Definition** - References the custom image from ECR
3. **Secrets Injection** - ECS pulls secrets from Secrets Manager and injects as environment variables
4. **Configuration Loading** - Superset loads `superset_config.py` automatically via `SUPERSET_CONFIG_PATH`

## Updating the Image

### For Configuration Changes Only

If you only change `superset_config.py`:

```bash
# Rebuild and push
make docker-build ENV=dev

# Update ECS service to use new image
aws ecs update-service \
  --cluster ellen-young-yt-dev-superset \
  --service ellen-young-yt-dev-superset \
  --force-new-deployment
```

### For Superset Version Updates

Update the base image version in the Dockerfile:

```dockerfile
FROM apache/superset:4.2.0  # Update version
```

Then rebuild and redeploy as above.

**Important:** After version updates, run the init task to apply database migrations:

```bash
# Get the init task run command from Terraform outputs
terraform output superset_init_instructions
```

## Troubleshooting

### Image Won't Build

**Error:** `psycopg2-binary` installation fails

**Solution:** Ensure you're using a recent Python version compatible with psycopg2-binary 2.9.9

### Container Fails to Start

**Error:** `SECRET_KEY environment variable is required`

**Solution:** Verify that the ECS task definition correctly injects secrets from AWS Secrets Manager

### Database Connection Fails

**Error:** `Missing required database environment variables`

**Solution:** Check that all database secrets are present in Secrets Manager and correctly referenced in the ECS task definition

### Configuration Not Loading

**Error:** Superset uses default configuration

**Solution:** Verify that `SUPERSET_CONFIG_PATH=/app/superset_config.py` is set in the Dockerfile and the file exists in the image

## References

- [Apache Superset Docker Documentation](https://superset.apache.org/docs/installation/docker-builds/)
- [Superset Configuration Documentation](https://superset.apache.org/docs/configuration/configuring-superset/)
- [AWS ECS Task Secrets](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html)
