#!/usr/bin/env python3
"""Model-check the engine lifecycle model in verification/engine-lifecycle with TLC.

The steps and the meaning of each result are in .claude/skills/verify-engine-lifecycle/SKILL.md.
Exit status: 0 when every rule gives its expected result, 1 when a result differs, 2 when the
tools or a run fail, 3 when the results are as expected but covered code changed after the sync commit.
"""
import argparse
import concurrent.futures
import hashlib
import os
import platform
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "verification" / "engine-lifecycle"
SPEC = MODEL / "EngineLifecycle.tla"
SKILL = ROOT / ".claude" / "skills" / "verify-engine-lifecycle" / "SKILL.md"

INVARIANTS = ["StopStands", "SavedStopMatches", "QuitLeavesNoEngine", "OneEngine", "StoppedMeansNoEngine", "WaitingIsShown"]
PROPERTIES = ["QuitFinishes"]
# Rules that the current code breaks. Each one is a reported finding, not a modeling error.
KNOWN_FINDINGS = {"WaitingIsShown"}
# Each mutant changes one step of the model the way a plausible code change would, and must break its rule.
MUTANTS = {
    "restart_without_waiting": "OneEngine",
    "stop_reports_stopped_early": "StoppedMeansNoEngine",
    "no_kill_timer": "QuitFinishes",
}

TLA2TOOLS = (
    "https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar",
    "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88",
)
TEMURIN = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/"
JRE = {
    ("Darwin", "arm64"): (
        TEMURIN + "OpenJDK21U-jre_aarch64_mac_hotspot_21.0.13_9.tar.gz",
        "225bab0a09491ef06835488cd942f5d2befa9a0410a2484f0c8bbcf7506ec09a",
        "jdk-21.0.13+9-jre/Contents/Home/bin/java",
    ),
    ("Linux", "x86_64"): (
        TEMURIN + "OpenJDK21U-jre_x64_linux_hotspot_21.0.13_9.tar.gz",
        "a535a1df9c6284d9618872984e026ae0352d1f7e9e0605425c0e6114f47351dd",
        "jdk-21.0.13+9-jre/bin/java",
    ),
}
# A full run takes about 2 seconds, so a run past this limit has a model with no bound.
TLC_TIMEOUT = 120
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "miri" / "verification"


def download(url: str, sha256: str, destination: Path) -> None:
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == sha256:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {url}", file=sys.stderr)
    with urllib.request.urlopen(url) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != sha256:
        sys.exit(f"Checksum mismatch for {url}")
    destination.write_bytes(data)


def tools() -> tuple[str, str]:
    """Returns the java binary and tla2tools.jar. JAVA and TLA2TOOLS override the pinned downloads."""
    jar = os.environ.get("TLA2TOOLS")
    if not jar:
        path = CACHE / "tla2tools-1.7.4.jar"
        download(*TLA2TOOLS, path)
        jar = str(path)
    java = os.environ.get("JAVA")
    if not java:
        key = (platform.system(), platform.machine())
        if key not in JRE:
            sys.exit(f"No pinned Java for {key}. Set JAVA to a Java 11 or later binary.")
        url, sha256, binary = JRE[key]
        archive = CACHE / Path(url).name
        java_path = CACHE / binary
        if not java_path.exists():
            download(url, sha256, archive)
            with tarfile.open(archive) as tar:
                tar.extractall(CACHE, filter="tar")
        java = str(java_path)
    return java, jar


def coverage() -> tuple[str, list[str]]:
    """Reads the sync commit and the covered files from the skill."""
    text = SKILL.read_text(encoding="utf-8")
    sync = re.search(r"^sync-commit: ([0-9a-f]{7,40})$", text, re.M)
    files = re.findall(r"^covers: (\S+)", text, re.M)
    if not sync or not files:
        sys.exit(f"{SKILL} has no sync-commit line or no covers lines.")
    return sync.group(1), files


def stale_files(sync: str, files: list[str]) -> list[str]:
    """Covered files that differ between the sync commit and the working tree, untracked ones included."""
    stale = []
    for command in (["git", "diff", "--name-only", sync], ["git", "ls-files", "--others", "--exclude-standard"]):
        result = subprocess.run([*command, "--", *files], cwd=ROOT, capture_output=True, text=True)
        if result.returncode != 0:
            sys.exit(f"{' '.join(command[:2])} for the covered files failed: {result.stderr.strip()}")
        stale += [line for line in result.stdout.splitlines() if line]
    return stale


