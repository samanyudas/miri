---
status: accepted
---

# Run the engine as a helper process

The Paneru-based engine runs as a separate helper process inside `Miri.app` instead of a Rust library linked into the app.
Miri controls it through Paneru's existing command-line and JSON interfaces.
An engine crash therefore leaves the settings window and menu bar running, which makes automatic restart and failure reporting possible.
This also keeps Miri's engine patches small.
The cost is an interprocess protocol without command acknowledgement, so Miri must reconcile state after reconnecting.
Whether macOS attributes Accessibility permission to `Miri.app` or to the helper process must be verified with a prototype before other implementation work starts.
