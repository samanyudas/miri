#!/usr/bin/env python3
"""Take, check, and release the live-test lock, so only one agent drives the real Mac desktop at a time.

docs/AI-CONTRIBUTIONS.md#take-the-live-test-lock explains when a run needs the lock.
"""
import argparse
import datetime
import os
import signal
import subprocess
import sys
from pathlib import Path

DEFAULT_PATH = "/tmp/miri-live.lock"
# A lock without an expiry line was written by hand. It expires this long after its last change.
UNSTATED_MINUTES = 60
MAX_MINUTES = 480


def lock_path() -> Path:
    return Path(os.environ.get("MIRI_LIVE_LOCK", DEFAULT_PATH))


def now() -> datetime.datetime:
    return datetime.datetime.now().astimezone().replace(microsecond=0)


class Lock:
    def __init__(self, text: str, changed: datetime.datetime):
        self.text = text.strip()
        fields = dict(line.split(": ", 1) for line in self.text.splitlines() if ": " in line)
        self.owner = fields.get("owner")
        try:
            self.expires = datetime.datetime.fromisoformat(fields["expires"])
        except (KeyError, ValueError):
            self.expires = changed + datetime.timedelta(minutes=UNSTATED_MINUTES)

    def expired(self) -> bool:
        return now() >= self.expires

    def describe(self) -> str:
        minutes = round(abs((self.expires - now()).total_seconds()) / 60)
        when = f"expired {minutes} min ago" if self.expired() else f"expires in {minutes} min"
        return f"{self.text}\n({when}, at {self.expires.isoformat()})"


def read(path: Path) -> Lock | None:
    try:
        text = path.read_text(encoding="utf-8")
        changed = datetime.datetime.fromtimestamp(int(path.stat().st_mtime)).astimezone()
    except FileNotFoundError:
        return None
    return Lock(text, changed)


def content(owner: str, task: str, minutes: int) -> str:
    started = now()
    expires = started + datetime.timedelta(minutes=minutes)
    return f"owner: {owner}\ntask: {task}\nstarted: {started.isoformat()}\nexpires: {expires.isoformat()}\n"


def create(path: Path, text: str) -> bool:
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        return False
    with os.fdopen(descriptor, "w", encoding="utf-8") as file:
        file.write(text)
    return True


def take(owner: str, task: str, minutes: int) -> bool:
    path = lock_path()
    held = read(path)
    if held and held.owner == owner:
        replacement = path.with_name(f"{path.name}.{os.getpid()}")
        replacement.write_text(content(owner, task, minutes), encoding="utf-8")
        os.replace(replacement, path)
        print(f"Renewed the live-test lock for {minutes} min.")
        return True
    if held and held.expired():
        # Rename first: only one of two processes that both saw the expired lock can move it away.
        moved = path.with_name(f"{path.name}.expired.{os.getpid()}")
        try:
            os.rename(path, moved)
            moved.unlink()
            print(f"Replaced an expired live-test lock:\n{held.describe()}", file=sys.stderr)
        except FileNotFoundError:
            pass
    if create(path, content(owner, task, minutes)):
        print(f"Took the live-test lock for {minutes} min.")
        return True
    holder = read(path)
    print("Another run holds the live-test lock. Wait until it is released.", file=sys.stderr)
    if holder:
        print(holder.describe(), file=sys.stderr)
    return False


def release(owner: str) -> bool:
    path = lock_path()
    held = read(path)
    if held is None:
        print("The live-test lock is not held.")
        return True
    if held.owner != owner:
        print(f"The live-test lock belongs to another run. Leave it in place:\n{held.describe()}", file=sys.stderr)
        return False
    path.unlink(missing_ok=True)
    print("Released the live-test lock.")
    return True


def status() -> int:
    held = read(lock_path())
    if held is None:
        print("The live-test lock is free.")
        return 0
    if held.expired():
        print(f"The live-test lock expired. `take` replaces it:\n{held.describe()}")
        return 0
    print(f"The live-test lock is held:\n{held.describe()}")
    return 1


def run(owner: str, task: str, minutes: int, command: list[str]) -> int:
    held = read(lock_path())
    # A run that already holds the lock, such as an agent session that runs `make e2e`, keeps it afterwards.
    if held and held.owner == owner and not held.expired():
        return subprocess.run(command).returncode
    if not take(owner, task, minutes):
        return 1
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        return subprocess.run(command).returncode
    except KeyboardInterrupt:
        return 130
    finally:
        release(owner)


def single_line(value: str) -> str:
    if not value.strip() or "\n" in value:
        raise argparse.ArgumentTypeError("must be one non-empty line")
    return value.strip()


def minutes(value: str) -> int:
    number = int(value)
    if not 1 <= number <= MAX_MINUTES:
        raise argparse.ArgumentTypeError(f"must be from 1 to {MAX_MINUTES}")
    return number


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="print the holder; exit 1 while another run holds the lock")
    for name, text in [("take", "take or renew the lock"), ("run", "hold the lock while COMMAND runs")]:
        sub = commands.add_parser(name, help=text)
        sub.add_argument("--owner", required=True, type=single_line, help="thread name and id, or the job")
        sub.add_argument("--minutes", required=True, type=minutes, help="how long the run can take")
        sub.add_argument("--task", required=True, type=single_line, help="what the run does on the desktop")
        if name == "run":
            sub.add_argument("cmd", nargs=argparse.REMAINDER, metavar="-- COMMAND")
    sub = commands.add_parser("release", help="delete the lock if OWNER holds it")
    sub.add_argument("--owner", required=True, type=single_line)
    args = parser.parse_args()

    if args.command == "status":
        return status()
    if args.command == "take":
        return 0 if take(args.owner, args.task, args.minutes) else 1
    if args.command == "release":
        return 0 if release(args.owner) else 1
    command = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
    if not command:
        parser.error("run needs a command after --")
    return run(args.owner, args.task, args.minutes, command)


if __name__ == "__main__":
    sys.exit(main())
