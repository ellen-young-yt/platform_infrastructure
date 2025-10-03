#!/usr/bin/env python3
"""
Simple utilities for Terraform management.

Basic logging, file operations, and constants without unnecessary complexity.
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple, Union, overload, Literal

from environment import (
    ExecutionEnvironment,
    VENV_DIR_NAME,
    REQUIREMENTS_FILE,
)


# Global environment instance
_env = ExecutionEnvironment()


def log_info(message: str) -> None:
    """Log info message."""
    print(f"\033[96m[INFO]\033[0m {message}")


def log_success(message: str) -> None:
    """Log success message."""
    print(f"\033[92m[SUCCESS]\033[0m {message}")


def log_warning(message: str) -> None:
    """Log warning message."""
    print(f"\033[93m[WARNING]\033[0m {message}")


def log_error(message: str) -> None:
    """Log error message."""
    print(f"\033[91m[ERROR]\033[0m {message}")


def log_step(message: str) -> None:
    """Log step message."""
    print(f"\033[94m[STEP]\033[0m {message}")


@overload
def run_command(
    cmd: List[str], cwd: Optional[Path] = None, capture: bool = True, *, simple: Literal[True]
) -> bool: ...


@overload
def run_command(
    cmd: List[str], cwd: Optional[Path] = None, capture: bool = True, *, simple: Literal[False]
) -> Tuple[bool, str, str]: ...


@overload
def run_command(
    cmd: List[str], cwd: Optional[Path] = None, capture: bool = True
) -> Tuple[bool, str, str]: ...


def run_command(
    cmd: List[str], cwd: Optional[Path] = None, capture: bool = True, simple: bool = False
) -> Union[bool, Tuple[bool, str, str]]:
    """
    Consolidated command runner with cross-platform support.

    Args:
        cmd: Command as list of strings
        cwd: Working directory (defaults to current directory)
        capture: Whether to capture output (True) or stream to console (False)
        simple: If True, return only bool success status (for backward compatibility)

    Returns:
        If simple=True: bool (success status)
        If simple=False: Tuple[bool, str, str] (success, stdout, stderr)
    """
    # Determine working directory
    if cwd is None:
        cwd = Path(__file__).parent.parent

    # Set up environment to include virtual environment PATH
    env = os.environ.copy()

    # Use global environment instance for path setup
    if _env.should_use_venv() and _env.venv_path.exists():
        venv_scripts = _env.venv_scripts_dir
        if venv_scripts.exists():
            env["PATH"] = str(venv_scripts) + os.pathsep + env.get("PATH", "")

    # Determine if we need shell=True for this command
    # Python packages installed in venv need shell=True on Windows for .cmd files
    python_tools = {"pytest", "coverage", "black", "flake8", "mypy", "pre-commit", "checkov"}
    use_shell = _env.is_windows and cmd[0] in python_tools

    try:
        if capture:
            result = subprocess.run(
                cmd, cwd=cwd, capture_output=True, text=True, check=False, env=env, shell=use_shell
            )
            success = result.returncode == 0
            if not success:
                log_error(f"Command failed: {' '.join(cmd)}")
                if result.stderr:
                    log_error(f"Error: {result.stderr}")

            if simple:
                return success
            return success, result.stdout, result.stderr
        else:
            returncode = subprocess.call(cmd, cwd=cwd, env=env, shell=use_shell)
            success = returncode == 0
            if not success:
                log_error(f"Command failed: {' '.join(cmd)}")

            if simple:
                return success
            return success, "", ""
    except FileNotFoundError:
        error_msg = f"Command not found: {cmd[0]}"
        log_error(error_msg)
        if simple:
            return False
        return False, "", error_msg


def setup_environment(clean: bool = False) -> bool:
    """Set up Python virtual environment and install dependencies."""
    log_step("Setting up development environment...")

    # Log environment detection
    log_info(_env.get_environment_info())

    # Handle container environments differently
    if not _env.should_use_venv():
        log_info("Installing dependencies with system pip...")
        pip_cmd = _env.get_pip_command()
        if not pip_cmd:
            log_error("Could not find system pip")
            return False

        install_args = (
            [pip_cmd, "install"] + _env.get_pip_install_args() + ["-r", REQUIREMENTS_FILE]
        )
        if not run_command(install_args, cwd=_env.root_dir, simple=True):
            log_error("Failed to install dependencies")
            return False

        log_success("Dependencies installed successfully (system-wide)")
        return True

    # Native environment - use virtual environment
    venv_path = _env.venv_path

    # Clean existing environment if requested
    if clean and venv_path.exists():
        log_info("Removing existing virtual environment...")
        shutil.rmtree(venv_path)

    # Create virtual environment
    if not venv_path.exists():
        log_info("Creating virtual environment...")
        python_cmd = _env.python_executable
        venv_cmd = [python_cmd, "-m", "venv", VENV_DIR_NAME]
        if not run_command(venv_cmd, cwd=_env.root_dir, simple=True):
            log_error("Failed to create virtual environment")
            return False
        log_success("Virtual environment created")
    else:
        log_info("Virtual environment already exists")

    # Find pip command
    pip_cmd = _env.get_pip_command()
    if not pip_cmd:
        log_error("Could not find pip in virtual environment")
        return False

    # Install dependencies
    log_info("Installing dependencies...")
    install_args = [pip_cmd, "install", "-r", REQUIREMENTS_FILE]
    if not run_command(install_args, cwd=_env.root_dir, simple=True):
        log_error("Failed to install dependencies")
        return False

    log_success("Dependencies installed successfully")
    log_info(f"Virtual environment ready at: {venv_path}")

    # Install pre-commit hooks if not already installed
    precommit_hook = _env.git_hooks_dir / "pre-commit"

    if not precommit_hook.exists():
        log_info("Installing pre-commit hooks...")
        if not run_command(["pre-commit", "install"], cwd=_env.root_dir, simple=True):
            log_warning("Failed to install pre-commit hooks - you may need to run 'pre-commit install' manually")
        else:
            log_success("Pre-commit hooks installed")
    else:
        log_info("Pre-commit hooks already installed")

    # Show appropriate activation command
    if _env.is_windows:
        log_info(f"Activate with: {venv_path}\\Scripts\\activate")
    else:
        log_info(f"Activate with: source {venv_path}/bin/activate")

    return True


def format_terraform() -> bool:
    """Format Terraform files."""
    log_step("Formatting Terraform files...")

    success = run_command(["terraform", "fmt", "-recursive"], capture=False, simple=True)
    if not success:
        log_error("Terraform formatting failed")
        return False

    log_success("Terraform files formatted")
    return True


def format_python() -> bool:
    """Format Python files using black."""
    log_step("Formatting Python files...")

    success = run_command(
        ["black", "scripts/", "tests/", "--line-length=100"], capture=False, simple=True
    )
    if not success:
        log_error("Python formatting failed")
        return False

    log_success("Python files formatted")
    return True


def format_all() -> bool:
    """Format both Terraform and Python files."""
    terraform_success = format_terraform()
    python_success = format_python()

    if terraform_success and python_success:
        log_success("All files formatted successfully")
        return True
    else:
        log_error("Some formatting operations failed")
        return False


def lint_python() -> bool:
    """Lint Python files using flake8 and mypy."""
    log_step("Linting Python files...")

    # Run flake8 - show output directly to console
    log_info("Running flake8...")
    flake8_success = run_command(
        ["flake8", "scripts/", "tests/", "--max-line-length=100"], capture=False, simple=True
    )
    if not flake8_success:
        log_error("Flake8 linting failed")

    # Run mypy on scripts only (as configured in pre-commit)
    log_info("Running mypy...")
    mypy_success = run_command(
        ["mypy", "scripts/", "--ignore-missing-imports"], capture=False, simple=True
    )
    if not mypy_success:
        log_error("MyPy type checking failed")

    if flake8_success and mypy_success:
        log_success("Python linting completed successfully")
        return True
    else:
        log_error("Python linting failed")
        return False


def lint_terraform() -> bool:
    """Lint Terraform files using terraform validate and tflint."""
    log_step("Linting Terraform files...")

    # Run terraform validate - show output directly to console
    log_info("Running terraform validate...")
    validate_success = run_command(["terraform", "validate"], capture=False, simple=True)
    if not validate_success:
        log_error("Terraform validation failed")

    # Note: tflint requires separate installation and configuration
    # For now, just run terraform validate
    if validate_success:
        log_success("Terraform linting completed successfully")
        return True
    else:
        log_error("Terraform linting failed")
        return False


def lint_all() -> bool:
    """Lint both Terraform and Python files."""
    terraform_success = lint_terraform()
    python_success = lint_python()

    if terraform_success and python_success:
        log_success("All linting completed successfully")
        return True
    else:
        log_error("Some linting operations failed")
        return False


def generate_docs() -> bool:
    """Generate documentation using terraform-docs if available."""
    log_step("Generating documentation...")

    # Check if terraform-docs is available
    if not run_command(["terraform-docs", "--version"], simple=True):
        log_warning(
            "terraform-docs not found. "
            "Download from https://github.com/terraform-docs/terraform-docs"
        )
        return False

    # Generate docs for main module
    if not run_command(
        ["terraform-docs", "markdown", "table", "--output-file", "README.md", "."], simple=True
    ):
        log_error("Failed to generate documentation")
        return False

    log_success("Documentation generated successfully")
    return True
