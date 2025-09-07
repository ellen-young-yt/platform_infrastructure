#!/bin/bash
set -euo pipefail

# Deploy platform infrastructure to AWS using Terraform
# Usage: ./deploy.sh <environment> <action> [--auto-approve]
# Environment: dev, staging, prod
# Action: plan, apply, destroy

# Color functions
red() { echo -e "\033[31m❌ $1\033[0m"; }
green() { echo -e "\033[32m✅ $1\033[0m"; }
yellow() { echo -e "\033[33m⚠️  $1\033[0m"; }
blue() { echo -e "\033[34mℹ️  $1\033[0m"; }
cyan() { echo -e "\033[36m🔄 $1\033[0m"; }

# Parse arguments
ENVIRONMENT="${1:-}"
ACTION="${2:-}"
AUTO_APPROVE=""
if [[ "${3:-}" == "--auto-approve" ]]; then
    AUTO_APPROVE="--auto-approve"
fi

# Validate arguments
if [[ -z "$ENVIRONMENT" ]] || [[ -z "$ACTION" ]]; then
    red "Usage: $0 <environment> <action> [--auto-approve]"
    red "Environment: dev, staging, prod"
    red "Action: plan, apply, destroy"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    red "Invalid environment: $ENVIRONMENT"
    exit 1
fi

if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    red "Invalid action: $ACTION"
    exit 1
fi

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$ROOT_DIR/environments/$ENVIRONMENT"
TFVARS_FILE="$ENV_DIR/terraform.tfvars"

blue "=== Platform Infrastructure Deployment ==="
blue "Environment: $ENVIRONMENT"
blue "Action: $ACTION"
blue "Root Directory: $ROOT_DIR"

# Validation functions
validate_prerequisites() {
    cyan "Validating prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        red "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    green "AWS CLI is installed"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        red "Terraform is not installed. Please install it first."
        exit 1
    fi
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    green "Terraform is installed (version: $tf_version)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        red "AWS credentials are not configured. Run 'aws configure' first."
        exit 1
    fi
    local identity=$(aws sts get-caller-identity)
    local account=$(echo "$identity" | jq -r '.Account')
    local arn=$(echo "$identity" | jq -r '.Arn')
    green "AWS credentials are configured (Account: $account, User: $arn)"
    
    # Check if tfvars file exists
    if [[ ! -f "$TFVARS_FILE" ]]; then
        red "Terraform variables file not found: $TFVARS_FILE"
        exit 1
    fi
    green "Terraform variables file found"
}

validate_environment_files() {
    cyan "Validating environment files..."
    
    if [[ ! -d "$ENV_DIR" ]]; then
        red "Environment directory not found: $ENV_DIR"
        exit 1
    fi
    
    green "Environment files validated"
}

initialize_terraform() {
    cyan "Initializing Terraform..."
    
    cd "$ROOT_DIR"
    terraform init -input=false
    green "Terraform initialized successfully"
}

terraform_plan() {
    cyan "Creating Terraform plan..."
    
    cd "$ROOT_DIR"
    terraform plan -var-file="$TFVARS_FILE" -input=false
    green "Terraform plan completed successfully"
}

terraform_apply() {
    cyan "Applying Terraform configuration..."
    
    if [[ -n "$AUTO_APPROVE" ]]; then
        yellow "Auto-approve enabled - applying without confirmation"
    fi
    
    cd "$ROOT_DIR"
    terraform apply -var-file="$TFVARS_FILE" -input=false $AUTO_APPROVE
    green "Terraform apply completed successfully"
    
    # Show outputs
    cyan "Displaying outputs..."
    terraform output -json | jq '.'
}

terraform_destroy() {
    cyan "Destroying Terraform infrastructure..."
    
    yellow "This will destroy ALL infrastructure in the $ENVIRONMENT environment!"
    
    if [[ -z "$AUTO_APPROVE" ]]; then
        read -p "Are you sure you want to destroy the infrastructure? Type 'yes' to continue: " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            blue "Destruction cancelled"
            exit 0
        fi
    fi
    
    cd "$ROOT_DIR"
    terraform destroy -var-file="$TFVARS_FILE" -input=false $AUTO_APPROVE
    green "Terraform destroy completed successfully"
}

show_cost_warning() {
    if [[ "$ACTION" == "apply" ]]; then
        yellow "=== COST REMINDER ==="
        blue "Estimated daily cost for $ENVIRONMENT environment: ~\$2-4/day"
        blue "Major cost components:"
        blue "  • NAT Gateway: ~\$1.50/day"
        blue "  • ECS Fargate: ~\$0.40/day"
        blue "  • Other services: ~\$0.20/day"
        blue "Don't forget to destroy resources when not in use!"
        echo
    fi
}

show_post_deployment_info() {
    if [[ "$ACTION" == "apply" ]]; then
        green "=== DEPLOYMENT COMPLETE ==="
        blue "Next steps:"
        blue "1. Check AWS Console to verify resources are created"
        blue "2. Configure Snowflake connection using the outputs above"
        blue "3. Access Metabase using port forwarding (see outputs for instructions)"
        blue "4. Test Airflow and Lambda endpoints"
        echo
        blue "To destroy resources later: ./deploy.sh $ENVIRONMENT destroy"
    fi
}

# Main execution
main() {
    validate_prerequisites
    validate_environment_files
    show_cost_warning
    initialize_terraform
    
    case "$ACTION" in
        "plan") terraform_plan ;;
        "apply") terraform_apply ;;
        "destroy") terraform_destroy ;;
    esac
    
    show_post_deployment_info
    green "Script completed successfully!"
}

main "$@"