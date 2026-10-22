# Acceptance ledger

This ledger is the single record of v1 acceptance results.
The [app checklist](../decisions/v1-app-acceptance-checklist.md) and the [multi-monitor checklist](../decisions/v1-acceptance-checklist.md) own what each check means.
This file owns only the recorded result for each check.

## Rules

- Record each result against one frozen release candidate.
  The candidate has a fixed app revision and engine pin.
- Fill every column: app revision, engine pin, macOS version, hardware, result, and evidence.
- Use **Pass**, **Fail**, or **Pending** as the result.
  A skipped, unavailable, or unverified check stays **Pending**.
- Name the kind of evidence: automated observation, manual permission grant, or hardware check.
  Never report one kind as another.
- Link the evidence, such as a CI run, a PR, or a file under `.audit/`.
- A multi-monitor failure fails the blocker.
  After a fix, clear the multi-monitor results and run the full checklist again, as its pass rules require.
- A synthetic key event or a gesture detector test is not trackpad evidence.

## Release candidate

No release candidate is frozen yet.
Every check below is **Pending**.

| Field | Value |
| --- | --- |
| App revision | Not frozen |
| Engine pin | Not frozen |
| Signing | Developer ID signed and notarized, required for public-release checks |
| Full runs passed | 0 of 3 |

## Historical evidence

[PROGRESS.md](../PROGRESS.md) records earlier results for earlier builds.
They include granted app and recovery checks, native gap checks, and physical horizontal and vertical display shortcut checks.
These results are useful evidence, but they do not pass any check below.
Each check needs a result on the release candidate.

