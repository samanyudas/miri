# Setup

Status: planned Miri setup behavior, aligned with the accepted [release scope](release-scope.md).
Implementation and test status lives in [PROGRESS.md](../PROGRESS.md), not in this document.
The steps below describe the intended Miri setup experience.

## Check the requirements

V1 provisionally supports Apple silicon Macs running macOS 27 or later.
Older macOS versions require community testing before adoption.
Intel support is deferred unless Sam needs it.

Multi-finger strip gestures require a built-in trackpad or Magic Trackpad.
Users without a trackpad use keyboard commands.

Miri requires Accessibility permission only.
It keeps System Integrity Protection (SIP) enabled and does not capture the screen.
It does not require Screen Recording permission, Input Monitoring permission, kernel extensions, or system modifications.

Public releases use Developer ID signing and Apple notarization.
Development builds use ad-hoc signing on Sam's Mac.

## Install and start Miri

1. Open the Miri disk image.
2. Drag `Miri.app` into Applications.
3. Run Miri from Applications.
4. Follow Miri's Accessibility permission guidance.
5. Confirm that window management starts after permission is granted.

A Homebrew cask is also planned.
Miri starts management on launch unless the user previously stopped it.
Launch at login is offered and enabled by default.

Miri checks for updates daily and asks before installing.
Users can enable automatic installation in Settings.
Keep the installed app location stable when validating Accessibility permission.

## Teach the strip on first run

The guided shortcut tutorial is deferred to v2.
It will explain strip navigation and essential shortcuts using the user's configured bindings.
The exact shortcut set remains unresolved.

V1 provides permission guidance and a setup checker.
Initial setup also recommends a strip gesture and offers a gesture test when conflict detection is unavailable.
This setup guidance does not add the deferred guided shortcut tutorial to v1.
Keep action descriptions available after the settings window closes.

## Grant Accessibility permission

Explain why Miri needs permission to move windows.
Direct users to **System Settings > Privacy & Security > Accessibility**.

Whether macOS attributes permission to `Miri.app` or its engine helper requires a prototype.
Verify that identity before finalizing the permission instructions.
See [ADR 0009](../docs/adr/0009-run-the-engine-as-a-helper-process.md).

1. Enable the verified Miri Accessibility entry.
2. Start window management through Miri's menu bar controls.
3. Confirm that Miri reports the engine as running.

If permission remains unavailable after moving or replacing Miri, re-add the verified Accessibility entry from the installed bundle.
Restart the engine through Miri's menu bar controls.
Validate this recovery procedure with the signed build.

## Reserve a horizontal swipe

macOS gestures can conflict with Miri's strip swipe.
The setup checker reports clashes and links to the relevant System Settings page.
Miri never changes macOS settings itself.

