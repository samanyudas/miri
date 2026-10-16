import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from test_workflow_permissions import WORKFLOWS, jobs

WORKFLOW = (WORKFLOWS / "issue-fix-status.yml").read_text(encoding="utf-8")
REPO = "samanyudas/miri"
BOT = "github-actions[bot]"
PENDING = "fixed (pending release)"
CONFIRM = "please confirm close"

GH = r'''
import json, os, re, subprocess, sys

path = os.environ["FAKE_GH_STATE"]
with open(path) as f:
    state = json.load(f)
args = sys.argv[1:]


def fail(message):
    sys.exit(f"fake gh: {message}: {sys.argv[1:]}")


def take(flag):
    values = []
    while flag in args:
        index = args.index(flag)
        values.append(args[index + 1])
        del args[index:index + 2]
    return values


def emit(value):
    jq = take("--jq")
    # Real gh applies --jq to each page separately, which is what the scripts' jq -s has to undo.
    pages = [value]
    if paginate and isinstance(value, list):
        pages = [value[i:i + 2] for i in range(0, len(value), 2)] or [[]]
    for page in pages:
        text = json.dumps(page)
        if jq:
            text = subprocess.run(["jq", "-r", jq[0]], input=text, capture_output=True, text=True, check=True).stdout
        else:
            text += "\n"
        sys.stdout.write(text)


def issue(number):
    if str(number) not in state["issues"]:
        fail("no such issue")
    return state["issues"][str(number)]


paginate = "--paginate" in args
args = [a for a in args if a not in ("--silent", "--paginate")]

if args[:2] == ["issue", "list"]:
    wanted, label, fields = take("--state")[0], take("--label")[0], take("--json")[0].split(",")
    take("--limit")
    emit([{field: {"number": int(n), "author": {"login": i["author"]}}[field] for field in fields}
          for n, i in sorted(state["issues"].items(), key=lambda item: int(item[0]))
          if i["state"] == wanted and label in i["labels"]])
elif args[:2] == ["issue", "comment"]:
    body = take("--body") or [open(f).read() for f in take("--body-file")]
    issue(args[2])["comments"].append({"created_at": state["now"], "login": "github-actions[bot]", "body": body[0]})
elif args[:2] == ["issue", "edit"]:
    labels = issue(args[2])["labels"]
    for label in take("--add-label"):
        if label not in state["labels"]:
            fail(f"label {label!r} not found")
        labels += [label] if label not in labels else []
    for label in take("--remove-label"):
        labels[:] = [l for l in labels if l != label]
elif args[:2] == ["issue", "close"]:
    issue(args[2]).update(state="closed", state_reason=take("--reason")[0], closed_by="github-actions[bot]")
elif args[:2] == ["issue", "reopen"]:
    issue(args[2]).update(state="open", state_reason=None)
elif args[:2] == ["label", "create"]:
    take("--color")
    take("--description")
    if args[2] in state["labels"]:
        fail("label already exists")
    state["labels"].append(args[2])
elif args[:1] == ["api"]:
    fields = take("-f")
    match = re.fullmatch(r"repos/%s/(issues|pulls)/(\d+)(/labels|/comments)?" % re.escape(os.environ["GH_REPO"]), args[1])
    if not match:
        fail("unsupported api path")
    kind, number, tail = match.groups()
    if kind == "pulls" and not tail:
        emit({"body": state["pulls"][number]["body"]})
    elif tail == "/labels" and fields:
        labels = issue(number)["labels"]
        labels += [f.split("=", 1)[1] for f in fields if f.split("=", 1)[1] not in labels]
        state["labels"] += [l for l in labels if l not in state["labels"]]
    elif tail == "/comments":
        emit([{"created_at": c["created_at"], "user": {"login": c["login"]}, "body": c["body"]}
              for c in issue(number)["comments"]])
    elif kind == "issues" and not tail:
        i = issue(number)
        emit({"number": int(number), "state": i["state"], "title": f"Issue {number}",
              "labels": [{"name": l} for l in i["labels"]],
              "closed_by": {"login": i["closed_by"]} if i.get("closed_by") else None})
    else:
        fail("unsupported api call")
else:
    fail("unsupported command")

with open(path, "w") as f:
    json.dump(state, f)
'''

# BSD date on macOS has no -d, and the close job only asks for "N days ago".
DATE = r'''
import os, re, sys
from datetime import datetime, timedelta, timezone

args = sys.argv[1:]
match = len(args) == 4 and args[:2] == ["-u", "-d"] and re.fullmatch(r"(\d+) days ago", args[2])
if not match:
    os.execv("/bin/date", ["date", *args])
print((datetime.now(timezone.utc) - timedelta(days=int(match.group(1)))).strftime(args[3][1:]))
'''