The CI run [39222055411](https://github.com/samanyudas/miri/actions/runs/39222055411) on `main` at `e516edd` passed.
Its permission selftest reported `observed-ungranted. Attribution unresolved.`
Its recovery selftest reported `skipped-ungranted`, because Miri Developer lacked the Accessibility grant.
A green selftest step therefore does not prove granted window recovery.

The drag integration branch pins engine merge `ffff464` from [samanyudas/paneru#29](https://github.com/samanyudas/paneru/pull/29).
Its tree matches reviewed head `ee94515`, which passed thirteen standalone native fixture lanes on two physical displays.
Those fixture results do not pass S-6 on a frozen release candidate.
A native AppKit fixture at the earlier `c6ae07a` pin measured fill restoration from width 512 to 2048 and back to 512, with all eight unrelated window frames unchanged.
Its automated mock tests and this fill check do not establish native dragging, edge holds, or cross-display behavior.
S-6 remains pending on a frozen candidate.

## Scope accepted after the checklists

[Release scope](../decisions/release-scope.md) added these behaviors on 19 October 2026.
The checklists do not list them yet, so this ledger tracks them here.

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S-1 | Trackpad scrolling moves the strip under the pointer by default, and the setting switches to the focused strip. Each display moves independently. | | | | | Pending | |
| S-2 | Focus reveals only the hidden part of a column. Check partly hidden, fully visible, resized, and destination-display columns. | | | | | Pending | |
| S-3 | After a swipe or modifier scroll, the strip settles on a column, respects the ends, restores stack focus, and resists in a strip that fits. | | | | | Pending | |
| S-4 | Stack heights stay equal after membership changes, and windows with minimum heights never overlap. | | | | | Pending | |
| S-5 | An overflowing stack overlaps each window only below the top bar above it, and the focused window comes to the front and returns on focus change ([#42](https://github.com/samanyudas/miri/issues/42)). | | | | | Pending | |
| S-6 | Dragging a tiled window inserts it into a column at the top, middle, or bottom, or opens a new column, on the same and another display, with insertion lines, refusal, and edge auto-scroll ([#43](https://github.com/samanyudas/miri/issues/43)). | | | | | Pending | |
| S-7 | The stack limit defaults to 5, never exceeds what fits, a Stack command past it starts a new column, and lowering it leaves existing stacks unchanged ([#44](https://github.com/samanyudas/miri/issues/44)). | | | | | Pending | |

## App acceptance

Source: [App acceptance](../decisions/v1-app-acceptance-checklist.md).

### Permission and setup behavior

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AP-1 | Launch Miri without Accessibility permission. | | | | | Pending | |
| AP-2 | Grant permission to the identity established by the prototype. | | | | | Pending | |
| AP-3 | Test the documented recovery procedure after replacing or moving the installed bundle. | | | | | Pending | |
| AP-4 | Run a competing window manager, including standalone Paneru. | | | | | Pending | |
| AP-5 | Turn off **Displays have separate Spaces**. | | | | | Pending | |
| AP-6 | Exercise the setup checker for Stage Manager and supported macOS gesture conflicts. | | | | | Pending | |
| AP-7 | Exercise a non-gesture setup check whose setting cannot be inspected. | | | | | Pending | |

### App lifecycle and recovery

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AL-1 | Close and reopen Settings through the menu bar or Dock entry. | | | | | Pending | |
| AL-2 | Select Stop and relaunch Miri. | | | | | Pending | |
| AL-3 | Start management and select Quit Miri. | | | | | Pending | |
| AL-4 | Check the launch-at-login setting on a new installation. | | | | | Pending | |
| AL-5 | Crash the engine once while Settings remains open. | | | | | Pending | |
| AL-6 | Cause three engine crashes within five minutes. | | | | | Pending | |
| AL-7 | Perform a successful manual restart. | | | | | Pending | |

### Window accessibility after management ends

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AW-1 | Prepare managed windows beyond both visible ends of a scrolling strip. | | | | | Pending | |
| AW-2 | Select Stop and verify access to every previously managed window while management remains stopped. | | | | | Pending | |
| AW-3 | Prepare off-screen managed windows again and select Quit Miri. | | | | | Pending | |
| AW-4 | Prepare off-screen managed windows again and cause an unrecoverable engine failure. | | | | | Pending | |
| AW-5 | Repeat the failure check when the engine cannot execute its clean-shutdown handler. | | | | | Pending | |
| AW-6 | Repeat these checks across the native Spaces and display arrangements in the multi-monitor checklist. | | | | | Pending | |

### Configuration behavior

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AC-1 | Change gaps and width presets through Settings. | | | | | Pending | |
| AC-2 | Relaunch Miri. | | | | | Pending | |
| AC-3 | Edit `~/Library/Application Support/Miri/config.toml` externally with valid settings. | | | | | Pending | |
| AC-4 | Introduce invalid TOML. | | | | | Pending | |
| AC-5 | Make the configuration file unwritable and attempt a setting change. | | | | | Pending | |
| AC-6 | Check standalone Paneru configuration before and after these operations. | | | | | Pending | |
| AC-7 | Check a new installation's layout defaults. | | | | | Pending | |
| AC-8 | Upgrade an installation whose configuration needs migration. | | | | | Pending | |
| AC-9 | Exercise a migration that cannot preserve user values. | | | | | Pending | |

### Shortcuts and layout behavior

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AS-1 | Record several shortcuts for one action. | | | | | Pending | |
| AS-2 | Test supported non-US keyboard layouts, including AZERTY, QWERTZ, and Dvorak. | | | | | Pending | |
| AS-3 | Upgrade an installation with custom bindings. | | | | | Pending | |
| AS-4 | Exercise the v1 bindings in [Keybinding reference](../decisions/keybinding%20reference.md). | | | | | Pending | |
| AS-5 | Open a new resizable window. | | | | | Pending | |
| AS-6 | Adjust column width and window height. | | | | | Pending | |
| AS-7 | Open fixed-size windows and Miri's settings. | | | | | Pending | |
| AS-8 | Focus different columns in a strip that fits, then in a strip that overflows. | | | | | Pending | |
| AS-9 | Check the layout with a visible Dock. | | | | | Pending | |
| AS-10 | Enable macOS Reduce Motion with Miri's disable-animation setting off. | | | | | Pending | |
| AS-11 | Turn off Reduce Motion and enable Miri's disable-animation setting. | | | | | Pending | |
| AS-12 | Check v1 controls and bindings for deferred work. | | | | | Pending | |
| AS-13 | Record a shortcut already assigned to a different Miri action. | | | | | Pending | |
| AS-14 | Record a shortcut with a known macOS conflict. | | | | | Pending | |

### Strip gestures and conflict handling

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AG-1 | Inspect the strip gesture controls. | | | | | Pending | |
| AG-2 | Run initial setup without verified gesture usability. | | | | | Pending | |
| AG-3 | Run initial setup with four-finger usability verified and no macOS conflict. | | | | | Pending | |
| AG-4 | Exercise the supported three-finger and four-finger strip gestures on real hardware. | | | | | Pending | |
| AG-5 | Reverse swipe direction through Settings and relaunch Miri. | | | | | Pending | |
| AG-6 | Select Off. | | | | | Pending | |
| AG-7 | Confirm a known macOS conflict with the selected strip gesture. | | | | | Pending | |
| AG-8 | Make gesture conflict detection unavailable. | | | | | Pending | |
| AG-9 | Complete a real gesture test with consistent strip movement and no unintended macOS actions. | | | | | Pending | |
| AG-10 | Relaunch Miri after selecting and persisting a gesture preference. | | | | | Pending | |
| AG-11 | Fail or leave a gesture test inconclusive. | | | | | Pending | |
| AG-12 | Confirm a known macOS conflict despite a user test or user confirmation. | | | | | Pending | |
| AG-13 | Change the finger count, then separately change the direction. | | | | | Pending | |
| AG-14 | Upgrade macOS, then separately upgrade the bundled engine. | | | | | Pending | |
| AG-15 | Detect a change to relevant macOS gestures, then separately report such a change through Miri. | | | | | Pending | |
| AG-16 | Check keyboard window management while a gesture is Off pending retesting. | | | | | Pending | |

### Updates and diagnostics

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AU-1 | Check the default update policy on a new installation. | | | | | Pending | |
| AU-2 | Enable automatic updates and start Miri with an update available. | | | | | Pending | |
| AU-3 | Open logs and use **Copy diagnostics**. | | | | | Pending | |
| AU-4 | Observe network activity during management, update checks, and update downloads. | | | | | Pending | |
| AU-5 | Exercise diagnostics with known window titles, document paths, usernames, and raw configuration values in the test data. | | | | | Pending | |

### Public-release delivery

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AR-1 | Validate the release disk image on the target Mac. | | | | | Pending | |
| AR-2 | Install the release through its Homebrew cask. | | | | | Pending | |
| AR-3 | Check the distributed source and license notices. | | | | | Pending | |

## Multi-monitor acceptance

Source: [Multi-monitor acceptance](../decisions/v1-acceptance-checklist.md).

### Quick check

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HQ-1 | Scroll each strip in a horizontal and then a vertical arrangement. | | | | | Pending | |
| HQ-2 | Scroll one strip. | | | | | Pending | |
| HQ-3 | Move focus and a window to the other display in both directions. | | | | | Pending | |
| HQ-4 | Unplug and replug the external display 3 times. | | | | | Pending | |
| HQ-5 | Close and open the lid once with an external display connected. | | | | | Pending | |
| HQ-6 | Sleep and wake 3 times. | | | | | Pending | |
| HQ-7 | Force-quit the engine once. | | | | | Pending | |

### Arrangements and scrolling

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HA-1 | Arrange displays horizontally, with the external display on the left and then on the right. | | | | | Pending | |
| HA-2 | Arrange displays vertically, with the external display above and then below. | | | | | Pending | |
| HA-3 | Repeat each arrangement with the laptop as the main display and then with the external display as the main display. | | | | | Pending | |
| HA-4 | Scroll every strip to both ends with the keyboard and the trackpad. | | | | | Pending | |
| HA-5 | Scroll one strip. | | | | | Pending | |
| HA-6 | Repeat scrolling on displays with different resolutions and scaling, including the 32-inch TV. | | | | | Pending | |

### Monitor navigation

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HM-1 | Move focus to the display in each direction where one exists. | | | | | Pending | |
| HM-2 | Move a window to the display in each direction where one exists. | | | | | Pending | |
| HM-3 | Issue a monitor command toward a side with no display. | | | | | Pending | |

### Display changes

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HD-1 | Unplug and replug the external display 50 times. | | | | | Pending | |
| HD-2 | Close and open the lid 20 times with two external displays connected. | | | | | Pending | |
| HD-3 | Sleep and wake 50 times, including at least one overnight sleep. | | | | | Pending | |
| HD-4 | Rearrange displays in **System Settings > Displays** while Miri runs. | | | | | Pending | |
| HD-5 | Change the main display while Miri runs. | | | | | Pending | |
| HD-6 | Change the resolution and scaling of a connected display. | | | | | Pending | |
| HD-7 | Unplug a display that shows a native fullscreen window. | | | | | Pending | |

### Engine recovery

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HR-1 | Force-quit the engine 10 times during a multi-monitor session. | | | | | Pending | |
| HR-2 | Force-quit the engine 3 times within 5 minutes. | | | | | Pending | |

### Endurance

| ID | Check | App revision | Engine pin | macOS | Hardware | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HE-1 | Run an 8-hour working session with two displays and no restarts. | | | | | Pending | |
| HE-2 | Complete the 2-week daily-use period from the release scope. | | | | | Pending | |
