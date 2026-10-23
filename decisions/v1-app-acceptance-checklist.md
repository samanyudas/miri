# V1 app acceptance checklist

Status: checks derived from Sam's accepted design decisions on 14 October 2026.
A check passes only with a recorded result for the build under test.
Implementation status lives in [PROGRESS.md](../PROGRESS.md), and results live in the [acceptance ledger](../docs/acceptance-ledger.md).
This checklist adds no new product choices and does not alter the [multi-monitor release checklist](v1-acceptance-checklist.md).

## Prerequisites and evidence

Complete the Accessibility attribution prototype required by [ADR 0009](../docs/adr/0009-run-the-engine-as-a-helper-process.md) before other implementation.
Run permission and lifecycle checks on the actual Miri app bundle and helper identities.
Use ad-hoc signing for development checks and the Developer ID signed, notarized bundle for public-release checks.
Record the app build, pinned engine revision, macOS version, display setup, and observed result for each check.
An unavailable or unverified check remains pending rather than passing.

## Permission and setup behavior

1. Launch Miri without Accessibility permission.
   Miri explains why it needs permission and links to the relevant System Settings page.
   Window management starts only after permission is available.
2. Grant permission to the identity established by the prototype.
   Miri reports the actual engine state and starts management unless the user previously selected Stop.
3. Test the documented recovery procedure after replacing or moving the installed bundle.
   The verified Accessibility entry restores management after the engine restarts.
4. Run a competing window manager, including standalone Paneru.
   Miri refuses to start management and names the competing tool.
   The other tool's configuration stays unchanged.
5. Turn off **Displays have separate Spaces**.
   Miri refuses to start management and explains the logout requirement.
6. Exercise the setup checker for Stage Manager, macOS tiling, and supported macOS gesture conflicts.
   The checker reports the condition, links to System Settings, and never changes macOS settings itself.
   Automatic detection remains pending where the engineering investigation has not established a reliable check.
7. Exercise a non-gesture setup check whose setting cannot be inspected.
   The checker shows **Not checked** with manual instructions.
   The unavailable check is never presented as passed.

## App lifecycle and recovery

1. Close and reopen Settings through the menu bar or Dock entry.
   Window management continues while Settings is closed.
2. Select Stop and relaunch Miri.
   Management remains stopped until the user starts it.
3. Start management and select Quit Miri.
   Both the app and helper stop.
4. Check the launch-at-login setting on a new installation.
   The setting is enabled by default and can be changed through Settings.
5. Crash the engine once while Settings remains open.
   The app stays available, restarts the engine, and restores its layout.
6. Cause three engine crashes within five minutes.
   Miri stops automatic retries and presents the failure, logs, and manual restart control.
7. Perform a successful manual restart.
   The crash count resets, and the app reconciles its displayed state with the engine.

## Window accessibility after management ends

All managed windows must remain accessible after Miri stops, quits, or experiences an unrecoverable engine failure.
Never leave windows stranded off-screen.

1. Prepare managed windows beyond both visible ends of a scrolling strip.
2. Select Stop and verify access to every previously managed window while management remains stopped.
   No window is stranded off-screen.
3. Prepare off-screen managed windows again and select Quit Miri.
   Every previously managed window remains accessible after the app and helper stop.
4. Prepare off-screen managed windows again and cause an unrecoverable engine failure.
   Every previously managed window remains accessible without a successful engine restart.
5. Repeat the failure check when the engine cannot execute its clean-shutdown handler.
   Window access does not depend on the failed engine completing cleanup.
6. Repeat these checks across the native Spaces and display arrangements in the multi-monitor checklist.
   Verify that each previously managed window can be focused and interacted with.

## Configuration behavior

1. Change gaps and width presets through Settings.
   Valid changes apply immediately, persist, and require no Save action or engine restart.
2. Relaunch Miri.
   The selected settings remain in effect.
3. Edit `~/Library/Application Support/Miri/config.toml` externally with valid settings.
   The app detects the edit and applies the valid settings.
4. Introduce invalid TOML.
   The engine retains the last valid settings.
   Settings and the menu bar show the error and its line.
   Miri does not overwrite the file it could not read correctly.
5. Make the configuration file unwritable and attempt a setting change.
   Miri reports the write failure and retains the last valid settings.
6. Check standalone Paneru configuration before and after these operations.
   Miri never reads it as a fallback or modifies its files.
7. Check a new installation's layout defaults.
   Width presets are `[0.25, 0.33, 0.5, 0.66, 0.75]`, and both gaps are 8 points.
8. Upgrade an installation whose configuration needs migration.
   Miri creates a backup before migration and preserves user values in the migrated file.
9. Exercise a migration that cannot preserve user values.
   Miri leaves the original file unchanged and reports an error.

## Shortcuts and layout behavior

1. Record several shortcuts for one action.
   Each recorded binding performs the selected action.
2. Test supported non-US keyboard layouts, including AZERTY, QWERTZ, and Dvorak.
   The recorder and configured actions work with the active layout.
3. Upgrade an installation with custom bindings.
   Existing bindings remain unchanged, and new defaults fill only unused keys.
   The explicit reset action selects the current default set.
4. Exercise the v1 bindings in [Keybinding reference](keybinding%20reference.md).
   Numbered jumps select columns and restore the selected stack's last-focused window.
   Dedicated monitor commands follow physical monitor directions.
5. Open a new resizable window.
   Its initial width is 50% of display width, and existing windows retain their widths.
6. Adjust column width and window height.
   Each press changes size by five percentage points of the corresponding display dimension, subject to window size constraints.
