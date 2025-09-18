#!/usr/bin/env python3
"""
Simple Terraform Manager

A consolidated manager for all Terraform operations including validation,
deployment, and status checking. No unnecessary abstractions or complexity.
"""

import json
import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Any, List, Optional, Union, TypedDict, NotRequired, Callable

from utils import log_info, log_success, log_warning, log_error, log_step, run_command
from environment import VALID_ENVIRONMENTS, ExecutionEnvironment, ExecutionContext


@dataclass
class ValidationCheck:
    """A validation check with name and function."""

    name: str
    func: Callable[[], bool]


class TerraformOutput(TypedDict):
    """Structure for Terraform output values."""

    value: Any
    type: str
    sensitive: Optional[bool]


class InfrastructureStatus(TypedDict):
    """Structure for infrastructure status response."""

    environment: str
    workspace_selected: bool
    resources: List[str]
    outputs: Union[Dict[str, TerraformOutput], Dict[str, str]]
    error: NotRequired[str]
    execution_environment: NotRequired[Dict[str, str]]


class TerraformManager:
    """Simple, consolidated Terraform operations manager."""

    def __init__(self, environment: Optional[str] = None):
        """Initialize with optional environment."""
        self.environment = environment
        self.root_dir = Path(__file__).parent.parent
        self.script_dir = Path(__file__).parent
        self.env = ExecutionEnvironment()

    def validate_environment(self, environment: str) -> bool:
        """Validate environment name."""
        if not environment:
            log_error("Environment cannot be empty")
            return False

        if environment not in VALID_ENVIRONMENTS:
            log_error(
                f"Invalid environment '{environment}'. \
                    Must be one of: {', '.join(VALID_ENVIRONMENTS)}"
            )
            return False

        return True

    def validate_aws_credentials(self) -> bool:
        """Validate AWS credentials."""
        log_step("Validating AWS credentials...")

        success, stdout, stderr = run_command(
            ["aws", "sts", "get-caller-identity"], cwd=self.root_dir
        )

        if not success:
            log_error("AWS credentials are invalid or not configured")
            return False

        try:
            identity = json.loads(stdout) if stdout.strip() else {}
            account = identity.get("Account", "Unknown")
            log_success(f"AWS credentials are valid (Account: {account})")
            return True
        except json.JSONDecodeError:
            log_error("Could not parse AWS identity response")
            return False

    def get_var_files(self, environment: str) -> List[str]:
        """Get list of variable files for the environment."""
        var_files = []

        # Common variables file
        common_vars = self.root_dir / "environments" / "common.tfvars"
        if common_vars.exists():
            var_files.extend(["-var-file", str(common_vars)])

        # Environment-specific variables file
        env_vars = self.root_dir / "environments" / f"{environment}.tfvars"
        if env_vars.exists():
            var_files.extend(["-var-file", str(env_vars)])

        return var_files

    def validate_tfvars_files(self, environment: str) -> bool:
        """Validate that required tfvars files exist."""
        log_step("Validating variables files...")

        common_tfvars = self.root_dir / "environments" / "common.tfvars"
        env_tfvars = self.root_dir / "environments" / f"{environment}.tfvars"

        if not common_tfvars.exists():
            log_error(f"Common variables file not found: {common_tfvars}")
            return False

        if not env_tfvars.exists():
            log_error(f"Environment variables file not found: {env_tfvars}")
            return False

        log_success("Variables files are valid")
        return True

    def terraform_init(self, environment: str) -> bool:
        """Initialize Terraform."""
        log_step(f"Initializing Terraform for {environment}...")

        success, _, _ = run_command(["terraform", "init"], cwd=self.root_dir, capture=False)

        if success:
            log_success("Terraform initialized successfully")
        else:
            log_error("Terraform initialization failed")

        return success

    def select_terraform_workspace(self, environment: str) -> bool:
        """Select or create Terraform workspace."""
        log_step(f"Selecting Terraform workspace '{environment}'...")

        # Try to select the workspace
        success, _, _ = run_command(
            ["terraform", "workspace", "select", environment], cwd=self.root_dir
        )

        if not success:
            log_info(f"Workspace '{environment}' doesn't exist, creating it...")
            success, _, stderr = run_command(
                ["terraform", "workspace", "new", environment], cwd=self.root_dir
            )
            if not success:
                log_error(f"Failed to create workspace '{environment}'")
                return False

        # Verify current workspace
        success, stdout, _ = run_command(["terraform", "workspace", "show"], cwd=self.root_dir)
        if success and stdout.strip() == environment:
            log_success(f"Using Terraform workspace: {environment}")
            return True
        else:
            log_warning("Could not verify current workspace")
            return True  # Continue anyway

    def terraform_validate(self) -> bool:
        """Validate Terraform configuration."""
        log_step("Validating Terraform configuration...")

        success, _, _ = run_command(["terraform", "validate"], cwd=self.root_dir)

        if success:
            log_success("Terraform configuration is valid")
        else:
            log_error("Terraform configuration validation failed")

        return success

    def terraform_format_check(self) -> bool:
        """Check Terraform formatting."""
        log_step("Checking Terraform formatting...")

        success, _, _ = run_command(["terraform", "fmt", "-check", "-recursive"], cwd=self.root_dir)

        if success:
            log_success("Terraform files are properly formatted")
        else:
            log_error("Terraform files need formatting - run 'terraform fmt -recursive'")

        return success

    def terraform_format_fix(self) -> bool:
        """Fix Terraform formatting."""
        log_step("Formatting Terraform files...")

        success, _, _ = run_command(["terraform", "fmt", "-recursive"], cwd=self.root_dir)

        if success:
            log_success("Terraform files formatted")
        else:
            log_error("Terraform formatting failed")

        return success

    def terraform_plan(self, environment: str, plan_file: Optional[str] = None) -> bool:
        """Create Terraform plan."""
        log_step(f"Creating Terraform plan for {environment}...")

        var_files = self.get_var_files(environment)
        cmd = ["terraform", "plan"] + var_files

        # Context-aware plan options
        if self.env.context in (ExecutionContext.CI, ExecutionContext.CONTAINER):
            cmd.append("-input=false")

        if plan_file:
            cmd.extend(["-out", plan_file])

        success, _, _ = run_command(cmd, cwd=self.root_dir, capture=False)

        if success:
            log_success("Terraform plan created successfully")
        else:
            log_error("Terraform plan creation failed")
            if self.env.context == ExecutionContext.NATIVE:
                log_step("Tip: Check AWS credentials and network connectivity")

        return success

    def terraform_apply(
        self, environment: str, auto_approve: bool = False, plan_file: Optional[str] = None
    ) -> bool:
        """Apply Terraform changes."""
        log_step(f"Applying Terraform changes for {environment}...")

        if plan_file:
            cmd = ["terraform", "apply"]
            # Always auto-approve when using plan files in CI/Container
            if auto_approve or self.env.context in (
                ExecutionContext.CI,
                ExecutionContext.CONTAINER,
            ):
                cmd.append("-auto-approve")
            cmd.append(plan_file)
        else:
            var_files = self.get_var_files(environment)
            cmd = ["terraform", "apply"] + var_files
            if auto_approve or self.env.context in (
                ExecutionContext.CI,
                ExecutionContext.CONTAINER,
            ):
                cmd.append("-auto-approve")

        # Add input=false for non-interactive environments
        if self.env.context in (ExecutionContext.CI, ExecutionContext.CONTAINER):
            if "-input=false" not in cmd:
                cmd.insert(-1, "-input=false")

        success, _, _ = run_command(cmd, cwd=self.root_dir, capture=False)

        if success:
            log_success("Terraform apply completed successfully")
        else:
            log_error("Terraform apply failed")
            if self.env.context == ExecutionContext.NATIVE:
                log_step("Tip: Review the plan output above for specific error details")

        return success

    def terraform_destroy(self, environment: str, auto_approve: bool = False) -> bool:
        """Destroy Terraform infrastructure."""
        log_step(f"Destroying Terraform infrastructure for {environment}...")

        # Skip interactive confirmation in CI/Container environments
        if not auto_approve and self.env.context == ExecutionContext.NATIVE:
            log_warning("This will destroy ALL infrastructure in the environment!")
            response = input("Type 'yes' to proceed with destruction: ").strip()
            if response != "yes":
                log_info("Destruction cancelled")
                return True
        elif self.env.context in (ExecutionContext.CI, ExecutionContext.CONTAINER):
            log_warning(
                "Running destroy in automated environment - proceeding without confirmation"
            )

        var_files = self.get_var_files(environment)
        cmd = ["terraform", "destroy"] + var_files + ["-auto-approve"]

        # Add input=false for non-interactive environments
        if self.env.context in (ExecutionContext.CI, ExecutionContext.CONTAINER):
            cmd.insert(-1, "-input=false")

        success, _, _ = run_command(cmd, cwd=self.root_dir, capture=False)

        if success:
            log_success("Terraform destroy completed successfully")
        else:
            log_error("Terraform destroy failed")

        return success

    def get_terraform_outputs(self) -> Union[Dict[str, TerraformOutput], Dict[str, str]]:
        """Get Terraform outputs."""
        log_step("Getting Terraform outputs...")

        success, stdout, stderr = run_command(["terraform", "output", "-json"], cwd=self.root_dir)

        if not success:
            log_warning("Could not get Terraform outputs")
            return {"error": stderr or "Could not get Terraform outputs"}

        try:
            return json.loads(stdout) if stdout.strip() else {}
        except json.JSONDecodeError:
            log_warning("Could not parse Terraform outputs")
            return {"error": "Could not parse Terraform outputs"}

    def get_terraform_state(self) -> Optional[List[str]]:
        """Get list of resources from Terraform state."""
        log_step("Checking Terraform state...")

        success, stdout, _ = run_command(["terraform", "state", "list"], cwd=self.root_dir)

        if not success:
            return None

        resources = [line.strip() for line in stdout.split("\n") if line.strip()]
        return resources

    def validate_prerequisites(self, environment: str) -> bool:
        """Validate all prerequisites for deployment."""
        log_step("Validating deployment prerequisites...")

        checks = [
            ValidationCheck("Environment", lambda: self.validate_environment(environment)),
            ValidationCheck("AWS credentials", lambda: self.validate_aws_credentials()),
            ValidationCheck("Variables files", lambda: self.validate_tfvars_files(environment)),
            ValidationCheck("Terraform syntax", lambda: self.terraform_validate()),
            ValidationCheck("Terraform formatting", lambda: self.terraform_format_check()),
        ]

        all_passed = True
        for check in checks:
            log_info(f"Checking {check.name}...")
            try:
                result = check.func()
                if result:
                    log_success(f"{check.name}: PASSED")
                else:
                    log_error(f"{check.name}: FAILED")
                    all_passed = False
            except (FileNotFoundError, OSError) as e:
                log_error(f"{check.name}: FAILED - File/System error: {e}")
                all_passed = False
            except json.JSONDecodeError as e:
                log_error(f"{check.name}: FAILED - JSON parsing error: {e}")
                all_passed = False
            except Exception as e:
                log_error(f"{check.name}: FAILED - Unexpected error: {e}")
                all_passed = False

        if all_passed:
            log_success("All deployment prerequisites validated")
        else:
            log_error("Some prerequisite checks failed")

        return all_passed

    def deploy_infrastructure(
        self, environment: str, auto_approve: bool = False, skip_validation: bool = False
    ) -> bool:
        """Complete infrastructure deployment workflow."""
        log_step(f"Starting infrastructure deployment for '{environment}'...")

        # Validate prerequisites unless skipped
        if not skip_validation:
            if not self.validate_prerequisites(environment):
                log_error("Prerequisite validation failed. Use skip_validation=True to override.")
                return False

        # Initialize Terraform
        if not self.terraform_init(environment):
            return False

        # Select workspace
        if not self.select_terraform_workspace(environment):
            return False

        # Create and apply deployment
        plan_file = f"deployment-{environment}-{int(time.time())}.tfplan"

        if not self.terraform_plan(environment, plan_file):
            return False

        if not self.terraform_apply(environment, auto_approve, plan_file):
            return False

        # Clean up plan file
        try:
            os.remove(plan_file)
        except OSError:
            pass

        log_success(f"Infrastructure deployment for '{environment}' completed successfully")
        return True

    def destroy_infrastructure(self, environment: str, confirm: bool = False) -> bool:
        """Complete infrastructure destruction workflow."""
        log_step(f"Starting infrastructure destruction for '{environment}'...")

        # Initialize and select workspace
        if not self.terraform_init(environment):
            return False

        if not self.select_terraform_workspace(environment):
            return False

        # Destroy infrastructure
        if not self.terraform_destroy(environment, auto_approve=confirm):
            return False

        log_success(f"Infrastructure destruction for '{environment}' completed successfully")
        return True

    def get_infrastructure_status(self, environment: str) -> InfrastructureStatus:
        """Get comprehensive infrastructure status."""
        log_step(f"Checking infrastructure status for '{environment}'...")

        status: InfrastructureStatus = {
            "environment": environment,
            "workspace_selected": False,
            "resources": [],
            "outputs": {},
        }

        try:
            # Select workspace
            status["workspace_selected"] = self.select_terraform_workspace(environment)

            # Get state and outputs
            resources = self.get_terraform_state()
            if resources:
                status["resources"] = resources

            outputs = self.get_terraform_outputs()
            if "error" not in outputs:
                status["outputs"] = outputs

        except (FileNotFoundError, OSError) as e:
            status["error"] = f"File/System error: {e}"
        except json.JSONDecodeError as e:
            status["error"] = f"JSON parsing error: {e}"
        except Exception as e:
            status["error"] = f"Unexpected error: {e}"

        return status

    def security_scan(self) -> bool:
        """Run basic security scanning if Checkov is available."""
        log_step("Running security scan...")

        # Check if checkov is available
        success, _, _ = run_command(["checkov", "--version"], cwd=self.root_dir)
        if not success:
            log_warning("Checkov not found. Install with: pip install checkov")
            return True  # Don't fail if not available

        # Run checkov scan
        cmd = [
            "checkov",
            "-d",
            ".",
            "--framework",
            "terraform",
            "--quiet",
            "--compact",
            "--download-external-modules",
            "false",
        ]

        success, _, _ = run_command(cmd, cwd=self.root_dir)

        if success:
            log_success("Security scan completed successfully")
        else:
            log_error("Security scan found issues")

        return success

    def clean_temporary_files(self) -> bool:
        """Clean up temporary files."""
        log_step("Cleaning up temporary files...")
        log_step(f"Environment: {self.env.get_environment_info()}")

        # More aggressive cleanup in CI/Container environments
        if self.env.context in (ExecutionContext.CI, ExecutionContext.CONTAINER):
            cleanup_patterns = [
                ".terraform",
                "terraform.tfstate.backup",
                "crash.log",
                "*.tfplan",
                "*.terraform.lock.hcl",
            ]
        else:
            # Preserve lock file in native development
            cleanup_patterns = [".terraform", "terraform.tfstate.backup", "crash.log", "*.tfplan"]

        cleaned_items = []

        for pattern in cleanup_patterns:
            if pattern.startswith(".") or "*" not in pattern:
                # Directory or specific file
                path = self.root_dir / pattern
                if path.exists():
                    if path.is_dir():
                        import shutil

                        shutil.rmtree(path)
                    else:
                        path.unlink()
                    cleaned_items.append(str(path))
            else:
                # Glob pattern
                for match in self.root_dir.glob(pattern):
                    if match.exists():
                        match.unlink()
                        cleaned_items.append(str(match))

        if cleaned_items:
            log_success(f"Cleaned {len(cleaned_items)} items")
            if self.env.context == ExecutionContext.NATIVE:
                for item in cleaned_items:
                    log_info(f"  Removed: {item}")
        else:
            log_info("No temporary files found to clean")

        return True