def days_ago(days: float) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ")


def workflow_env() -> dict[str, str]:
    lines = WORKFLOW.splitlines()
    env = {}
    for line in lines[lines.index("env:") + 1:]:
        match = re.fullmatch(r"  ([A-Z_]+): (.*)", line)
        if not match:
            break
        if "${{" not in match.group(2):
            env[match.group(1)] = match.group(2)
    return env | {"GH_REPO": REPO}


def job_script(job: str) -> str:
    block = jobs(WORKFLOW)[1][job]
    start = block.index("        run: |") + 1
    end = next((i for i in range(start, len(block)) if block[i].strip() and not block[i].startswith(" " * 10)),
               len(block))
    return textwrap.dedent("\n".join(block[start:end]))


def issue(author="reporter", state="open", labels=(), comments=(), closed_by=None):
    return {"state": state, "state_reason": None, "author": author, "labels": list(labels), "comments": list(comments),
            "closed_by": closed_by}


def comment(created_at, login, body):
    return {"created_at": created_at, "login": login, "body": body}


def repo(issues, pulls=None, now=None):
    return {"now": now or days_ago(0), "labels": ["bug", "needs-triage", PENDING],
            "issues": issues, "pulls": pulls or {}}


ASK = "The fix for this is out now. <!-- miri-fix-status confirm=v1.2.0 -->"


class IssueLifecycleTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        bin_dir = self.dir / "bin"
        bin_dir.mkdir()
        stubs = {"gh": GH}
        if subprocess.run(["date", "-u", "-d", "1 days ago"], capture_output=True).returncode != 0:
            stubs["date"] = DATE
        for name, source in stubs.items():
            (bin_dir / name).write_text(f"#!{sys.executable}\n{source}")
            (bin_dir / name).chmod(0o755)
        self.path = f"{bin_dir}{os.pathsep}{os.environ['PATH']}"

    def run_job(self, job, state, **env):
        state_file = self.dir / "state.json"
        state_file.write_text(json.dumps(state))
        result = subprocess.run(["bash", "-c", job_script(job)], cwd=self.dir, capture_output=True, text=True,
                                env={"PATH": self.path, "FAKE_GH_STATE": str(state_file)} | workflow_env() | env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(state_file.read_text())

    def test_a_stable_release_asks_each_waiting_reporter(self):
        untouched = {"11": issue("bob", labels=["bug"]), "12": issue("carol", state="closed", labels=[PENDING])}
        state = repo({"10": issue("alice", labels=["bug", PENDING])} | copy.deepcopy(untouched))

        after = self.run_job("reporter-check", state, TAG="v1.2.0", PRERELEASE="false")

        asked = after["issues"]["10"]
        self.assertEqual(asked["labels"], ["bug", "please confirm close"])
        self.assertEqual([c["login"] for c in asked["comments"]], [BOT])
        body = asked["comments"][0]["body"]
        self.assertIn("in **1.2.0**", body)
        self.assertIn("@alice, could you update", body)
        self.assertTrue(body.rstrip().endswith("<!-- miri-fix-status confirm=v1.2.0 -->"), body)
        self.assertIn("please confirm close", after["labels"])
        self.assertEqual({n: after["issues"][n] for n in untouched}, untouched)

    def test_a_prerelease_or_odd_tag_changes_nothing(self):
        for tag, prerelease in [("v1.3.0", "true"), ("v1.3.0-beta.1", "false"), ("nightly", "false")]:
            with self.subTest(tag=tag, prerelease=prerelease):
                state = repo({"10": issue("alice", labels=[PENDING])})
                self.assertEqual(self.run_job("reporter-check", copy.deepcopy(state), TAG=tag, PRERELEASE=prerelease),
                                 state)

    def test_an_unanswered_question_closes_after_two_weeks(self):
        waiting = {
            "21": issue(labels=[CONFIRM], comments=[comment(days_ago(40), BOT, "Fixed in #2."),
                                                    comment(days_ago(15), BOT, ASK),
                                                    comment(days_ago(10), "reporter", "Still broken on Sonoma.")]),
            "22": issue(labels=[CONFIRM], comments=[comment(days_ago(3), BOT, ASK)]),
            "23": issue(labels=[CONFIRM], comments=[comment(days_ago(30), BOT, "Unrelated note.")]),
        }
        state = repo({"20": issue(labels=["bug", CONFIRM], comments=[comment(days_ago(40), BOT, "Fixed in #2."),
                                                                     comment(days_ago(39), "reporter", "Thanks."),
                                                                     comment(days_ago(15), BOT, ASK),
                                                                     comment(days_ago(14.5), BOT, "Bot echo.")])}
                     | copy.deepcopy(waiting))

        after = self.run_job("close-unanswered", state)

        closed = after["issues"]["20"]
        self.assertEqual((closed["state"], closed["state_reason"], closed["labels"]), ("closed", "completed", ["bug"]))
        self.assertEqual(closed["comments"][-1]["login"], BOT)
        self.assertTrue(closed["comments"][-1]["body"].startswith("Nobody replied in two weeks"))
        self.assertTrue(closed["comments"][-1]["body"].endswith("<!-- miri-fix-status closed -->"))
        self.assertEqual({n: after["issues"][n] for n in waiting}, waiting)

    def test_a_reply_reopens_only_a_silence_close(self):
        reply = comment(days_ago(0), "reporter", "Still happens.")
        silence = [comment(days_ago(20), BOT, ASK),
                   comment(days_ago(5), BOT, "Nobody replied. <!-- miri-fix-status closed -->"), reply]
        human = [comment(days_ago(5), BOT, "Fixed in #3. <!-- miri-fix-status sha=abc pr=3 -->"), reply]
        state = repo({"30": issue(state="closed", labels=["bug"], comments=silence, closed_by=BOT),
                      "31": issue(state="closed", labels=["bug"], comments=human, closed_by="sam")})

        after = self.run_job("reopen-on-reply", copy.deepcopy(state), NUMBER="30")
        self.assertEqual((after["issues"]["30"]["state"], after["issues"]["30"]["labels"]), ("open", ["bug", "needs-triage"]))

        after = self.run_job("reopen-on-reply", copy.deepcopy(state), NUMBER="31")
        self.assertEqual(after, state)

    def test_a_maintainer_close_after_a_reopen_sticks(self):
        state = repo({"32": issue(labels=[CONFIRM], comments=[comment(days_ago(15), BOT, ASK)])})
        state = self.run_job("close-unanswered", state)
        state["issues"]["32"]["comments"].append(comment(days_ago(0), "reporter", "Still happens."))
        state = self.run_job("reopen-on-reply", state, NUMBER="32")
        self.assertEqual(state["issues"]["32"]["state"], "open")
        state["issues"]["32"].update(state="closed", state_reason="not_planned", closed_by="sam")
        state["issues"]["32"]["comments"].append(comment(days_ago(0), "reporter", "Thanks anyway."))

        self.assertEqual(self.run_job("reopen-on-reply", copy.deepcopy(state), NUMBER="32"), state)

    def test_a_merged_reference_labels_the_open_issue(self):
        untouched = {"42": issue(), "43": issue(state="closed")}
        state = repo({"41": issue(labels=["bug"]), "44": issue(labels=[CONFIRM])} | copy.deepcopy(untouched),
                     pulls={"40": {"body": "Refs #41\nalso see #42\nFixes #43\nRefs: #44"}})

        after = self.run_job("fixed-on-main", state, PR_NUMBER="40", MERGE_SHA="abc123")

        for number, labels in [("41", ["bug", PENDING]), ("44", [PENDING])]:
            with self.subTest(issue=number):
                labelled = after["issues"][number]
                self.assertEqual(labelled["labels"], labels)
                self.assertEqual([c["login"] for c in labelled["comments"]], [BOT])
                self.assertIn("added in #40", labelled["comments"][0]["body"])
                self.assertTrue(labelled["comments"][0]["body"].rstrip().endswith(
                    "<!-- miri-fix-status sha=abc123 pr=40 -->"))
        self.assertEqual({n: after["issues"][n] for n in untouched}, untouched)

    def test_a_fix_travels_from_merge_to_release_to_timed_close_and_back(self):
        state = repo({"7": issue("dana", labels=["bug"])}, pulls={"8": {"body": "Refs #7"}}, now=days_ago(20))
        state = self.run_job("fixed-on-main", state, PR_NUMBER="8", MERGE_SHA="f00d")
        state["now"] = days_ago(15)
        state = self.run_job("reporter-check", state, TAG="v2.0.0", PRERELEASE="false")
        state["now"] = days_ago(0)
        state = self.run_job("close-unanswered", state)
        state["issues"]["7"]["comments"].append(comment(days_ago(0), "dana", "Not fixed for me."))
        state = self.run_job("reopen-on-reply", state, NUMBER="7")

        reopened = state["issues"]["7"]
        self.assertEqual((reopened["state"], reopened["labels"]), ("open", ["bug", "needs-triage"]))
        self.assertEqual([re.search(r"miri-fix-status (\w+)", c["body"]).group(1) for c in reopened["comments"][:3]],
                         ["sha", "confirm", "closed"])


if __name__ == "__main__":
    unittest.main()