Supported finger counts, defaults, direction, and conflict handling follow [Strip gestures](release-scope.md#strip-gestures).
Validate each supported finger count and macOS gesture combination on real hardware.

### Test and retest a strip gesture

When automatic conflict detection is unavailable, Miri offers a gesture test during setup.
The pass criteria, the **Verified by user test** result, and the conditions that require a retest follow [Strip gestures](release-scope.md#strip-gestures).

### Proposed four-finger setup

1. Open **System Settings > Trackpad > More Gestures**.
2. Turn off **Swipe between full-screen applications**.
3. Set Miri's strip swipe to four fingers.

Miri enables the gesture only under the enablement rule in [Strip gestures](release-scope.md#strip-gestures).

Use Control-Left, Control-Right, or Mission Control to change Spaces.
Keep vertical Mission Control and App Exposé gestures enabled if desired.

### Proposed three-finger setup with desktop swipes

1. Set **Swipe between full-screen applications** to four fingers.
2. Set **Swipe between pages** to two fingers.
3. Turn off **Three Finger Drag** in **Accessibility > Pointer Control > Trackpad Options**.
4. Set Miri's strip swipe to three fingers.

If Three Finger Drag is needed, use the four-finger strip setup instead.
Confirm that strip swipes do not also trigger desktop switching or browser navigation.

## Configure Mission Control and other window managers

Miri refuses to start management while **Displays have separate Spaces** is off.
Enable that setting in **System Settings > Desktop & Dock**, then log out for the change to take effect.
Miri explains this prerequisite before the user starts management.

Miri also refuses to start while another window manager runs, including standalone Paneru.
Quit the tool that Miri identifies before starting management.
Miri leaves the other tool's configuration untouched.

The setup checker reports Stage Manager and macOS gesture conflicts.
Turning off **Automatically rearrange Spaces based on most recent use** remains proposed setup guidance.
Verify the relevant settings paths on each supported macOS version.

## Check competing macOS tiling

macOS tiling controls can conflict with Miri's planned drag-to-reorder behavior in v2.
Verify conflicts before requiring changes to these settings in **System Settings > Desktop & Dock > Windows**:

- **Drag windows to screen edges to tile**.
- **Drag windows to menu bar to fill screen**.
- **Hold Option key while dragging windows to tile**.

## Arrange and select displays

V1 supports horizontal, vertical, and mixed physical monitor arrangements that Sam can verify on real hardware.
Each managed display and native Space has its own strip.
Scrolling one strip must not change another strip's focus or scroll position.

Off-screen windows must remain on their assigned displays without macOS relocating them.
The edge-handling mechanism requires engine and hardware verification.
Reliable horizontal multi-monitor scrolling blocks the v1 release until it passes the [acceptance checklist](v1-acceptance-checklist.md).

Display changes follow macOS Space migration as recorded in [ADR 0008](../docs/adr/0008-follow-macos-space-migration-for-display-changes.md).
Miri keeps no separate display layout state and offers no reconnection settings in v1.
Excluding individual displays from management is deferred to v2.

## Find settings and diagnostics

Reopen Miri's settings through its menu bar controls or Dock entry.
Closing settings keeps the engine running.
Stop, Quit, and window recovery follow [App controls and window recovery](release-scope.md#app-controls-and-window-recovery).

Settings provide gaps, width presets, shortcut editing, permission guidance, and access to logs.
Logs remain local.
A **Copy diagnostics** control prepares information for GitHub issues.
Diagnostics contents and redaction follow [Privacy and diagnostics](release-scope.md#privacy-and-diagnostics).
The exact menu labels and placement remain to be designed.

Advanced users can edit `~/Library/Application Support/Miri/config.toml`.
Miri keeps standalone Paneru's configuration files untouched.

## Setup checks to implement

Report missing Accessibility permission, **Displays have separate Spaces** turned off, Stage Manager turned on, competing window managers, and conflicting macOS gestures.
Explain the relevant System Settings path for each failure.
Update the check status as users resolve each problem.

Keep unsupported OS and hardware checks separate from recoverable settings problems.
Confirm which settings Miri can inspect before promising automatic checks.
Report unavailable checks as described in [Conflicts and setup checker](release-scope.md#conflicts-and-setup-checker) and [Strip gestures](release-scope.md#strip-gestures).

## Troubleshoot setup problems

### Swiping does nothing or moves incorrectly

1. Confirm that Miri reports the engine as running.
2. Check that strip scrolling is enabled.
3. Use the configured number of fingers on a built-in trackpad or Magic Trackpad.
4. Check for a conflicting macOS gesture using [Reserve a horizontal swipe](#reserve-a-horizontal-swipe).
5. Check Miri's update controls for an available update.

### Swiping switches desktops or navigates back a page

If strip swipes also switch desktops, turn off **Swipe between full-screen applications** or assign desktop switching a different finger count.
If three-finger swipes navigate back in a browser, try setting **Swipe between pages** to two fingers.
Verify each recommendation on the supported macOS version.

### No windows move or Accessibility remains unavailable

Follow [Grant Accessibility permission](#grant-accessibility-permission).
Check the setup checker for a competing window manager or **Displays have separate Spaces** being off.
Restart the engine after resolving the reported problem.

### Restored windows have incorrect sizes

Verify that restored windows retain their intended heights with vertically arranged displays, including a display below the main display.
Include the arrangement and observed sizes in a bug report.

### The settings window was closed

Reopen Miri's settings through its menu bar controls or Dock entry.
Window management continues while settings are closed.

### Collect information for an unresolved problem

Use **Copy diagnostics** to prepare a report.
Record the macOS version, Miri version, and observed behavior.
Use the redacted engine log when relevant.
Review the diagnostics preview before copying.
Keep diagnostic collection user initiated and local until the user chooses to share it.
