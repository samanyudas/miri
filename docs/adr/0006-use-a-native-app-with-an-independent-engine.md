---
status: accepted
---

# Use a native app with an independent engine

Miri uses SwiftUI settings and AppKit where needed, with menu bar controls for operating the engine.
Closing settings leaves window management running because settings visibility and engine operation are separate states.
Stop pauses management, and Quit Miri stops both the app and its engine.
All managed windows must remain accessible after Miri stops, quits, or experiences an unrecoverable engine failure.
Never leave windows stranded off-screen.
Opening Miri starts management after Accessibility permission is granted, unless the user left Miri in the stopped state.
Launch at login is offered and enabled by default.
Miri restarts the engine after an isolated crash, and stops retrying after three crashes within five minutes so the user sees the failure, logs, and a manual restart control.