def run_tlc(java: str, jar: str, rule: str, mutant: str) -> tuple[str, str, str]:
    """Checks one rule. Returns the rule, "holds" or "breaks", and TLC's output."""
    kind = "PROPERTY" if rule in PROPERTIES else "INVARIANT"
    try:
        return _run_tlc(java, jar, rule, mutant, kind)
    except OSError as error:
        return rule, "error", f"Java could not start: {error}"
    except subprocess.TimeoutExpired:
        return rule, "error", (
            f"TLC ran longer than {TLC_TIMEOUT} seconds. The model's state space is probably unbounded. "
            "Check the bounds in EngineLifecycle.tla before anything else."
        )


def _run_tlc(java: str, jar: str, rule: str, mutant: str, kind: str) -> tuple[str, str, str]:
    with tempfile.TemporaryDirectory() as tmp:
        # TLC looks for the config next to the spec, so both go in the scratch folder.
        (Path(tmp) / SPEC.name).write_bytes(SPEC.read_bytes())
        (Path(tmp) / "check.cfg").write_text(f'SPECIFICATION Spec\nCONSTANT Mutant = "{mutant}"\n{kind} {rule}\n')
        result = subprocess.run(
            [java, "-XX:+UseParallelGC", f"-Djava.io.tmpdir={tmp}", "-cp", jar, "tlc2.TLC",
             "-workers", "1", "-metadir", "states", "-config", "check.cfg", SPEC.name],
            cwd=tmp, capture_output=True, text=True, timeout=TLC_TIMEOUT,
        )
    output = result.stdout + result.stderr
    if "Model checking completed. No error has been found." in output:
        return rule, "holds", output
    if re.search(rf"Invariant {rule} is violated|Temporal properties were violated", output):
        return rule, "breaks", output
    return rule, "error", output


STATE = re.compile(r"^State (\d+): <(\w+)|^State \d+: Stuttering|^Back to state \d+")
FIELDS = ["app", "engine", "proc", "alive", "exitQueued", "stoppedByUser", "polling", "completions"]


def trace(output: str) -> list[str]:
    """The counterexample as one line for each step, with the fields a reader needs."""
    lines, step, record = [], None, ""

    def flush() -> None:
        if step is None:
            return
        values = []
        for field in FIELDS:
            found = re.search(rf"\b{field} \|-> (<<[^>]*>>|\{{[^}}]*\}}|\"[^\"]*\"|\w+)", record)
            if found:
                values.append(f"{field}={found.group(1)}")
        lines.append(f"{step}: " + ", ".join(values))

    for line in output.splitlines():
        match = STATE.match(line)
        if match:
            flush()
            record = ""
            if match.group(2):
                step = f"{match.group(1)}. {match.group(2)}"
            elif "Stuttering" in line:
                step = None
                lines.append("   then nothing more happens, forever")
            else:
                step = None
                lines.append(f"   then {line.split(':', 1)[0].lower()}, and the steps from there repeat forever")
            continue
        if step is not None:
            record += " " + line.strip()
    flush()
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--mutants", action="store_true", help="also check that each mutant breaks its rule")
    parser.add_argument("--quiet", action="store_true", help="leave counterexamples out")
    parser.add_argument("--traces", action="store_true", help="also print the path of each mutant")
    args = parser.parse_args()

    java, jar = tools()
    jobs = [(rule, "none") for rule in INVARIANTS + PROPERTIES]
    if args.mutants:
        jobs += [(rule, mutant) for mutant, rule in MUTANTS.items()]
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        results = list(pool.map(lambda job: (job[1], *run_tlc(java, jar, *job)), jobs))

    unexpected = False
    for mutant, rule, verdict, output in results:
        expected = "breaks" if rule in KNOWN_FINDINGS or mutant != "none" else "holds"
        label = rule if mutant == "none" else f"{rule} with mutant {mutant}"
        if verdict == "error":
            print(f"ERROR     {label}: TLC did not finish.\n{output}")
            return 2
        if verdict == expected:
            status = "finding" if mutant == "none" and verdict == "breaks" else "ok"
        else:
            status = "UNEXPECTED"
            unexpected = True
        print(f"{status:<11}{label} {verdict}")
        # A mutant that breaks its rule is expected, so its path prints only with --traces.
        if verdict == "breaks" and (status == "UNEXPECTED" or (status == "finding" and not args.quiet) or args.traces):
            for line in trace(output):
                print(f"          {line}")
    # A run that breaks a rule stops early, so only a rule that holds explores every state.
    for mutant, rule, verdict, output in results:
        found = re.search(r"(\d+) distinct states found", output)
        if mutant == "none" and verdict == "holds" and found:
            print(f"State space: {found.group(1)} distinct states, every one checked for {rule}.")
            break

    sync, files = coverage()
    stale = stale_files(sync, files)
    if unexpected:
        print("A result differs from the expected one. Read the skill's 'Read the result' section.")
        return 1
    if stale:
        print(f"Covered code changed after sync commit {sync}: {', '.join(stale)}")
        print("Compare these changes with the model before you trust the results.")
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
