# Platform Infrastructure Makefile
# Simplified orchestration layer that delegates to Python scripts

.PHONY: help validate plan apply destroy status clean setup test lint docs
.DEFAULT_GOAL := help

# Default environment
ENV ?= dev


## help: Show this help message
help:
	@python -c "print('Platform Infrastructure Management'); print(); print('Usage:'); print('  make <command> [ENV=environment]'); print(); print('Core Commands:')"
	@python -c "import re; [print(f'  {line.replace(\"##\", \"\").strip()}') for line in open('$(MAKEFILE_LIST)').readlines() if line.startswith('##')]"
	@python -c "print(); print('Examples:'); print('  make validate ENV=dev     # Validate dev environment'); print('  make plan                 # Plan deployment (defaults to dev)'); print('  make apply ENV=staging    # Apply staging environment'); print('  make test-ci ENV=dev      # Run CI-safe tests')"

## setup: Setup development environment
setup:
	@python scripts/manage.py setup

## setup-clean: Clean setup (removes existing venv)
setup-clean:
	@python scripts/manage.py setup --clean

#
# === INFRASTRUCTURE OPERATIONS ===
#

## validate: Validate Terraform configuration
validate: setup
	@python scripts/validate.py $(ENV)

## plan: Create Terraform execution plan
plan: validate
	@python scripts/manage.py plan $(ENV)

## apply: Apply Terraform changes
apply: validate
	@python scripts/deploy.py $(ENV)

## apply-auto: Apply Terraform changes without confirmation (use with caution)
apply-auto: validate
	@python scripts/deploy.py $(ENV) --auto-approve

## destroy: Destroy Terraform infrastructure
destroy:
	@python scripts/deploy.py $(ENV) --destroy

## status: Show current infrastructure status
status:
	@python scripts/status.py $(ENV)

## outputs: Show Terraform outputs
outputs:
	@terraform output

#
# === TESTING ===
#

## test: Run basic validation tests (default)
test: test-ci

## test-ci: Run CI-safe tests (validation + security + format check)
test-ci: setup
	@python scripts/validate.py $(ENV)
	@python scripts/manage.py security-scan

## test-unit: Run unit tests
test-unit: setup
	@python scripts/test_manager.py unit

## test-integration: Run integration tests
test-integration: setup
	@python scripts/test_manager.py integration $(ENV)

## test-coverage: Run tests with coverage
test-coverage: setup
	@python scripts/test_manager.py coverage

## test-post-deploy: Run post-deployment verification
test-post-deploy: setup
	@python scripts/test_manager.py integration $(ENV)

## test-full: Run all available tests
test-full: setup
	@python scripts/test_manager.py all $(ENV)

#
# === CODE QUALITY ===
#

## format: Format code (Terraform + Python)
format:
	@python scripts/manage.py format

## lint: Lint and format code
lint:
	@python scripts/manage.py lint

## security-scan: Run security scanning
security-scan:
	@python scripts/manage.py security-scan

#
# === UTILITIES ===
#

## clean: Clean up temporary files
clean:
	@python scripts/manage.py clean

## check-aws: Verify AWS credentials
check-aws:
	@python scripts/manage.py check-aws


## docs: Generate documentation
docs:
	@python scripts/manage.py docs

#
# === TERRAFORM DIRECT ACCESS ===
#

## init: Initialize Terraform (direct access)
init:
	@python scripts/manage.py init $(ENV) $(if $(NO_WORKSPACE),--no-workspace,)

## terraform: Pass-through to terraform command
terraform:
	@terraform $(ARGS)

#
# === LEGACY COMPATIBILITY ===
#

## pre-commit: Run pre-commit hooks (legacy)
pre-commit:
	@python -c "from scripts.utils import log_warning; log_warning('Use \'make lint\' instead')"
	@python scripts/manage.py format

## setup-tests: Initialize test directory structure (legacy)
setup-tests:
	@python -c "from scripts.utils import log_warning; log_warning('Test structure is automatically managed')"
	@python -c "import os; [os.makedirs(d, exist_ok=True) for d in ['tests/unit', 'tests/integration', 'tests/fixtures']]"
	@touch tests/__init__.py tests/unit/__init__.py tests/integration/__init__.py
