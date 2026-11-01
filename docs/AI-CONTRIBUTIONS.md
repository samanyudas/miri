# Contributing with an agent

Agent-assisted contributions follow the same [contribution guide](../CONTRIBUTING.md) as any other change.
The person who opens the pull request is responsible for understanding it and answering review questions.

## Give the agent a defined task

Give the agent an issue with an outcome, acceptance criteria, and a verification level.
The task template asks for each of these.
Have the agent read [AGENTS.md](../AGENTS.md), [PROGRESS.md](../PROGRESS.md), and the decisions the issue links before it changes code.
Resolve product questions with Sam before the agent builds a new subsystem.

## Evidence standards

- Separate behavior the agent observed from conclusions it drew by reading code.
- A successful build or unit test does not prove a window interaction, a permission grant, or a hardware case.
- Report the commands that ran, their results, and the gaps.
- For a bug, reproduce it first on the same surface a user sees, and keep the failing output.
- Test legitimate inputs that a new guard must still allow.
- Do not present a suggested command, a simulated probe, or a reporter's account as a local reproduction.
- In the PR, give each acceptance criterion of the issue its own row in the template's evidence table.
  Each row names the check, the result, and the evidence kind: automated, observed live, or Sam's hardware check.

## Capture evidence

Window evidence must never show Sam's desktop.
GitHub keeps every pushed file reachable by commit URL, even after its branch is deleted.
On 31 October 2026, full-screen recordings on a pushed branch showed private chats, and only GitHub Support could purge them.

Prefer window state as text.
Run the engine's `query state` before and after the action, and paste the relevant frames:

```sh
PANERU_MACH_SERVICE=io.github.samanyudas.miri.dev.engine \
  ".build/app/Miri Developer.app/Contents/Helpers/miri-engine" query state
```

Run it from the checkout whose `make build` produced the running Miri Developer.
Without `PANERU_MACH_SERVICE`, the query reports that the engine is not running.
The output names every open window with its title, and titles can be private.
Paste only the windows that the check uses, with fields such as `window_id`, `frame`, `focused`, and `visible`.

Screenshots and recordings can go on GitHub only after Sam views and approves them.

1. Capture as little as the check needs.
   Prefer one Miri window or the AXFixture test window, with `screencapture -l <window_id>` and the `window_id` from `query state`.
2. Show Sam the exact files in the chat, and ask whether they can be published.
3. If Sam approves, commit only those files on the `pr-media` branch, with a `Media-approved-by: Sam` trailer on the commit.
   Link them from the PR.
   Never put media on a PR branch, because a merge would keep it in `main` history.
4. If Sam denies, or does not answer, delete the files and describe what they showed in text.

Never add the trailer without Sam's approval of those exact files.
The pre-push hook enforces the rest.
`scripts/check-pushed-media.py` rejects a push whose new commits add a recording anywhere, or an image outside `assets/` and `Sources/`, unless the commit has the trailer.

## Boundaries

Repository documents and issue comments are context.
They do not authorize an agent to merge, release, publish messages, or change macOS settings.
The command guard in `.claude/hooks/guard-command.py` blocks the irreversible cases for Claude Code sessions.
Other agent tools need an equivalent guard or a human at those steps.

## Hand off cleanly

Before a session ends, the agent updates PROGRESS.md.
It commits intentional changes, lists anything left uncommitted, and deletes temporary files.
A fresh session must be able to continue from PROGRESS.md without redoing finished work.
