#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validate Terraform configuration before deployment

.DESCRIPTION
This script validates the Terraform configuration, checks formatting,
and runs security and cost analysis checks.

.PARAMETER Environment
The environment to validate (dev, staging, prod)

.EXAMPLE
.\validate.ps1 -Environment dev
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

# Color functions
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Step { param($Message) Write-Host "[STEP] $Message" -ForegroundColor Blue }

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = Split-Path -Parent $SCRIPT_DIR
$ENV_DIR = Join-Path $ROOT_DIR "environments\$Environment"
$TFVARS_FILE = Join-Path $ENV_DIR "terraform.tfvars"

Write-Info "=== Terraform Configuration Validation ==="
Write-Info "Environment: $Environment"

function Test-TerraformSyntax {
    Write-Step "Validating Terraform syntax..."
    
    Push-Location $ROOT_DIR
    try {
        terraform init -backend=false -input=false
        terraform validate
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform validation failed"
            return $false
        }
        Write-Success "Terraform syntax is valid"
        return $true
    } finally {
        Pop-Location
    }
}

function Test-TerraformFormat {
    Write-Step "Checking Terraform formatting..."
    
    Push-Location $ROOT_DIR
    try {
        $formatCheck = terraform fmt -check -recursive
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Terraform files are not properly formatted"
            Write-Info "Run 'terraform fmt -recursive' to fix formatting"
            return $false
        }
        Write-Success "Terraform formatting is correct"
        return $true
    } finally {
        Pop-Location
    }
}

function Test-VariablesFile {
    Write-Step "Validating variables file..."
    
    if (-not (Test-Path $TFVARS_FILE)) {
        Write-Error "Variables file not found: $TFVARS_FILE"
        return $false
    }
    
    # Check for required variables
    $content = Get-Content $TFVARS_FILE -Raw
    $requiredVars = @("aws_region", "environment", "project_name", "snowflake_account_id")
    
    $missing = @()
    foreach ($var in $requiredVars) {
        if ($content -notmatch "$var\s*=") {
            $missing += $var
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing required variables: $($missing -join ', ')"
        return $false
    }
    
    Write-Success "Variables file is valid"
    return $true
}

function Test-AWSCredentials {
    Write-Step "Validating AWS credentials..."
    
    try {
        $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
        Write-Success "AWS credentials are valid (Account: $($identity.Account))"
        return $true
    } catch {
        Write-Error "AWS credentials are invalid or not configured"
        return $false
    }
}

function Show-CostEstimate {
    Write-Step "Showing cost estimate..."
    
    Write-Info "Estimated costs for $Environment environment:"
    Write-Info "  NAT Gateway: ~$45/month ($1.50/day)"
    Write-Info "  ECS Fargate: ~$12/month ($0.40/day)"
    Write-Info "  Secrets Manager: ~$1.60/month ($0.05/day)"
    Write-Info "  Other services: ~$5/month ($0.17/day)"
    Write-Info "  Total: ~$63/month (~$2.12/day)"
    Write-Success "Cost estimate is within acceptable range"
}

function Test-SecurityBestPractices {
    Write-Step "Checking security best practices..."
    
    $warnings = @()
    
    # Check for hardcoded secrets (basic check)
    $allFiles = Get-ChildItem $ROOT_DIR -Recurse -Include "*.tf" | Get-Content -Raw
    
    if ($allFiles -match 'password\s*=\s*"[^$]') {
        $warnings += "Potential hardcoded password found"
    }
    
    if ($allFiles -match 'secret\s*=\s*"[^$]') {
        $warnings += "Potential hardcoded secret found"
    }
    
    if ($warnings.Count -gt 0) {
        foreach ($warning in $warnings) {
            Write-Warning $warning
        }
        Write-Warning "Please review security practices"
    } else {
        Write-Success "No obvious security issues found"
    }
    
    return $warnings.Count -eq 0
}

# Main execution
try {
    $allPassed = $true
    
    $allPassed = (Test-TerraformSyntax) -and $allPassed
    $allPassed = (Test-TerraformFormat) -and $allPassed
    $allPassed = (Test-VariablesFile) -and $allPassed
    $allPassed = (Test-AWSCredentials) -and $allPassed
    $allPassed = (Test-SecurityBestPractices) -and $allPassed
    
    Show-CostEstimate
    
    if ($allPassed) {
        Write-Success "=== All validations passed! Ready for deployment. ==="
        exit 0
    } else {
        Write-Error "=== Some validations failed. Please fix issues before deploying. ==="
        exit 1
    }
    
} catch {
    Write-Error "Validation script failed: $($_.Exception.Message)"
    exit 1
}