#!/usr/bin/env pwsh
<#
.SYNOPSIS
Show status of deployed infrastructure

.DESCRIPTION
This script shows the current status of deployed infrastructure,
including resource counts, costs, and access information.

.PARAMETER Environment
The environment to check (dev, staging, prod)

.EXAMPLE
.\status.ps1 -Environment dev
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

Write-Info "=== Infrastructure Status ==="
Write-Info "Environment: $Environment"

function Get-TerraformState {
    Write-Step "Checking Terraform state..."
    
    Push-Location $ROOT_DIR
    try {
        # Check if state file exists
        if (-not (Test-Path "terraform.tfstate")) {
            Write-Warning "No Terraform state found - infrastructure not deployed"
            return $null
        }
        
        # Get state list
        $resources = terraform state list 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not read Terraform state"
            return $null
        }
        
        return $resources
    } finally {
        Pop-Location
    }
}

function Show-ResourceCounts {
    param($Resources)
    
    if (-not $Resources) {
        Write-Warning "No resources found"
        return
    }
    
    Write-Step "Resource Summary:"
    
    $counts = @{}
    foreach ($resource in $Resources) {
        $type = ($resource -split '\.')[0]
        if ($counts.ContainsKey($type)) {
            $counts[$type]++
        } else {
            $counts[$type] = 1
        }
    }
    
    foreach ($type in $counts.Keys | Sort-Object) {
        Write-Info "  $type: $($counts[$type])"
    }
    
    Write-Info "  Total resources: $($Resources.Count)"
}

function Get-TerraformOutputs {
    Write-Step "Getting Terraform outputs..."
    
    Push-Location $ROOT_DIR
    try {
        $outputs = terraform output -json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not get Terraform outputs"
            return $null
        }
        
        return $outputs | ConvertFrom-Json
    } finally {
        Pop-Location
    }
}

function Show-AccessInformation {
    param($Outputs)
    
    if (-not $Outputs) {
        Write-Warning "No outputs available"
        return
    }
    
    Write-Step "Access Information:"
    
    # Show key outputs
    foreach ($key in $Outputs.PSObject.Properties.Name | Sort-Object) {
        $output = $Outputs.$key
        if ($output.sensitive -eq $true) {
            Write-Info "  $key: <sensitive>"
        } else {
            $value = $output.value
            if ($value -is [string] -and $value.Length -gt 80) {
                Write-Info "  $key: $($value.Substring(0, 77))..."
            } else {
                Write-Info "  $key: $value"
            }
        }
    }
}

function Show-CostEstimate {
    Write-Step "Current cost estimate..."
    
    Write-Info "Estimated daily costs for active resources:"
    Write-Info "  NAT Gateway: ~`$1.50/day"
    Write-Info "  ECS Fargate (if running): ~`$0.40/day"
    Write-Info "  Secrets Manager: ~`$0.05/day"
    Write-Info "  Other services: ~`$0.17/day"
    Write-Info "  Estimated total: ~`$2.12/day"
    
    Write-Warning "Remember to destroy resources when not needed!"
}

function Show-QuickCommands {
    Write-Step "Quick commands:"
    
    Write-Info "Deploy/Update: .\deploy.ps1 -Environment $Environment -Action apply"
    Write-Info "Plan changes: .\deploy.ps1 -Environment $Environment -Action plan"
    Write-Info "Destroy all: .\deploy.ps1 -Environment $Environment -Action destroy"
    Write-Info "Validate config: .\validate.ps1 -Environment $Environment"
    
    if ($Environment -eq "dev") {
        Write-Info ""
        Write-Info "Access Metabase (dev): Use ECS port forwarding (see outputs)"
        Write-Info "Access Airflow: Check ECS service in AWS Console"
    }
}

# Main execution
try {
    $resources = Get-TerraformState
    
    if ($resources) {
        Write-Success "Infrastructure is deployed"
        Show-ResourceCounts -Resources $resources
        
        $outputs = Get-TerraformOutputs
        Show-AccessInformation -Outputs $outputs
        
        Show-CostEstimate
    } else {
        Write-Warning "Infrastructure is not deployed"
        Write-Info "Run deployment script to deploy: .\deploy.ps1 -Environment $Environment -Action apply"
    }
    
    Show-QuickCommands
    
} catch {
    Write-Error "Status check failed: $($_.Exception.Message)"
    exit 1
}