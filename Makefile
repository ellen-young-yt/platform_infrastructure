# Platform Infrastructure Makefile
# Provides convenient commands for managing Terraform infrastructure

.PHONY: help validate plan apply destroy status format lint init clean setup

# Default environment
ENV ?= dev

# Colors for output
RED    := \033[31m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m
CYAN   := \033[36m
RESET  := \033[0m

## help: Show this help message
help:
	@echo "$(CYAN)Platform Infrastructure Management$(RESET)"
	@echo ""
	@echo "$(YELLOW)Usage:$(RESET)"
	@echo "  make <command> [ENV=environment]"
	@echo ""
	@echo "$(YELLOW)Available commands:$(RESET)"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/  /'
	@echo ""
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make validate ENV=dev     # Validate dev environment"
	@echo "  make plan                 # Plan deployment (defaults to dev)"
	@echo "  make apply ENV=staging    # Apply staging environment"
	@echo "  make destroy ENV=dev      # Destroy dev environment"

## setup: Setup development environment (virtual env + dependencies)
setup: init
	@echo "$(BLUE)Setting up development environment...$(RESET)"
	@python -c "import os; print('$(BLUE)Creating new virtual environment...$(RESET)') if not os.path.exists('infra') else print('$(BLUE)Virtual environment already exists, checking dependencies...$(RESET)')"
	-@python -m venv infra 2>nul
	@echo "$(BLUE)Installing/updating dependencies...$(RESET)"
	-@infra\\Scripts\\pip.exe install -r requirements.txt --upgrade 2>nul
	-@infra/bin/pip install -r requirements.txt --upgrade 2>/dev/null
	@echo "$(GREEN)Setup complete!$(RESET)"
	@echo "$(GREEN)Windows: infra\\Scripts\\activate$(RESET)"
	@echo "$(GREEN)Linux/Mac: source infra/bin/activate$(RESET)"

## setup-clean: Force clean setup (removes existing venv)
setup-clean:
	@echo "$(BLUE)Force cleaning and recreating virtual environment...$(RESET)"
	@rm -rf infra 2>/dev/null || rmdir /s /q infra 2>nul || true
	@echo "$(BLUE)Creating new virtual environment...$(RESET)"
	python -m venv infra
	@echo "$(BLUE)Installing dependencies...$(RESET)"
	@cd infra && cd Scripts && pip install -r ../../requirements.txt || true
	@cd infra && cd bin && pip install -r ../../requirements.txt || true
	@echo "$(GREEN)Clean setup complete!$(RESET)"
	@echo "$(GREEN)Windows: infra\\Scripts\\activate$(RESET)"
	@echo "$(GREEN)Linux/Mac: source infra/bin/activate$(RESET)"

## validate: Validate Terraform configuration
validate:
	@echo "$(BLUE)Validating Terraform configuration for $(ENV)...$(RESET)"
	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/validate.ps1', '-Environment', '$(ENV)'] if os.name == 'nt' else ['./scripts/validate.sh', '$(ENV)'])"

## format: Format Terraform files
format:
	@echo "$(BLUE)Formatting Terraform files...$(RESET)"
	terraform fmt -recursive

## lint: Run Terraform linting
lint: format
	@echo "$(BLUE)Running Terraform lint checks...$(RESET)"
	terraform validate
	@if command -v tflint > /dev/null 2>&1; then \
		tflint --recursive; \
	else \
		echo "$(YELLOW)Warning: tflint not installed, skipping lint checks$(RESET)"; \
	fi

## init: Initialize Terraform
init:
	@echo "$(BLUE)Initializing Terraform...$(RESET)"
	terraform init

## plan: Create Terraform execution plan
plan: validate
	@echo "$(BLUE)Creating Terraform plan for $(ENV)...$(RESET)"
	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/deploy.ps1', '-Environment', '$(ENV)', '-Action', 'plan'] if os.name == 'nt' else ['./scripts/deploy.sh', '$(ENV)', 'plan'])"

# ## apply: Apply Terraform changes
# apply: validate
# 	@echo "$(BLUE)Applying Terraform changes for $(ENV)...$(RESET)"
# 	@echo "$(YELLOW)This will create/modify infrastructure in your AWS account!$(RESET)"
# 	@python -c "import sys; resp = input('Are you sure you want to continue? [y/N]: '); sys.exit(0 if resp.strip() in ('y', 'yes') else 1)"
# 	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/deploy.ps1', '-Environment', '$(ENV)', '-Action', 'apply'] if os.name == 'nt' else ['./scripts/deploy.sh', '$(ENV)', 'apply'])"

## apply: Apply Terraform changes
apply: validate
	@echo "$(BLUE)Applying Terraform changes for $(ENV)...$(RESET)"
	@echo "$(YELLOW)This will create/modify infrastructure in your AWS account!$(RESET)"
	@python scripts/deploy.py apply $(ENV)

## apply-auto: Apply Terraform changes without confirmation (use with caution)
apply-auto: validate
	@echo "$(RED)Auto-applying Terraform changes for $(ENV)...$(RESET)"
	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/deploy.ps1', '-Environment', '$(ENV)', '-Action', 'apply', '-AutoApprove'] if os.name == 'nt' else ['./scripts/deploy.sh', '$(ENV)', 'apply', '--auto-approve'])"

## destroy: Destroy Terraform infrastructure
destroy:
	@echo "$(RED)Destroying Terraform infrastructure for $(ENV)...$(RESET)"
	@echo "$(RED)WARNING: This will DELETE all infrastructure!$(RESET)"
	@read -p "Type 'yes' to confirm destruction: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/deploy.ps1', '-Environment', '$(ENV)', '-Action', 'destroy'] if os.name == 'nt' else ['./scripts/deploy.sh', '$(ENV)', 'destroy'])"

## status: Show current infrastructure status
status:
	@echo "$(BLUE)Checking infrastructure status for $(ENV)...$(RESET)"
	@python -c "import os, subprocess; subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/status.ps1', '-Environment', '$(ENV)'] if os.name == 'nt' else ['sh', '-c', 'echo \"Status script not available for this platform\"; terraform show -no-color'])"

## outputs: Show Terraform outputs
outputs:
	@echo "$(BLUE)Terraform outputs for $(ENV):$(RESET)"
	terraform output

## clean: Clean up temporary files
clean:
	@echo "$(BLUE)Cleaning up temporary files...$(RESET)"
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f *.tfplan
	rm -f crash.log
	find . -name "*.tmp" -delete
	@echo "$(GREEN)Cleanup complete$(RESET)"

## check-aws: Verify AWS credentials and permissions
check-aws:
	@echo "$(BLUE)Checking AWS credentials...$(RESET)"
	aws sts get-caller-identity
	@echo "$(GREEN)AWS credentials are valid$(RESET)"

## cost-estimate: Show estimated costs for the environment
cost-estimate:
	@echo "$(BLUE)Cost estimate for $(ENV) environment:$(RESET)"
	@echo "  NAT Gateway: ~$$45/month ($$1.50/day)"
	@echo "  ECS Fargate: ~$$12/month ($$0.40/day)"
	@echo "  Secrets Manager: ~$$1.60/month ($$0.05/day)"
	@echo "  Other services: ~$$5/month ($$0.17/day)"
	@echo "  $(YELLOW)Total: ~$$63/month (~$$2.12/day)$(RESET)"

## security-scan: Run security scanning with Checkov
security-scan:
	@echo "$(BLUE)Running security scan with Checkov...$(RESET)"
	@if command -v checkov > /dev/null 2>&1; then \
		checkov -f . --framework terraform; \
	elif [ -f "infra/bin/checkov" ]; then \
		infra/bin/checkov -f . --framework terraform; \
	elif [ -f "infra/Scripts/checkov.exe" ]; then \
		infra/Scripts/checkov.exe -f . --framework terraform; \
	else \
		echo "$(YELLOW)Checkov not found. Install with: pip install checkov$(RESET)"; \
	fi

## pre-commit: Run pre-commit hooks
pre-commit:
	@echo "$(BLUE)Running pre-commit hooks...$(RESET)"
	@if command -v pre-commit > /dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		echo "$(YELLOW)Pre-commit not installed. Run 'make setup' first$(RESET)"; \
	fi

## docs: Generate documentation
docs:
	@echo "$(BLUE)Generating documentation...$(RESET)"
	@if command -v terraform-docs > /dev/null 2>&1; then \
		terraform-docs markdown table . > README-GENERATED.md; \
		echo "$(GREEN)Documentation generated in README-GENERATED.md$(RESET)"; \
	else \
		echo "$(YELLOW)terraform-docs not installed$(RESET)"; \
	fi

# Development workflow targets
## dev-deploy: Full development deployment (validate -> plan -> apply)
dev-deploy: ENV = dev
dev-deploy: validate plan
	@echo "$(BLUE)Starting development deployment...$(RESET)"
	$(MAKE) apply ENV=dev

## dev-destroy: Destroy development environment
dev-destroy: ENV = dev
dev-destroy:
	$(MAKE) destroy ENV=dev

## quick-check: Quick validation and format check
quick-check: format validate
	@echo "$(GREEN)Quick check passed!$(RESET)"