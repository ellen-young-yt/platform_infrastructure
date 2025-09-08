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
	@python -c "import re; [print(f'  {line.replace(\"##\", \"\").strip()}') for line in open('$(MAKEFILE_LIST)').readlines() if line.startswith('##')]"
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
	-@python -m venv infra
	@echo "$(BLUE)Installing/updating dependencies...$(RESET)"
	-@infra/Scripts/pip.exe install -r requirements.txt --upgrade
	-@infra/bin/pip install -r requirements.txt --upgrade
	@echo "$(GREEN)Setup complete!$(RESET)"
	@echo "$(GREEN)Windows: infra\\Scripts\\activate$(RESET)"
	@echo "$(GREEN)Linux/Mac: source infra/bin/activate$(RESET)"

## setup-clean: Force clean setup (removes existing venv)
setup-clean:
	@echo "$(BLUE)Force cleaning and recreating virtual environment...$(RESET)"
	@python -c "import shutil, os; shutil.rmtree('infra', ignore_errors=True) if os.path.exists('infra') else None"
	@echo "$(BLUE)Creating new virtual environment...$(RESET)"
	python -m venv infra
	@echo "$(BLUE)Installing dependencies...$(RESET)"
	@cd infra && cd Scripts && pip install -r ../../requirements.txt || true
	@cd infra && cd bin && pip install -r ../../requirements.txt || true
	@echo "$(GREEN)Clean setup complete!$(RESET)"
	@echo "$(GREEN)Windows: infra\\Scripts\\activate$(RESET)"
	@echo "$(GREEN)Linux/Mac: source infra/bin/activate$(RESET)"

## validate: Validate Terraform configuration
validate: setup
	@echo "$(BLUE)Validating Terraform configuration for $(ENV)...$(RESET)"
	@python scripts/validate.py $(ENV)

## lint: Run static analysis (formatting, linting, security)
lint: format
	@echo "$(BLUE)Formatting Terraform files...$(RESET)"
	terraform fmt -recursive
	@echo "$(BLUE)Running Terraform linting...$(RESET)"
	@if command -v tflint > /dev/null 2>&1; then \
		tflint --recursive; \
	else \
		echo "$(YELLOW)Warning: tflint not installed, skipping lint checks$(RESET)"; \
	fi
	@echo "$(BLUE)Running security checks...$(RESET)"
	@if command -v checkov > /dev/null 2>&1; then \
		checkov -d . --framework terraform --quiet --compact; \
	else \
		echo "$(YELLOW)Warning: checkov not installed, skipping security checks$(RESET)"; \
	fi

## init: Initialize Terraform
init:
	@echo "$(BLUE)Initializing Terraform...$(RESET)"
	terraform init

## plan: Create Terraform execution plan
plan: validate
	@echo "$(BLUE)Creating Terraform plan for $(ENV)...$(RESET)"
	@python scripts/deploy.py plan $(ENV)

## apply: Apply Terraform changes
apply: plan
	@echo "$(BLUE)Applying Terraform changes for $(ENV)...$(RESET)"
	@echo "$(YELLOW)This will create/modify infrastructure in your AWS account!$(RESET)"
	@python scripts/deploy.py apply $(ENV)

## apply-auto: Apply Terraform changes without confirmation (use with caution)
apply-auto: plan
	@echo "$(RED)Auto-applying Terraform changes for $(ENV)...$(RESET)"
	@python scripts/deploy.py apply $(ENV) --auto-approve

## destroy: Destroy Terraform infrastructure
destroy:
	@echo "$(RED)Destroying Terraform infrastructure for $(ENV)...$(RESET)"
	@echo "$(RED)WARNING: This will DELETE all infrastructure!$(RESET)"
	@python scripts/deploy.py destroy $(ENV)

## status: Show current infrastructure status
status:
	@echo "$(BLUE)Checking infrastructure status for $(ENV)...$(RESET)"
	@python scripts/status.py $(ENV)

## outputs: Show Terraform outputs
outputs:
	@echo "$(BLUE)Terraform outputs for $(ENV):$(RESET)"
	terraform output

## clean: Clean up temporary files
clean:
	@echo "$(BLUE)Cleaning up temporary files...$(RESET)"
	@python -c "import shutil, os, glob; shutil.rmtree('.terraform', ignore_errors=True); [os.remove(f) for f in ['terraform.tfstate.backup', 'crash.log'] + glob.glob('*.tfplan') + glob.glob('**/*.tmp', recursive=True) if os.path.exists(f)]"
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
		checkov -d . --framework terraform --config-file .checkov.yml; \
	elif [ -f "infra/bin/checkov" ]; then \
		infra/bin/checkov -d . --framework terraform --config-file .checkov.yml; \
	elif [ -f "infra/Scripts/checkov.exe" ]; then \
		infra/Scripts/checkov.exe -d . --framework terraform --config-file .checkov.yml; \
	else \
		echo "$(YELLOW)Checkov not found. Install with: pip install -e .[dev]$(RESET)"; \
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

## test: Run all tests appropriate for the environment
test: test-unit
	@if [ "$(ENV)" != "prod" ]; then \
		echo "$(BLUE)Running integration tests for $(ENV)...$(RESET)"; \
		python -m pytest tests/integration/ -v --tb=short --env=$(ENV) 2>/dev/null || echo "$(YELLOW)No integration tests found$(RESET)"; \
	else \
		echo "$(YELLOW)Skipping integration tests in production environment$(RESET)"; \
	fi

## test-unit: Run unit tests (fast, no external dependencies)
test-unit: setup
	@echo "$(BLUE)Running unit tests...$(RESET)"
	@if [ -d "tests" ]; then \
		python -m pytest tests/unit/ -v --tb=short || echo "$(YELLOW)No unit tests found$(RESET)"; \
	else \
		echo "$(YELLOW)Tests directory not found. Run 'make setup-tests' to initialize$(RESET)"; \
	fi

## test-integration: Run integration tests (requires ENV to be set)
test-integration: setup
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)ENV variable must be set for integration tests$(RESET)"; \
		echo "$(BLUE)Usage: make test-integration ENV=dev$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running integration tests for $(ENV)...$(RESET)"
	@if [ -d "tests/integration" ]; then \
		python -m pytest tests/integration/ -v --tb=short --env=$(ENV) || echo "$(YELLOW)No integration tests found$(RESET)"; \
	else \
		echo "$(YELLOW)Integration tests directory not found$(RESET)"; \
	fi

## setup-tests: Initialize test directory structure
setup-tests:
	@echo "$(BLUE)Setting up test directory structure...$(RESET)"
	@python -c "import os; [os.makedirs(d, exist_ok=True) for d in ['tests/unit', 'tests/integration', 'tests/fixtures']]"
	@touch tests/__init__.py tests/unit/__init__.py tests/integration/__init__.py
	@echo "$(GREEN)Test structure created. Add pytest to requirements.txt if not already present.$(RESET)"