7. Open fixed-size windows and Miri's settings.
   Those windows float automatically.
   Clicking and macOS window switching provide access to floating windows.
8. Focus different columns in a strip that fits, then in a strip that overflows.
   The strip moves only as far as needed to show the focused column fully, and a fully visible column does not move.
   After a trackpad swipe, the strip settles on a column and that column takes focus.
   A width change keeps the column around its own center, and cycling back to the starting width returns it to the same place.
9. Check the layout with a visible Dock.
   The layout reserves Dock space without a separate Miri setting.
10. Enable macOS Reduce Motion with Miri's disable-animation setting off.
    Strip movement is instant.
11. Turn off Reduce Motion and enable Miri's disable-animation setting.
    Strip movement remains instant.
12. Check v1 controls and bindings for deferred work.
    Virtual-workspace commands and their indicator remain hidden, and tabbed-column commands are unavailable in v1.
13. Record a shortcut already assigned to a different Miri action.
    Miri rejects the conflicting assignment and leaves the existing binding unchanged.
14. Record a shortcut with a known macOS conflict.
    Miri warns about the conflict and never silently replaces another binding.

## Strip gestures and conflict handling

1. Inspect the strip gesture controls.
   The supported selections are three fingers, four fingers, and Off.
   Five-finger support is unavailable in v1.
2. Run initial setup without verified gesture usability.
   Miri recommends four fingers, but strip gestures default to Off.
   Keyboard window management remains available when its startup prerequisites are satisfied.
3. Run initial setup with four-finger usability verified and no macOS conflict.
   Four-finger strip gestures can be enabled.
4. Exercise the supported three-finger and four-finger strip gestures on real hardware.
   The strip follows finger movement by default.
   The actual supported gesture and macOS setting combinations have recorded hardware evidence.
5. Reverse swipe direction through Settings and relaunch Miri.
   The selected reverse preference persists, but the gesture remains Off pending retesting.
   After a successful retest and explicit user confirmation, the selected reverse direction controls strip movement.
6. Select Off.
   Miri does not intercept the strip gesture, and keyboard window management remains available.
7. Confirm a known macOS conflict with the selected strip gesture.
   Miri disables its conflicting strip gesture, preserves keyboard window management, and shows manual setup instructions.
   Miri never modifies macOS settings automatically.
8. Make gesture conflict detection unavailable.
   Miri shows **Unable to verify** and offers a gesture test.
   Unavailable detection by itself is neither a confirmed conflict nor a passed verification.
9. Complete a real gesture test with consistent strip movement and no unintended macOS actions.
   Without explicit user confirmation, Miri does not mark usability as verified by the user test.
   After explicit user confirmation, Miri shows **Verified by user test**.
   The underlying macOS gesture configuration is not presented as automatically verified.
10. Relaunch Miri after selecting and persisting a gesture preference.
    The preference remains stored, and an option to retest is available.
    Ordinary restarts do not invalidate the user-test result.
11. Fail or leave a gesture test inconclusive.
    The gesture remains Off, and keyboard window management remains available when its startup prerequisites are satisfied.
12. Confirm a known macOS conflict despite a user test or user confirmation.
    The known conflict still prevents the conflicting strip gesture from being enabled.
13. Change the finger count, then separately change the direction.
    Each change invalidates the prior user-test result.
    The selected preference remains saved, but the gesture stays Off until another successful test and explicit user confirmation.
14. Upgrade macOS, then separately upgrade the bundled engine.
    Each upgrade invalidates the prior user-test result and requires retesting before gesture enablement.
15. Detect a change to relevant macOS gestures, then separately report such a change through Miri.
    Each case invalidates the prior user-test result and requires retesting.
    Miri does not claim to detect changes when automatic detection is unavailable.
16. Check keyboard window management while a gesture is Off pending retesting.
    Keyboard window management continues when its startup prerequisites are satisfied.

## Updates and diagnostics

1. Check the default update policy on a new installation.
   Miri checks daily and asks before installing an update.
2. Enable automatic updates and start Miri with an update available.
   Miri installs the update in the background without an installation prompt.
   The app update carries its pinned engine upgrade.
3. Open logs and use **Copy diagnostics**.
   Logs remain local, and Miri provides a preview before copying.
   Diagnostics include versions, monitor setup, permission status, engine status, and redacted logs.
   Window titles, document paths, usernames, and raw configuration are excluded by default.
4. Observe network activity during management, update checks, and update downloads.
   Miri sends no telemetry or window-management data.
   Update checks and downloads can use the network.
5. Exercise diagnostics with known window titles, document paths, usernames, and raw configuration values in the test data.
   Inspect both the preview and the clipboard contents.
   Neither contains those fields under the default diagnostics policy.

## Public-release delivery

1. Validate the release disk image on the target Mac.
   The app has Developer ID signing and Apple notarization.
2. Install the release through its Homebrew cask.
   The installed app follows the same permission and setup behavior.
3. Check the distributed source and license notices.
   The release follows the accepted GPL-3.0-or-later direction and preserves Paneru's required MIT notices.

## Remaining limits

The intended gesture defaults and conflict policy are accepted.
Gesture-test pass criteria and result invalidation are accepted.
Supported gesture combinations still need engine and hardware verification.
Configuration keys, validation ranges, and private API fallbacks require review against the actual pinned dependency.
This checklist does not supply a memory-stability threshold or settle Q6 about release duration, which Sam decides at the final check before publishing v1.
The [design tree status](design-tree-status.md) retains those open items.
