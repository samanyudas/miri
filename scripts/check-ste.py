#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from lib import ste_lint


def main():
    parser = argparse.ArgumentParser(description="Review maintained Markdown for ASD-STE100-inspired structural findings.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="Absolute path to the repository to check.")
    parser.add_argument("--advisory", action="store_true", help="Exit successfully for findings, but fail on tool errors.")
    parser.add_argument("--output", type=Path, help="Save the JSON report.")
    parser.add_argument("--json", action="store_true", help="Print a structured report.")
    args = parser.parse_args()
    if not args.root.is_absolute():
        parser.error("--root must be an absolute path")
    report = {"files": [], "findings": [], "errors": []}
    try:
        root = args.root.resolve()
        inventory = subprocess.run(
            ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            check=True, capture_output=True,
        ).stdout
        for name in sorted(set(os.fsdecode(inventory).rstrip("\0").split("\0"))):
            path = Path(name)
            if not name or path.suffix != ".md" or path.parts[0] == "harness":
                continue
            if not (len(path.parts) == 1 or path.parts[0] in ("docs", "decisions")
                    or path.parts[:2] == (".claude", "agents")
                    or path.name in ("ARCHITECTURE.md", "CONSTRAINTS.md")):
                continue
            source = root / path
            try:
                source.lstat()
            except FileNotFoundError:
                continue
            except OSError as error:
                report["errors"].append(f"{name}: {error}")
                continue
            try:
                source.resolve().relative_to(root)
                findings, _ = ste_lint.lint(source.read_text(encoding="utf-8"), filename=name)
                report["files"].append(name)
                report["findings"].extend(findings)
            except (OSError, UnicodeError, ValueError, RuntimeError) as error:
                report["errors"].append(f"{name}: {error}")
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        detail = error.stderr.decode("utf-8", errors="replace").strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        report["errors"].append(f"File discovery failed. Check the repository path and Git installation: {detail}")

    if args.output:
        try:
            args.output.write_text(json.dumps(report, indent=2) + "\n")
        except OSError as error:
            report["errors"].append(str(error))
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print("ASD-STE100-inspired review. Findings need human review and do not certify full compliance.")
        for finding in report["findings"]:
            print(f"{finding['file']}:{finding['line']}:{finding['col']} {finding['rule']}: {finding['message']}")
        for error in report["errors"]:
            print(f"ERROR: {error}")
        print(f"Checked {len(report['files'])} files. {len(report['findings'])} findings. {len(report['errors'])} errors.")
    return 2 if report["errors"] else 1 if report["findings"] and not args.advisory else 0


if __name__ == "__main__":
    sys.exit(main())
