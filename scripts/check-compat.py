#!/usr/bin/env python3
"""Check that declared platform, toolchain, and engine versions agree with each other."""
import hashlib
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
RELEASE_APP_ID = "io.github.samanyudas.miri"
DEVELOPER_APP_ID = "io.github.samanyudas.miri.dev"
DEVELOPER_ENGINE_ID = "io.github.samanyudas.miri.dev.engine"
# Sources/MiriCore/EngineCommand.swift mirrors the engine's command parser, so a change to it needs a review there.
MIRRORED_PARSER = {
    "src/types/argv.rs": "7e1f014e866fc486a889025b4eaeafe8bb583680085dcf077cd92931bc057305",
    "src/types/commands.rs": "d1bd0d5d93c6efae6e69077e338c29a5c87a88a8b3136d16ccff3a9f075a63ed",
}


def version(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(ENGINE), *args], capture_output=True, text=True)


def key_name_problems() -> list[str]:
    engine = (ENGINE / "src/config.rs").read_text()
    swift = (ROOT / "Sources/MiriCore/EngineKey.swift").read_text()
    problems = []
    for engine_function, swift_list in [("virtual_keycode", "layoutKeys"), ("literal_keycode", "literalKeys"),
                                        ("parse_modifiers", "modifierNames")]:
        body = re.search(rf"\nfn {engine_function}\(.*?\n}}\n", engine, re.S)
        listed = re.search(rf"static let {swift_list}: [^=]+ = \[(.*?)\n    \]", swift, re.S)
        if not body or not listed:
            problems.append(f"cannot find {engine_function} in the engine or {swift_list} in EngineKey.swift")
            continue
        if engine_function == "parse_modifiers":
            matches = set(re.findall(r'^\s*"(\w+)" => Modifiers::', body.group(0), re.M)) == set(
                re.findall(r'"(\w+)"', listed.group(1)))
        else:
            # Order matters: the engine uses the first table entry whose layout character matches a key name.
            pair = r'\("(\w+)", 0x([0-9a-f]+)\)'
            engine_pairs = [(name, int(code, 16)) for name, code in re.findall(pair, body.group(0))]
            swift_pairs = [(name, int(code, 16)) for name, code in re.findall(pair, listed.group(1))]
            matches = bool(engine_pairs) and engine_pairs == swift_pairs
        if not matches:
            problems.append(f"EngineKey.{swift_list} no longer matches the engine's {engine_function} in src/config.rs")
    return problems


def main() -> int:
    problems = []
    package = (ROOT / "Package.swift").read_text()
    build = (ROOT / "scripts/build-app.sh").read_text()
    package_macos = re.search(r'\.macOS\("([\d.]+)"\)', package).group(1)
    plist_macos = re.search(r"<key>LSMinimumSystemVersion</key><string>([\d.]+)</string>", build).group(1)
    for name, value in [("Package.swift platform", package_macos), ("Info.plist minimum", plist_macos)]:
        if value != SUPPORTED_MACOS:
            problems.append(f"{name} is macOS {value}; release scope supports macOS {SUPPORTED_MACOS} and later")

    # Development builds must never share the release identity, or they share its Accessibility grant.
    if f"<key>CFBundleIdentifier</key><string>{DEVELOPER_APP_ID}</string>" not in build:
        problems.append(f"scripts/build-app.sh must give the app the developer identity {DEVELOPER_APP_ID}")
    if f"--identifier {DEVELOPER_ENGINE_ID}" not in build or "--features miri-developer" not in build:
        problems.append(f"scripts/build-app.sh must build and sign the engine as {DEVELOPER_ENGINE_ID}")
    release_scope = (ROOT / "decisions/release-scope.md").read_text()
    if f"The bundle ID is `{RELEASE_APP_ID}`" not in release_scope:
        problems.append(f"decisions/release-scope.md no longer names the release identity {RELEASE_APP_ID}")
    developer_plist = ENGINE / "assets/Info.developer.plist"
    if not developer_plist.exists() or f"<string>{DEVELOPER_ENGINE_ID}</string>" not in developer_plist.read_text():
        problems.append(f"the engine's assets/Info.developer.plist must embed {DEVELOPER_ENGINE_ID}")

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

    if "let argv = command.split('_')" not in (ENGINE / "src/config.rs").read_text():
        problems.append("the engine no longer splits [bindings] keys on '_' in src/config.rs; "
                        "update Sources/MiriCore/EngineCommand.swift to match")
    for name, digest in MIRRORED_PARSER.items():
        source = ENGINE / name
        if not source.exists() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            problems.append(f"the engine's {name} changed; check that Sources/MiriCore/EngineCommand.swift still "
                            "mirrors it, then update MIRRORED_PARSER in scripts/check-compat.py")

    problems += key_name_problems()

    for problem in problems:
        print(problem)
    print(f"check-compat: macOS {SUPPORTED_MACOS}+, Rust {pinned_rust}, engine {pin[:7]}, "
          f"{len(problems)} problem(s)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
