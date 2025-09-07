#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deploy platform infrastructure to AWS using Terraform

.DESCRIPTION
This script handles the deployment of the platform infrastructure to AWS.
It includes validation, planning, and deployment steps with proper error handling.

.PARAMETER Environment
The environment to deploy (dev, staging, prod)

.PARAMETER Action
The action to perform (plan, apply, destroy)

.PARAMETER AutoApprove
Skip interactive approval for terraform apply

.EXAMPLE
.\deploy.ps1 -Environment dev -Action plan
.\deploy.ps1 -Environment dev -Action apply
.\deploy.ps1 -Environment dev -Action apply -AutoApprove
.\deploy.ps1 -Environment dev -Action destroy
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action,
    
    [switch]$AutoApprove
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Step { param($Message) Write-Host "[STEP] $Message" -ForegroundColor Blue }

# Constants
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = Split-Path -Parent $SCRIPT_DIR
$ENV_DIR = Join-Path $ROOT_DIR "environments\$Environment"
$TFVARS_FILE = Join-Path $ENV_DIR "terraform.tfvars"

Write-Info "=== Platform Infrastructure Deployment ==="
Write-Info "Environment: $Environment"
Write-Info "Action: $Action"
Write-Info "Root Directory: $ROOT_DIR"

# Validation functions
function Test-Prerequisites {
    Write-Step "Validating prerequisites..."
    
    # Check if AWS CLI is installed
    try {
        $null = Get-Command aws -ErrorAction Stop
        Write-Success "AWS CLI is installed"
    } catch {
        Write-Error "AWS CLI is not installed. Please install it first."
        exit 1
    }
    
    # Check if Terraform is installed
    try {
        $null = Get-Command terraform -ErrorAction Stop
        $tfVersion = terraform version -json | ConvertFrom-Json
        Write-Success "Terraform is installed (version: $($tfVersion.terraform_version))"
    } catch {
        Write-Error "Terraform is not installed. Please install it first."
        exit 1
    }
    
    # Check AWS credentials
    try {
        $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
        Write-Success "AWS credentials are configured (Account: $($identity.Account), User: $($identity.Arn))"
    } catch {
        Write-Error "AWS credentials are not configured. Run 'aws configure' first."
        exit 1
    }
    
    # Check if tfvars file exists
    if (-not (Test-Path $TFVARS_FILE)) {
        Write-Error "Terraform variables file not found: $TFVARS_FILE"
        exit 1
    }
    Write-Success "Terraform variables file found"
}

function Test-EnvironmentFiles {
    Write-Step "Validating environment files..."
    
    if (-not (Test-Path $ENV_DIR)) {
        Write-Error "Environment directory not found: $ENV_DIR"
        exit 1
    }
    
    Write-Success "Environment files validated"
}

function Initialize-Terraform {
    Write-Step "Initializing Terraform..."
    
    Push-Location $ROOT_DIR
    try {
        terraform init -input=false
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform initialization failed"
            exit 1
        }
        Write-Success "Terraform initialized successfully"
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformPlan {
    Write-Step "Creating Terraform plan..."
    
    Push-Location $ROOT_DIR
    try {
        terraform plan -var-file="$TFVARS_FILE" -input=false
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform plan failed"
            exit 1
        }
        Write-Success "Terraform plan completed successfully"
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformApply {
    Write-Step "Applying Terraform configuration..."
    
    $applyArgs = @("-var-file=$TFVARS_FILE", "-input=false")
    if ($AutoApprove) {
        $applyArgs += "-auto-approve"
        Write-Warning "Auto-approve enabled - applying without confirmation"
    }
    
    Push-Location $ROOT_DIR
    try {
        terraform apply @applyArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform apply failed"
            exit 1
        }
        Write-Success "Terraform apply completed successfully"
        
        # Show outputs
        Write-Step "Displaying outputs..."
        terraform output -json | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } finally {
        Pop-Location
    }
}

function Invoke-TerraformDestroy {
    Write-Step "Destroying Terraform infrastructure..."
    
    Write-Warning "This will destroy ALL infrastructure in the $Environment environment!"
    
    if (-not $AutoApprove) {
        $confirmation = Read-Host "Are you sure you want to destroy the infrastructure? Type 'yes' to continue"
        if ($confirmation -ne "yes") {
            Write-Info "Destruction cancelled"
            exit 0
        }
    }
    
    Push-Location $ROOT_DIR
    try {
        $destroyArgs = @("-var-file=$TFVARS_FILE", "-input=false")
        if ($AutoApprove) {
            $destroyArgs += "-auto-approve"
        }
        
        terraform destroy @destroyArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform destroy failed"
            exit 1
        }
        Write-Success "Terraform destroy completed successfully"
    } finally {
        Pop-Location
    }
}

function Show-CostWarning {
    if ($Action -eq "apply") {
        Write-Warning "=== COST REMINDER ==="
        Write-Info "Estimated daily cost for $Environment environment: ~`$2-4/day"
        Write-Info "Major cost components:"
        Write-Info "  • NAT Gateway: ~`$1.50/day"
        Write-Info "  • ECS Fargate: ~`$0.40/day"
        Write-Info "  • Other services: ~`$0.20/day"
        Write-Info "Don't forget to destroy resources when not in use!"
        Write-Info ""
    }
}

function Show-PostDeploymentInfo {
    if ($Action -eq "apply") {
        Write-Success "=== DEPLOYMENT COMPLETE ==="
        Write-Info "Next steps:"
        Write-Info "1. Check AWS Console to verify resources are created"
        Write-Info "2. Configure Snowflake connection using the outputs above"
        Write-Info "3. Access Metabase using port forwarding (see outputs for instructions)"
        Write-Info "4. Test Airflow and Lambda endpoints"
        Write-Info ""
        Write-Info "To destroy resources later: .\deploy.ps1 -Environment $Environment -Action destroy"
    }
}

# Main execution
try {
    Test-Prerequisites
    Test-EnvironmentFiles
    Show-CostWarning
    Initialize-Terraform
    
    switch ($Action) {
        "plan" { Invoke-TerraformPlan }
        "apply" { Invoke-TerraformApply }
        "destroy" { Invoke-TerraformDestroy }
    }
    
    Show-PostDeploymentInfo
    Write-Success "Script completed successfully!"
    
} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    exit 1
}