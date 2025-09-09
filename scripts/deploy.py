#!/usr/bin/env python3
"""
Cross-platform deploy launcher (replaces deploy.sh & deploy.ps1).

Usage:
  python scripts/deploy.py apply <environment> [--auto-approve] \\
      [--extra-args ...]
  python scripts/deploy.py plan  <environment> [--extra-args ...]
  python scripts/deploy.py destroy <environment> [--auto-approve]

Notes:
- This script expects `terraform` and `aws` CLI to be on PATH.
- It intentionally does NOT pass -auto-approve to `terraform apply` unless you
  explicitly request --auto-approve. Terraform will then prompt with:
      Only 'yes' will be accepted to approve.
  and require typing exactly `yes`.
- For destroy, if --auto-approve is not given, the script will prompt you and
  require exact lowercase `yes` to proceed.
"""

from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys
from typing import List


# ---- Colors (simple)
def color(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m"


def red(s: str) -> str:
    return color(f"[ERROR] {s}", "31")


def green(s: str) -> str:
    return color(f"[SUCCESS] {s}", "32")


def yellow(s: str) -> str:
    return color(f"[WARNING] {s}", "33")


def blue(s: str) -> str:
    return color(f"[INFO] {s}", "34")


def cyan(s: str) -> str:
    return color(f"[STEP] {s}", "36")


# ---- Helpers
def run_check(
    cmd: List[str],
    capture: bool = False,
    text: bool = True,
    check: bool = True,
):
    """Run a command. If capture=True, return CompletedProcess,
    else return returncode."""
    if capture:
        return subprocess.run(cmd, capture_output=True, text=text, check=check)
    else:
        return subprocess.call(cmd)


def die(msg: str, code: int = 1):
    print(red(msg), file=sys.stderr)
    sys.exit(code)


# ---- Validations
def ensure_on_path(name: str):
    if shutil.which(name) is None:
        die(f"{name} not found in PATH. Please install {name} and add it to PATH.")


def check_aws_identity():
    try:
        cp = run_check(["aws", "sts", "get-caller-identity"], capture=True)
        out = cp.stdout
        j = json.loads(out)
        account = j.get("Account", "<unknown>")
        arn = j.get("Arn", "<unknown>")
        print(green(f"AWS credentials configured (Account: {account}, Arn: {arn})"))
    except subprocess.CalledProcessError:
        die("AWS CLI call failed. Ensure AWS credentials are configured (aws configure) and valid.")
    except Exception as e:
        die(f"Failed to parse AWS identity: {e}")


def terraform_version():
    try:
        cp = run_check(["terraform", "version", "-json"], capture=True)
        j = json.loads(cp.stdout)
        v = j.get("terraform_version", "<unknown>")
        print(green(f"Terraform is installed (version: {v})"))
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        # Fallback to text version
        try:
            cp = run_check(["terraform", "version"], capture=True)
            first = cp.stdout.splitlines()[0] if cp.stdout else "<unknown>"
            print(green(f"Terraform: {first}"))
        except Exception:
            die("Terraform is not available or returned unexpected output.")


# ---- Main actions
def terraform_init(root_dir: str):
    print(cyan("Initializing Terraform..."))
    rc = run_check(["terraform", "init", "-input=false"], capture=False)
    if rc != 0:
        die("terraform init failed", rc)
    print(green("Terraform initialized successfully"))


def terraform_plan(root_dir: str, tfvars: str, extra_args: List[str]):
    print(cyan("Creating Terraform plan..."))
    cmd = [
        "terraform",
        "plan",
        "-var-file",
        tfvars,
        "-input=false",
    ] + extra_args
    rc = run_check(cmd)
    if rc != 0:
        die("terraform plan failed", rc)
    print(green("Terraform plan completed successfully"))


def terraform_apply(root_dir: str, tfvars: str, auto: bool, extra_args: List[str]):
    print(cyan("Applying Terraform configuration..."))
    if auto:
        print(yellow("Auto-approve enabled - applying without confirmation"))
        auto_flag = ["--auto-approve"]
    else:
        auto_flag = []
    cmd = ["terraform", "apply", "-var-file", tfvars, "-input=false"] + auto_flag + extra_args
    rc = run_check(cmd)
    if rc != 0:
        die("Terraform apply failed", rc)
    print(green("Terraform apply completed successfully"))
    # show outputs (parsed)
    try:
        cp = run_check(["terraform", "output", "-json"], capture=True)
        j = json.loads(cp.stdout) if cp.stdout.strip() else {}
        print(cyan("Displaying outputs..."))
        print(json.dumps(j, indent=2))
    except Exception as e:
        print(yellow(f"Could not parse terraform outputs: {e}"))


def terraform_destroy(root_dir: str, tfvars: str, auto: bool, extra_args: List[str]):
    print(yellow("This will destroy ALL infrastructure in the environment!"))
    if not auto:
        resp = input(
            "Are you sure you want to destroy the infrastructure? Type 'yes' to continue: "
        )
        if resp != "yes":
            print(blue("Destruction cancelled"))
            return
    cmd = (
        ["terraform", "destroy", "-var-file", tfvars, "-input=false"]
        + (["--auto-approve"] if auto else [])
        + extra_args
    )
    rc = run_check(cmd)
    if rc != 0:
        die("Terraform destroy failed", rc)
    print(green("Terraform destroy completed successfully"))


# ---- Entrypoint
def main(argv: List[str]):
    p = argparse.ArgumentParser(description="Cross-platform Terraform deploy launcher")
    p.add_argument("action", choices=["plan", "apply", "destroy"])
    p.add_argument("environment")
    p.add_argument(
        "--auto-approve",
        action="store_true",
        help="Skip terraform's confirmation by passing --auto-approve",
    )
    p.add_argument(
        "--tfvars-file",
        default=None,
        help="Explicit path to terraform.tfvars (optional)",
    )
    p.add_argument(
        "extra",
        nargs=argparse.REMAINDER,
        help="Extra args forwarded to terraform",
    )
    args = p.parse_args(argv[1:])

    action = args.action
    env = args.environment
    auto = args.auto_approve
    extra = args.extra or []

    # Determine paths (environment-named files in environments folder)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)
    tfvars_file = args.tfvars_file or os.path.join(root_dir, "environments", f"{env}.tfvars")

    print(blue("=== Platform Infrastructure Deployment ==="))
    print(blue(f"Environment: {env}"))
    print(blue(f"Root Directory: {root_dir}"))

    # Validations
    print(cyan("Validating prerequisites..."))
    ensure_on_path("aws")
    ensure_on_path("terraform")
    terraform_version()
    check_aws_identity()
    if not os.path.isfile(tfvars_file):
        die(f"Terraform variables file not found: {tfvars_file}")
    print(green("Environment files validated"))

    # Initialize Terraform
    os.chdir(root_dir)
    terraform_init(root_dir)

    # Dispatch action
    if action == "plan":
        terraform_plan(root_dir, tfvars_file, extra)
    elif action == "apply":
        terraform_apply(root_dir, tfvars_file, auto, extra)
    elif action == "destroy":
        terraform_destroy(root_dir, tfvars_file, auto, extra)

    # Post info
    if action == "apply":
        print(green("=== DEPLOYMENT COMPLETE ==="))
        print(blue("Next steps:"))
        print(blue("1. Check AWS Console to verify resources"))
        print(blue("2. Use terraform outputs above"))
        print()
        print(blue(f"To destroy resources later: python scripts/deploy.py destroy {env}"))

    print(green("Script completed successfully!"))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
