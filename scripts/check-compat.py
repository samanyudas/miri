#!/usr/bin/env python3
"""Check that declared platform, toolchain, and engine versions agree with each other."""
import re
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor/paneru"
ENGINE_BASE = "b1b6abbd3f1a4be138152b6f0389c9ff1b27a269"
ENGINE_BRANCH = "miri/v0.5.2"
SUPPORTED_MACOS = "27.0"


def version(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(ENGINE), *args], capture_output=True, text=True)


def main() -> int:
    problems = []
    package = (ROOT / "Package.swift").read_text()
    build = (ROOT / "scripts/build-prototype.sh").read_text()
    package_macos = re.search(r'\.macOS\("([\d.]+)"\)', package).group(1)
    plist_macos = re.search(r"<key>LSMinimumSystemVersion</key><string>([\d.]+)</string>", build).group(1)
    for name, value in [("Package.swift platform", package_macos), ("Info.plist minimum", plist_macos)]:
        if value != SUPPORTED_MACOS:
            problems.append(f"{name} is macOS {value}; release scope supports macOS {SUPPORTED_MACOS} and later")

    pinned_rust = tomllib.loads((ROOT / "rust-toolchain.toml").read_text())["toolchain"]["channel"]
    engine_rust = tomllib.loads((ENGINE / "Cargo.toml").read_text())["package"]["rust-version"]
    if version(pinned_rust) < version(engine_rust):
        problems.append(f"rust-toolchain.toml pins {pinned_rust}, below the engine's rust-version {engine_rust}")

    pin = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--stage", "vendor/paneru"],
                         capture_output=True, text=True, check=True).stdout.split()[1]
    head = git("rev-parse", "HEAD").stdout.strip()
    if head != pin:
        problems.append(f"engine checkout {head or 'missing'} differs from the recorded pin {pin}; "
                        "run git submodule update --init")
    else:
        git("fetch", "--quiet", "origin", f"{ENGINE_BRANCH}:refs/remotes/origin/{ENGINE_BRANCH}")
        if git("merge-base", "--is-ancestor", ENGINE_BASE, pin).returncode != 0:
            problems.append(f"engine pin {pin} does not descend from the v0.5.2 base {ENGINE_BASE}")
        if git("merge-base", "--is-ancestor", pin, f"origin/{ENGINE_BRANCH}").returncode != 0:
            problems.append(f"engine pin {pin} is not published on the fork's {ENGINE_BRANCH} branch")

    for problem in problems:
        print(problem)
    print(f"check-compat: macOS {SUPPORTED_MACOS}+, Rust {pinned_rust}, engine {pin[:7]}, "
          f"{len(problems)} problem(s)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
