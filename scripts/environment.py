#!/usr/bin/env python3
"""
Environment detection and configuration for cross-platform compatibility.

Provides centralized environment detection using enums for type safety and extensibility.
Handles platform detection (Windows, Linux, macOS) and execution context detection
(native, container, CI) to provide appropriate configuration for each environment.
"""

import os
import platform
import subprocess
from enum import Enum, auto
from pathlib import Path
from typing import List, Optional


# Constants
VALID_ENVIRONMENTS = ["dev", "staging", "prod"]
VENV_DIR_NAME = "infra"
REQUIREMENTS_FILE = "requirements.txt"


class Platform(Enum):
    """Platform enumeration for type-safe platform detection."""

    WINDOWS = auto()
    LINUX = auto()
    MACOS = auto()
    UNKNOWN = auto()


class ExecutionContext(Enum):
    """Execution context enumeration for type-safe context detection."""

    NATIVE = auto()  # Native Windows/Linux installation
    CONTAINER = auto()  # Docker containers
    CI = auto()  # GitHub Actions, other CI systems
    WSL = auto()  # Windows Subsystem for Linux (future)


class ExecutionEnvironment:
    """Centralized environment detection and configuration."""

    def __init__(self, root_dir: Optional[Path] = None) -> None:
        """Initialize environment detection."""
        # Detection (computed once at initialization)
        self.platform = self._detect_platform()
        self.context = self._detect_execution_context()
        self.python_executable = self._detect_python_executable()

        # Paths (allow root_dir injection for testing)
        self._root_dir = root_dir or Path(__file__).parent.parent
        self._venv_path = self._root_dir / VENV_DIR_NAME

    # === DETECTION METHODS ===

    def _detect_platform(self) -> Platform:
        """Detect the current platform."""
        system = platform.system().lower()
        if system == "windows":
            return Platform.WINDOWS
        elif system == "linux":
            return Platform.LINUX
        elif system == "darwin":
            return Platform.MACOS
        else:
            return Platform.UNKNOWN

    def _detect_execution_context(self) -> ExecutionContext:
        """Detect execution context."""
        # Check for container indicators
        container_indicators = [
            Path("/.dockerenv").exists(),
            Path("/run/.containerenv").exists(),
            os.environ.get("GITHUB_ACTIONS") == "true",
            os.environ.get("CI") == "true",
            os.environ.get("RUNNER_OS") is not None,
        ]

        if any(container_indicators):
            # Distinguish between CI and generic containers
            if os.environ.get("GITHUB_ACTIONS") == "true":
                return ExecutionContext.CI
            else:
                return ExecutionContext.CONTAINER

        # Future: WSL detection could be added here
        # if self._is_wsl():
        #     return ExecutionContext.WSL

        return ExecutionContext.NATIVE

    def _detect_python_executable(self) -> str:
        """Find appropriate Python executable for the current context."""
        if self.context in (ExecutionContext.CONTAINER, ExecutionContext.CI):
            # In containers and CI, prefer system Python
            for candidate in ["python3", "python"]:
                try:
                    result = subprocess.run(
                        [candidate, "--version"], capture_output=True, check=True
                    )
                    if result.returncode == 0:
                        return candidate
                except (subprocess.CalledProcessError, FileNotFoundError):
                    continue
        return "python"  # Fallback to standard python command

    # === CONFIGURATION METHODS ===

    def should_use_venv(self) -> bool:
        """Determine if virtual environment should be used."""
        # Avoid venv in containers and CI to prevent path issues
        return self.context == ExecutionContext.NATIVE

    def get_pip_command(self) -> Optional[str]:
        """Get appropriate pip command based on environment."""
        if not self.should_use_venv():
            # Use system pip in containers/CI
            return "pip3" if self.python_executable == "python3" else "pip"

        # Use venv pip on native systems
        pip_name = "pip.exe" if self.platform == Platform.WINDOWS else "pip"
        pip_path = self.venv_scripts_dir / pip_name
        return str(pip_path) if pip_path.exists() else None

    def get_pip_install_args(self) -> List[str]:
        """Get pip install arguments based on environment."""
        if not self.should_use_venv():
            # Use --user install in containers/CI to avoid permission issues
            return ["--user"]
        return []

    # === PATH PROPERTIES ===

    @property
    def venv_path(self) -> Path:
        """Get the virtual environment path."""
        return self._venv_path

    @property
    def venv_scripts_dir(self) -> Path:
        """Get the venv scripts/bin directory."""
        if self.platform == Platform.WINDOWS:
            return self._venv_path / "Scripts"
        else:
            return self._venv_path / "bin"

    @property
    def root_dir(self) -> Path:
        """Get the project root directory."""
        return self._root_dir

    # === BACKWARD COMPATIBILITY PROPERTIES ===

    @property
    def is_windows(self) -> bool:
        """Check if running on Windows (backward compatibility)."""
        return self.platform == Platform.WINDOWS

    @property
    def is_container(self) -> bool:
        """Check if running in container (backward compatibility)."""
        return self.context in (ExecutionContext.CONTAINER, ExecutionContext.CI)

    # === DEBUG/INFO METHODS ===

    def get_environment_info(self) -> str:
        """Get a human-readable description of the current environment."""
        platform_name = self.platform.name.title()
        context_name = self.context.name.title()
        return f"{platform_name} platform in {context_name} context"


# Global environment instance
environment = ExecutionEnvironment()
