# Miri v1 specification

Draft synthesized from the saved repository documents on 14 October 2026.
The deleted design conversations are not a source for this draft.
Accepted requirements describe intended behavior, not implemented or verified behavior.
This checkout has no app implementation, automated test suite, or completed hardware validation.
Sam confirmed both testing seam proposals below.
This draft does not publish a GitHub issue or authorize implementation before the recorded prerequisites and shared-understanding confirmation.

## Problem Statement

Sam wants a scrolling window manager for daily use with a native macOS app interface.
Paneru's existing interface does not meet that need.
Users need ordinary controls for starting management, configuring layouts and shortcuts, checking setup, and diagnosing failures without editing configuration files.

Window management must remain predictable across physical monitors and native Spaces.
Scrolling must preserve display ownership, including when windows move beyond a display's visible area.
Users must retain access to every managed window after management stops or fails.
Selecting an existing engine does not establish that these requirements work on Miri's target hardware.

Miri also needs a public distribution that preserves user settings, keeps window-management data local, and respects the accepted macOS permission boundary.
The saved documents define this direction but retain unresolved product questions and engineering prerequisites.

## Solution

Miri v1 provides a native macOS app interface built for Miri using SwiftUI and AppKit where needed.
It bundles a pinned Paneru-based window engine as a separate helper process.
Users operate the engine through Settings, menu bar controls, keyboard commands, and verified strip gestures.
Closing Settings leaves window management running.

Each physical monitor and native Space has an independent horizontal scrolling strip of columns.
V1 includes column navigation and resizing, vertical window stacks, floating windows, and dedicated monitor navigation.
It supports horizontal, vertical, and mixed physical monitor arrangements that Sam can verify on real hardware.
Display changes follow macOS Space migration, with reachable floating windows when strip re-attachment fails.

Miri provides permission guidance, a setup checker, immediate persistent settings, shortcut recording, local logs, and redacted diagnostics.
It restarts an isolated engine crash and stops automatic retries after three crashes within five minutes.
Window recovery must also work when the engine cannot execute its clean-shutdown handler.

Public distribution uses a Developer ID signed, notarized disk image, a Homebrew cask, and Sparkle updates that deliver the app and engine together.
Initial validation targets Sam's Apple silicon Mac on macOS 27.0.
V1 provisionally supports macOS 27 and later, subject to the recorded validation limits.
The custom Miri dock and other deferred features remain outside v1.

## User Stories

These stories express accepted v1 outcomes from the release scope, ADRs, accepted keybinding reference, configuration contract, and app acceptance checklist.
The few additional planned setup details are identified below rather than assigned accepted status.
They do not claim that a working app already exists.
Stacking in either direction moves only the focused window, as Sam decided on 15 October 2026.
Broader feature proposals are not promoted into accepted requirements.

### Installation, distribution, and system access

1. As a Miri user, I want native settings controls, so that ordinary setup does not require configuration-file editing.
2. As a Miri user, I want the window engine bundled with the app, so that I do not need a standalone Paneru installation.
3. As a Miri user, I want a signed and notarized disk image, so that I can install the public release through macOS.
4. As a Miri user, I want a Homebrew cask, so that I can install the same product through Homebrew.
5. As an Apple silicon Mac user, I want a documented provisional macOS 27-or-later support boundary, so that I understand the initial platform limits.
6. As a Miri recipient, I want GPL-3.0-or-later source and preserved Paneru MIT notices, so that I can exercise the supplied software freedoms.
7. As a Miri recipient, I want public source available when binaries are distributed, so that I can inspect the distributed software.
8. As a Miri user, I want window management to require only Accessibility permission, so that additional permission grants are unnecessary.
9. As a Miri user, I want SIP to remain enabled and screen capture to remain unused, so that Miri respects its system-access boundary.
10. As a Miri user, I want window management and logs to stay local without telemetry, so that Miri does not transmit my window-management data.

### Permission guidance and setup checking

11. As a Miri user, I want an explanation of missing Accessibility permission, so that I understand why window management cannot start.
12. As a Miri user, I want a link to Accessibility settings, so that I can grant the required permission myself.
13. As a Miri user, I want guidance naming the permission identity verified by the helper prototype, so that I enable the correct entry.
14. As a Miri user, I want management to start only after permission is available, so that the app does not misrepresent its ability to manage windows.
15. As a Miri user, I want recovery guidance after moving or replacing the installed bundle, so that I can restore Accessibility access.
16. As a Miri user, I want Miri to refuse to start window management while another window manager runs, so that two managers do not control my windows simultaneously.
17. As a Miri user, I want the setup checker to name the competing tool, including standalone Paneru, so that I know which tool to quit.
18. As a standalone Paneru user, I want Miri to leave my Paneru configuration untouched, so that trying Miri preserves my existing setup.
19. As a Miri user, I want window management blocked when Displays have separate Spaces is off, so that management follows the required Space model.
20. As a Miri user, I want the setup checker to explain the logout requirement for that setting, so that I can complete the change.
21. As a Miri user, I want Stage Manager to be reported by the setup checker, so that I can identify a relevant setup condition.
22. As a Miri user, I want macOS gesture conflicts reported with System Settings guidance, so that I can resolve them manually.
23. As a Miri user, I want unavailable non-gesture checks shown as Not checked with manual instructions, so that unavailable checks never appear passed.
24. As a Miri user, I want setup results to update as problems are resolved, so that I can see whether the reported conditions remain.
25. As a Miri user, I want Miri to leave macOS settings changes to me, so that the setup checker does not change system behavior automatically.
26. As a Miri user, I want unsupported hardware and OS conditions distinguished from recoverable setup problems, so that I understand the relevant limitation.

Stories 24 and 26 retain planned setup details from the Setup document.
They describe documented intent, not separately accepted product choices or completed automatic checks.

### App lifecycle and window recovery

27. As a Miri user, I want opening the app to start management after permission is granted, so that ordinary launches start my window manager.
28. As a Miri user, I want an explicit stopped state to survive relaunches, so that reopening Miri respects my decision to stop management.
29. As a Miri user, I want a Start control, so that I can resume management after stopping it.
30. As a Miri user, I want a Stop control, so that I can pause management while keeping the app available.
31. As a Miri user, I want all previously managed windows accessible after Stop, so that off-screen windows remain usable while management is stopped.
32. As a Miri user, I want Quit Miri to stop both the app and helper, so that quitting ends Miri's window management.
33. As a Miri user, I want every managed window accessible after Quit Miri, so that quitting never strands a window off-screen.
34. As a Miri user, I want closing Settings to leave management running, so that the settings window does not determine engine operation.
35. As a Miri user, I want to reopen Settings through the menu bar or macOS Dock entry, so that app controls remain accessible.
36. As a Miri user, I want launch at login enabled by default, so that my window manager starts with my session.
37. As a Miri user, I want to change launch at login through Settings, so that I control automatic app startup.
38. As a Miri user, I want Settings and the menu bar to survive an engine crash, so that I can inspect the failure.
39. As a Miri user, I want an isolated engine crash restarted automatically, so that a single failure does not require manual recovery.
40. As a Miri user, I want startup session restore enabled, so that the layout returns after an engine start or crash restart.
41. As a Miri user, I want retries stopped after three crashes within five minutes, so that repeated failures do not continue indefinitely.
42. As a Miri user, I want the failure view to provide logs and a manual restart control, so that I can investigate and retry.
43. As a Miri user, I want a successful manual restart to reset the crash count, so that subsequent recovery uses a fresh count.
44. As a Miri user, I want the displayed engine state reconciled after restart or reconnection, so that controls reflect the actual engine state.
45. As a Miri user, I want windows accessible after an unrecoverable engine failure, so that access does not depend on a successful restart.
46. As a Miri user, I want recovery to work without the engine's clean-shutdown handler, so that abrupt termination cannot strand windows.

### Scrolling layout and defaults

47. As a Miri user, I want a horizontal strip on every managed physical monitor and native Space, so that each desktop has its own layout.
48. As a Miri user, I want the same scrolling layout on all connected displays, so that using another monitor preserves the interaction model.
49. As a Miri user, I want window order and focus independent between strips, so that work on one strip does not rearrange another.
50. As a Miri user, I want each strip's scroll position independent, so that scrolling one strip leaves other strips unchanged.
51. As a Miri user, I want new resizable windows to start at 50% of display width, so that their initial size is predictable.
52. As a Miri user, I want existing windows to retain their widths, so that starting management or opening another window preserves their sizes.
53. As a Miri user, I want default width presets of 0.25, 0.33, 0.5, 0.66, and 0.75, so that preset cycling uses the accepted sizes.
54. As a Miri user, I want to edit the width preset list, so that preset cycling fits my preferred window widths.
55. As a Miri user, I want an eight-point inner gap by default, so that spacing between windows follows the accepted layout.
56. As a Miri user, I want an eight-point outer gap by default, so that display-edge spacing follows the accepted layout.
57. As a Miri user, I want separate inner and outer gap controls, so that I can adjust both kinds of spacing.
58. As a Miri user, I want automatic column centering only when the strip overflows the display, so that a fitting strip does not recenter automatically.
59. As a Miri user, I want space reserved for the visible macOS Dock without another setting, so that the layout respects the Dock.
60. As a Miri user, I want instant strip movement when Reduce Motion is enabled, so that Miri follows my macOS motion preference.
61. As a Miri user, I want a disable-animation setting, so that I can make strip movement instant independently of Reduce Motion.

### Keyboard navigation, movement, and sizing

62. As a Miri user, I want to focus the column on the left with arrow or Vim keys, so that I can navigate without the pointer.
63. As a Miri user, I want to focus the column on the right with arrow or Vim keys, so that I can navigate in either direction.
64. As a Miri user, I want to focus the window above within a column, so that I can navigate a vertical stack.
65. As a Miri user, I want to focus the window below within a column, so that I can reach another window in the stack.
66. As a Miri user, I want to focus the first column, so that I can reach the start of the strip directly.
67. As a Miri user, I want to focus the last column, so that I can reach the end of the strip directly.
68. As a Miri user, I want numbered shortcuts for columns 1 through 9, so that I can select a column directly.
69. As a Miri user, I want a numbered jump to focus that stack's last-focused window, so that the jump restores my working context.
70. As a Miri user, I want to move the focused column left with Shift and directional keys, so that I can change column order.
71. As a Miri user, I want to move the focused column right with Shift and directional keys, so that I can reorder in either direction.
72. As a Miri user, I want to move a window upward within a column, so that I can change the stack's vertical order.
73. As a Miri user, I want to move a window downward within a column, so that I can place it below another window.
74. As a Miri user, I want to move the focused column to the first position, so that I can place it at the strip's start.
75. As a Miri user, I want to move the focused column to the last position, so that I can place it at the strip's end.
76. As a Miri user, I want to cycle column width presets forward, so that I can select a configured width through one command.
77. As a Miri user, I want a full-width column command distinct from native fullscreen, so that I can enlarge a tiled column.
78. As a Miri user, I want an explicit center-column command, so that I can request centering through a shortcut.
79. As a Miri user, I want each wider command to add five percentage points of display width, so that width adjustments use fixed increments.
80. As a Miri user, I want each narrower command to remove five percentage points of display width, so that I can reverse width adjustments.
81. As a Miri user, I want each taller command to add five percentage points of display height, so that height adjustments use fixed increments.
82. As a Miri user, I want each shorter command to remove five percentage points of display height, so that I can reverse height adjustments.
83. As a Miri user, I want resizing to respect window size constraints, so that commands do not require unsupported window dimensions.
84. As a Miri user, I want to equalize window heights within a column, so that the stack can share its height evenly.
85. As a Miri user, I want the accepted Stop shortcut to pause management, so that keyboard access includes lifecycle control.

### Stacks, floating windows, and native fullscreen

The accepted bindings provide stacking and pop-out actions in both directions.
Stacking in either direction moves only the focused window, and the rest of its old stack stays in place.
That decision remains open.

86. As a Miri user, I want the assigned stack-left command, so that I can combine windows with the neighboring column on the left.
87. As a Miri user, I want the assigned stack-right command, so that I can combine windows with the neighboring column on the right.
88. As a Miri user, I want to pop the focused window out to the right, so that I can give it a separate column.
89. As a Miri user, I want to pop the focused window out to the left, so that I can choose either side for its separate column.
90. As a Miri user, I want several windows to share a vertical stack, so that one column can hold multiple windows.
91. As a Miri user, I want to float or unfloat the focused window, so that I can change whether the strip manages it.
92. As a Miri user, I want fixed-size windows to float automatically, so that Miri does not impose unsupported resizing.
93. As a Miri user, I want Miri's Settings to float automatically, so that configuration stays outside the managed strip.
94. As a Miri user, I want clicking and macOS app or window switching to reach floating windows, so that they remain accessible.
95. As a Miri user, I want native fullscreen windows left unmanaged, so that native fullscreen remains a macOS interaction.
96. As a Miri user, I want a window leaving native fullscreen to return to its original column, so that fullscreen preserves its strip position.

### Physical monitors, native Spaces, and display changes

97. As a Miri user, I want horizontal physical monitor arrangements supported, so that side-by-side displays can scroll reliably.
98. As a Miri user, I want vertical physical monitor arrangements supported, so that displays above or below one another use independent strips.
99. As a Miri user, I want verified mixed physical monitor arrangements supported, so that three-display setups can follow the same model.
100. As a Miri user, I want off-screen windows to stay on their assigned displays, so that strip scrolling does not relocate windows between monitors.
101. As a Miri user, I want trackpad scrolling to target the display under the pointer by default, so that the pointed-at strip moves.
102. As a Miri user, I want a setting to target the focused window's strip instead, so that I can choose the alternative trackpad target.
103. As a Miri user, I want keyboard commands to act on the focused strip, so that keyboard targeting remains predictable.
104. As a Miri user, I want ordinary strip navigation and scrolling to remain within the current display, so that displays retain independent navigation.
105. As a Miri user, I want dedicated focus commands for monitors above, left, below, and right, so that navigation follows physical positions.
106. As a Miri user, I want dedicated window-move commands for those monitor directions, so that I can move a window across displays deliberately.
107. As a Miri user, I want the next-display shortcut retained, so that the accepted default set includes that dedicated monitor command.
108. As a Miri user, I want a monitor command toward an absent display to do nothing, so that navigation does not move windows unpredictably.
109. As a Miri user, I want a moved window to keep its column and display-relative width, so that monitor movement preserves the documented layout behavior.
110. As a Miri user, I want clicking a window on another display to change focus, so that pointer focus works across monitors.
111. As a Miri user, I want strips to stay on connected displays, so that their display ownership remains stable during ordinary use.
112. As a Miri user, I want a disconnected display's strips to follow their macOS Space and retain window order, so that migration follows macOS.
113. As a Miri user, I want strips to return when macOS returns their Space to a reconnected display, so that reconnection follows Space migration.
114. As a Miri user, I want failed strip re-attachment to leave reachable floating windows, so that disconnecting a display never loses window access.
115. As a Miri user, I want every window reachable after unplugging, lid changes, sleep, wake, or display reconfiguration, so that display changes preserve access.
116. As a Miri user, I want virtual-workspace commands and their indicator hidden in v1, so that the interface reflects the native-Space-only scope.

### Strip gestures and verification

117. As a Miri user, I want three fingers, four fingers, and Off as strip gesture selections, so that controls expose the accepted v1 choices.
118. As a Miri user, I want initial setup to recommend four fingers but default to Off without verified usability, so that unverified gestures remain disabled.
119. As a Miri user, I want a usable four-finger gesture enabled only without a macOS conflict, so that strip movement works independently.
120. As a Miri user, I want the strip to follow finger movement by default, so that horizontal movement follows the accepted direction.
121. As a Miri user, I want a persistent direction-reversal preference, so that I can choose the other swipe direction after required verification.
122. As a Miri user, I want Off to stop strip gesture interception, so that Miri leaves that gesture unused.
123. As a Miri user, I want a confirmed known conflict to disable the conflicting strip gesture, so that it cannot trigger conflicting macOS behavior.
124. As a Miri user, I want keyboard management to continue while gestures are disabled, so that gesture conflicts do not prevent otherwise valid management.
125. As a Miri user, I want manual instructions for confirmed gesture conflicts, so that I can change macOS settings myself.
126. As a Miri user, I want unavailable gesture detection shown as Unable to verify, so that uncertainty is not reported as success or a conflict.
127. As a Miri user, I want a real gesture test when detection is unavailable, so that I can establish usability through observed strip movement.
128. As a Miri user, I want test success to require consistent movement without unintended macOS actions, so that the result reflects actual usability.
129. As a Miri user, I want explicit confirmation required after a successful gesture test, so that usability is not declared without my confirmation.
130. As a Miri user, I want the result named Verified by user test, so that it does not claim automatic verification of macOS configuration.
131. As a Miri user, I want failed or inconclusive gesture tests to leave the gesture Off, so that uncertain usability cannot enable interception.
132. As a Miri user, I want confirmed known conflicts to override user-test results, so that confirmation cannot enable a known conflicting gesture.
133. As a Miri user, I want gesture preferences saved and a retest option available, so that I can revisit usability without losing my preference.
134. As a Miri user, I want ordinary restarts to preserve user-test validity, so that unchanged conditions do not require another test.
135. As a Miri user, I want finger-count or direction changes to invalidate prior results, so that the changed gesture requires fresh verification.
136. As a Miri user, I want macOS or engine upgrades to invalidate prior results, so that changed software requires a new gesture test.
137. As a Miri user, I want detected or reported relevant macOS gesture changes to invalidate results, so that changed assignments require retesting.
138. As a Miri user, I want invalidated gestures kept Off until successful retesting and confirmation, so that saved preferences do not imply current verification.
139. As a Miri user without a supported trackpad, I want keyboard window management, so that strip gestures are not required for ordinary use.

Story 139 retains the Setup document's planned guidance for users without a built-in trackpad or Magic Trackpad.
Hardware support has not been validated.

### Configuration and shortcut customization

140. As a Miri user, I want valid Settings changes applied immediately without Save or restart, so that configuring Miri changes its current behavior.
141. As a Miri user, I want Settings changes persisted across launches, so that relaunching preserves my chosen values.
142. As an advanced Miri user, I want a single editable TOML configuration, so that I can maintain settings with my dotfiles.
143. As an advanced Miri user, I want valid external configuration edits detected and applied, so that file edits and Settings use the same configuration.
144. As a Miri user, I want invalid TOML to retain the last valid engine settings, so that a syntax error does not replace working settings.
145. As a Miri user, I want configuration errors and their lines shown in Settings and the menu bar, so that I can locate the problem.
146. As a Miri user, I want unreadable or invalid configuration preserved, so that Miri does not overwrite a file it cannot read correctly.
147. As a Miri user, I want write failures reported while retaining the last valid settings, so that failed persistence does not silently change my configuration.
148. As a standalone Paneru user, I want Miri never to read my configuration as a fallback, so that Miri settings remain isolated.
149. As a Miri user, I want a configuration backup before upgrade migration, so that the original settings remain available.
150. As a Miri user, I want successful migrations to preserve my values, so that upgrading retains my choices.
151. As a Miri user, I want an unsafe migration to leave the original file unchanged and report an error, so that upgrading cannot discard values.
152. As a Miri user, I want a shortcut recorder, so that ordinary binding changes do not require file editing.
153. As a Miri user, I want several bindings per action, so that one action can support multiple shortcuts.
154. As a Miri user, I want AZERTY, QWERTZ, and Dvorak layouts respected, so that recording and actions work with my keyboard layout.
155. As a Miri user, I want a binding assigned to another Miri action rejected, so that recording cannot silently replace that action's binding.
156. As a Miri user, I want warnings for known macOS shortcut conflicts, so that I can assess those conflicts before using a binding.
157. As a Miri user, I want custom bindings preserved during upgrades, so that updating does not replace my shortcuts.
158. As a Miri user, I want new defaults added only on unused keys, so that new actions do not overwrite my bindings.
159. As a Miri user, I want an explicit reset to the current default set, so that replacing custom bindings remains my decision.

### Updates and diagnostics

160. As a Miri user, I want daily update checks by default, so that the app regularly checks for available releases.
161. As a Miri user, I want approval requested before default update installation, so that I choose when the update installs.
162. As a Miri user, I want an opt-in automatic-update setting, so that I can choose background installation at startup.
163. As a Miri user, I want enabled automatic updates installed silently at startup, so that this selected policy does not require installation prompts.
164. As a Miri user, I want app updates to carry the pinned engine, so that the app and engine upgrade together.
165. As a Miri user, I want update controls available through the app, so that I can inspect available updates.
166. As a Miri user, I want access to local engine logs, so that I can investigate setup or engine failures.
167. As a Miri user, I want a Copy diagnostics control, so that I can prepare information for a GitHub report.
168. As a Miri user, I want diagnostics to include versions, monitor setup, permission status, engine status, and redacted logs, so that reports contain relevant context.
169. As a Miri user, I want window titles, document paths, usernames, and raw configuration excluded by default, so that diagnostics omit those private fields.
170. As a Miri user, I want a diagnostics preview before copying, so that I can inspect the information prepared for the clipboard.
171. As a Miri user, I want clipboard diagnostics to match the redaction policy, so that the copied content excludes the same private fields.
172. As a Miri user, I want diagnostics shared only when I choose to share them, so that collection remains local and user initiated.
173. As a Miri user, I want update checks and downloads without telemetry or window-management data transmission, so that updates respect the accepted privacy policy.

Story 165 retains planned update controls from the Setup document and a proposal in Features and shortcuts.
Story 172 retains the Setup document's planned rule that diagnostic collection remains user initiated and local until the user chooses to share it.
These stories describe documented intent rather than separately accepted v1 requirements.

## Implementation Decisions

These decisions record accepted direction and its engineering limits.
They do not establish completed modules or verified engine capabilities.

### Native app and helper boundary

- Build Miri's native app interface from the ground up with SwiftUI and AppKit where needed.
- Separate Settings visibility from engine operation.
  Settings and menu bar controls remain available after an engine crash.
- Run the Paneru-based engine as a separate helper process inside the app bundle.
  ADR 0009 selects existing command-line and JSON interfaces for app control.
- Keep engine lifecycle, setup checking, configuration, diagnostics, and updating under the app's control.
  Specific internal module interfaces are not yet designed.
- Reconcile actual engine state after restart or reconnection.
  ADR 0009 records the absence of command acknowledgement.
  The earlier-revision assessment of `8a213313538a352537b26e25131cfe75f1e00724` reports subscriptions ending after exit and possible event loss for slow subscribers.
  The complete protocol contract still requires verification against the selected release.
- Use `io.github.samanyudas.miri` for the app bundle identity and `io.github.samanyudas.miri.engine` for the helper.
  Isolate Miri's process and service identities from standalone Paneru.
- Complete the Accessibility attribution prototype before other implementation work.
  The permission identity and final guidance depend on the prototype's observed result.

### Engine dependency and compatibility

- Use the selected Paneru `v0.5.2` release at `b1b6abbd3f1a4be138152b6f0389c9ff1b27a269`, plus Miri patches.
  This records the selection saved on 14 October 2026 rather than a claim about a later latest release.
- Keep Miri patches in the `samanyudas/paneru` fork, included as a git submodule and rebased onto each selected release tag.
  The checkout does not yet contain that engine integration.
- Upgrade one release tag at a time after a multi-monitor regression check on Sam's hardware.
  Sparkle delivers engine upgrades with app updates.
- Limit engine changes to app integration, isolation, and verified compatibility fixes.
  Contribute compatibility fixes upstream where possible instead of establishing a permanent fork.
- Require only Accessibility permission, keep SIP enabled, and avoid screen capture, kernel extensions, and system modifications.
  Undocumented APIs need individual compatibility assessments and defined fallback behavior before adoption.

### Lifecycle and failure handling

- Start management when Miri opens after Accessibility permission is available, unless the explicit stopped state was saved.
- Provide Start, Stop, restart, Quit Miri, and diagnostic controls through the app interface.
  Exact labels and placement remain undesigned.
  Update controls remain planned setup behavior rather than separately accepted v1 controls.
- Enable launch at login by default and expose a Settings control.
- Restart an isolated engine crash automatically with startup session restore enabled.
  Stop retrying after three crashes within five minutes and show the failure, logs, and manual restart control.
- Reset the crash count after a successful manual restart.
  Reconcile the displayed state with the running engine.
- Keep every managed window reachable after Stop, Quit Miri, and unrecoverable engine failure.
  Recovery must not depend on the failed engine's clean-shutdown handler or a successful restart.
  The recovery mechanism remains engineering work.

### Layout, sizing, and display ownership

- Use an independent horizontal scrolling strip for each physical monitor and native Space.
  Keep window order, focus, and scroll position independent between strips.
- Disable Paneru's experimental virtual workspaces in v1 and hide their commands and menu bar indicator.
- Keep ordinary strip navigation and scrolling within the current display.
  Dedicated monitor navigation commands cross displays according to their physical positions.
- Target trackpad scrolling at the display under the pointer by default.
  Offer a setting to target the focused window's strip instead.
  Keyboard commands always act on the focused strip.
- Preserve a moved window's column and display-relative width, as required by the release checklist.
  A monitor command toward a side without a display does nothing.
- Support horizontal, vertical, and mixed physical monitor arrangements that Sam can verify on real hardware.
  Reliable horizontal scrolling is a v1 release blocker.
- Follow macOS Space migration during display disconnection and reconnection.
  Preserve strip window order, and return strips only when macOS returns their Space.
- If strip re-attachment fails within the engine's timeout, make its windows floating and reachable.
  Keep no separate saved display-layout state or reconnection settings in v1.
  The timeout and this behavior require verification against the selected engine and hardware.
- Start new resizable windows at 50% of display width and retain existing window widths.
  Each width or height adjustment changes size by five percentage points of the display's corresponding dimension, subject to window size constraints.
- Default width presets are `[0.25, 0.33, 0.5, 0.66, 0.75]`, using `[options].preset_column_widths`.
  The fourth preset is `0.66`, not a rounded substitute.
- Default inner and outer gaps are eight points each, with separate controls.
  Paneru has no `gap_inner` or `gap_outer` fields.
  Mapping Miri's gaps to outer and per-window padding requires coordinate verification.
  Miri's allowed gap range remains unselected.
- Automatically center the focused column only when the strip overflows the display.
  Reserve visible macOS Dock space without a separate v1 setting.
- Make strip movement instant when either Reduce Motion or Miri's disable-animation setting is enabled.
  The app setting key and engine mechanism remain unverified.
- Float fixed-size windows and Miri's Settings automatically.
  Reach floating windows through clicking and macOS app or window switching.
- Leave native fullscreen windows unmanaged and require return to the original column when fullscreen ends.
  This accepted outcome remains subject to hardware verification.

### Stacking and default shortcut contracts

Control-Option is the default modifier for strip commands.
Arrow and Vim alternatives apply where the accepted reference supplies them.
The following table records the selected v1 defaults without claiming tested action identifiers or parser syntax.

| Action | Default shortcut | Alternative |
| --- | --- | --- |
| Focus column left | Control-Option-Left | Control-Option-H |
| Focus column right | Control-Option-Right | Control-Option-L |
| Focus window above within column | Control-Option-Up | Control-Option-K |
| Focus window below within column | Control-Option-Down | Control-Option-J |
| Focus first column | Control-Option-Command-Left | |
| Focus last column | Control-Option-Command-Right | |
| Jump to column 1 through 9 | Control-Option-1 through Control-Option-9 | |
| Move column left | Control-Option-Shift-Left | Control-Option-Shift-H |
| Move column right | Control-Option-Shift-Right | Control-Option-Shift-L |
| Move window up within column | Control-Option-Shift-Up | Control-Option-Shift-K |
| Move window down within column | Control-Option-Shift-Down | Control-Option-Shift-J |
| Move column to first position | Control-Option-Command-Shift-Left | |
| Move column to last position | Control-Option-Command-Shift-Right | |
| Send focused window to next display | Control-Option-N | |
| Focus monitor above, left, below, or right | Control-Option-Command with W, A, S, or D, respectively | |
| Move focused window to monitor above, left, below, or right | Control-Option-Command-Shift with W, A, S, or D, respectively | |
| Stop window manager | Control-Option-Q | |
| Cycle preset widths forward | Control-Option-R | |
| Make column full width | Control-Option-F | |
| Center column | Control-Option-C | |
| Make column wider | Control-Option-Equals | |
| Make column narrower | Control-Option-Minus | |
| Make window taller | Control-Option-Shift-Equals | |
| Make window shorter | Control-Option-Shift-Minus | |
| Equalize window heights within column | Control-Option-0 | |
| Stack focused window into left column | Control-Option-] | |
| Stack focused window into right column | Control-Option-[ | |
| Pop focused window out to right | Control-Option-Shift-] | |
| Pop focused window out to left | Control-Option-Shift-[ | |
| Float or unfloat focused window | Control-Option-T | |

- Numbered jumps select columns and focus the selected stack's last-focused window.
  They do not number individual windows.
- Full column width is distinct from native macOS fullscreen.
  macOS Space switching, fullscreen, app switching, closing, and ordinary app commands remain macOS or application interactions.
- Stack-left uses `]`, and stack-right uses `[`, as selected in the reference.
  Stacking moves only the focused window, so Miri must change Paneru's whole-column behavior.
- Supply stack-right and pop-left through Miri's integration because the selected engine source lacks those commands.
  Final action contracts, repeated-command behavior, and safe fullscreen interaction still need reconciliation.
- Actions without selected bindings use Paneru's defaults, changed only where they clash with macOS.
  The complete effective v1 fallback set still requires an audit against the selected release and deferred-feature exclusions.
- Provide a shortcut recorder with several bindings per action and support AZERTY, QWERTZ, and Dvorak layouts.
  Reject a binding already assigned to a different Miri action, warn about known macOS conflicts, and never silently replace another binding.
- Preserve user bindings on upgrade, add defaults only where keys are free, and offer an explicit reset to the current default set.
  Hyper-key recording and tabbed-column commands remain excluded from v1.

### Gesture policy

- Offer three fingers, four fingers, and Off.
  Initial setup recommends four fingers but enables it only when usability without a macOS conflict is verified.
  Otherwise, gestures default to Off.
- Follow finger movement by default and persist a reversal preference.
  The source-backed gesture fields are `[swipe.gesture].fingers_count` and `[swipe.gesture].direction`.
  Source direction values are `Natural` and `Reversed`, but the user-facing mapping still needs real verification.
- A confirmed known macOS conflict disables the conflicting Miri strip gesture, preserves keyboard management, and provides manual instructions.
  Miri never changes macOS settings itself.
- Unavailable gesture conflict detection shows **Unable to verify** and offers a real gesture test.
  Unavailable detection alone is neither a passed check nor a confirmed conflict.
- Consistent strip movement without unintended macOS actions, followed by explicit user confirmation, produces **Verified by user test**.
  This result does not claim automatic verification of the underlying macOS gesture configuration.
- Persist the preference and provide a retest option.
  Failed or inconclusive tests leave the gesture Off, and known confirmed conflicts prevent enablement despite user confirmation.
- Preserve user-test validity across ordinary restarts.
  Invalidate it after a finger-count or direction change, a macOS or bundled-engine upgrade, or a detected or user-reported relevant macOS gesture change.
- Preserve the saved preference after invalidation but keep the gesture Off until another successful test and explicit confirmation.
  Keyboard management continues when its startup prerequisites are satisfied.
- Verify horizontal-only gesture handling and the selected strip target against the pinned engine.
  The inspected engine targets the active workspace and enables vertical interception by default.
  Those source behaviors do not satisfy Miri's accepted policy automatically.

### Configuration and setup contract

- Use one TOML file in Miri's Application Support directory as the configuration source of truth.
  The app reads and writes it, watches external edits, and passes its path explicitly to the engine.
- Reuse Paneru TOML key names and store app-only settings, including launch at login and updates, in `[miri]`.
  Verify that the selected engine can coexist with that section.
  Proposed binding identifiers, parser syntax, and additional app-only keys remain unadopted until verified or selected.
- Apply valid settings immediately and persist them without a Save action or restart.
  If a file is invalid or unwritable, retain the last valid settings and report the error in Settings and the menu bar.
  Report the line for invalid TOML and never overwrite a file that could not be read correctly.
- Prevent standalone Paneru configuration fallback and Lua discovery from overriding Miri's selected file.
  An environment variable alone does not establish this isolation.
- Back up configuration before migration and preserve user values.
  If migration cannot preserve those values, leave the original file untouched and report an error.
  The migration schema and backup mechanism remain engineering work.
- Refuse management startup while a competing window manager runs or Displays have separate Spaces is off.
  Name the competing tool and explain the logout requirement for the Spaces setting.
- Report missing Accessibility permission, the Spaces setting, Stage Manager, competing window managers, and relevant macOS gesture conflicts.
  Link to relevant System Settings pages without changing settings automatically.
- Show **Not checked** with manual instructions for unavailable non-gesture checks.
  Use the distinct gesture verification policy for unavailable gesture checks.
  Stage Manager reporting does not add an undocumented startup blocker.

### Release delivery and diagnostics

- Provisionally target Apple silicon Macs on macOS 27 and later, with initial validation on Sam's macOS 27.0 Mac.
  Revisit the minimum version later and add older versions only after community testing.
  Intel support remains deferred unless Sam needs it.
- Use ad-hoc signing for development builds on Sam's Mac.
  Enroll in the Apple Developer Program before the first public release.
- Distribute a Developer ID signed and Apple-notarized disk image and offer a Homebrew cask.
  Configure Sparkle for app updates carrying the selected engine.
  Signed update feeds and release packaging remain unimplemented engineering work.
- Check for updates daily and ask before installing by default.
  If automatic updates are enabled, install silently in the background at startup.
- Make the repository public at the first working build and keep source public by binary distribution.
  License Miri as `GPL-3.0-or-later` and retain Paneru's required MIT copyright and permission notices.
- Send no telemetry or window-management data off the Mac.
  Update checks and downloads may use the network.
- Keep logs local and provide **Copy diagnostics** with a preview before copying.
  Include versions, monitor setup, permission status, engine status, and redacted logs.
- Exclude window titles, document paths, usernames, and raw configuration by default from both preview and clipboard content.
  The Setup document additionally plans user-initiated diagnostic collection that stays local until the user chooses to share it.
- Define bounded log storage before release.
  The retention limit and mechanism are not selected in the saved documents.

## Testing Decisions

The app acceptance checklist and multi-monitor acceptance checklist define the documented checks below.
Neither checklist has run against an app implementation.
The engine assessments are source inspection, not prior runtime tests.
No existing automated testing seam, test framework, fixtures, or reusable test suite exists in this checkout.

### Test behavior and preserve evidence

- Test externally visible behavior through the highest practical boundary.
  Observe the actual app state, helper lifecycle, managed windows, configuration, clipboard, update effects, and network activity.
  Calling an internal handler or inspecting an engine query alone does not establish the user-visible result.
- Cover the native app interface, bundled helper integration, setup checker, configuration, shortcuts, gesture verification, updates, diagnostics, and release installation.
  Verify real window effects where those components affect window management.
- Complete the Accessibility attribution prototype before other implementation.
  Run permission and lifecycle checks with the actual app bundle and helper identities.
- Use ad-hoc signing for development checks and the Developer ID signed, notarized bundle for public-release checks.
  Keep the installed location stable during permission validation, apart from explicit movement and replacement recovery checks.
- Record app build, pinned engine revision, macOS version, display setup, and observed result for every check.
  An unavailable, unverified, failed, or inconclusive check does not pass.
- Use built-in trackpads or a Magic Trackpad for the supported multi-finger hardware checks.
  Simulation cannot establish native gesture coexistence, display-edge reliability, permission attribution, or hardware compatibility.
- Treat the two saved acceptance checklists as test-design prior art.
  They are requirements and procedures, not evidence of an existing test implementation.

### Documented app acceptance checks

The following groups retain the app checklist's requirements.
The [app acceptance checklist](../../decisions/v1-app-acceptance-checklist.md) supplies the detailed procedures.

1. Verify missing and granted Accessibility permission, the prototype-established identity, actual engine status, and recovery after bundle movement or replacement.
2. Verify competing-manager and separate-Spaces startup blockers, competitor configuration preservation, Stage Manager and gesture reporting, System Settings guidance, and unavailable non-gesture checks.
3. Verify Settings closure and reopening, persisted Stop, Quit stopping both processes, launch-at-login defaults and editing, isolated crash restart, repeated-crash limits, and manual restart reset.
   Keep Settings open for the single-crash check.
   Verify the app remains available and the restarted engine restores its layout.
   After a successful manual restart, verify the displayed state matches the running engine.
4. Prepare windows beyond both visible strip ends.
   Verify every previously managed window remains focusable and interactive after Stop, Quit, unrecoverable failure, and termination without clean-shutdown handling.
   Repeat across the native Spaces and display arrangements in the multi-monitor checklist.
5. Verify immediate and persistent gap and preset edits, external valid edits, invalid TOML, unwritable configuration, last-valid settings, error lines, and preservation of unreadable files.
6. Verify no standalone Paneru fallback reads or file modifications, the accepted defaults, backup-before-migration, preserved values, and unchanged originals after unsafe migration.
7. Verify several bindings per action, AZERTY, QWERTZ, Dvorak, upgrade preservation, defaults only on free keys, and explicit reset.
8. Exercise every v1 binding in the accepted reference, including numbered-column semantics, physical-direction monitor navigation, all stacking directions, and floating actions.
   Stacking assertions expect only the focused window to move.
9. Verify new-window-only 50% width, preserved existing widths, fixed five-percentage-point increments, size constraints, overflow-only centering, and visible Dock reservation.
   Verify fixed-size windows and Miri's Settings float automatically.
   Verify clicking and macOS window switching provide access to floating windows.
10. Verify instant movement with Reduce Motion alone and with Miri's disable-animation setting alone.
    Verify hidden virtual-workspace commands and indicator, unavailable tabbed-column commands, binding rejection, and macOS conflict warnings.
11. Verify three fingers, four fingers, and Off, initial four-finger recommendations, Off without verified usability, both directions, and actual hardware gesture combinations.
    Verify five-finger support is unavailable in v1.
    Verify four-finger gestures can be enabled during initial setup when usability is verified and no macOS conflict exists.
12. Verify no interception when Off, confirmed-conflict disablement, continued keyboard management, manual guidance, unavailable detection, successful real tests, and explicit confirmation.
13. Verify the **Verified by user test** label without automatic-verification claims, persisted preferences, the retest option, restart validity, failed or inconclusive tests, and known-conflict precedence.
14. Verify invalidation after finger-count changes, direction changes, macOS upgrades, engine upgrades, detected relevant gesture changes, and user-reported relevant gesture changes.
    Verify saved preferences, Off until successful retesting and confirmation, and continued keyboard management when startup prerequisites hold.
    Verify Miri does not claim to detect macOS gesture changes when automatic detection is unavailable.
15. Verify daily update checks with installation approval by default and silent startup installation after automatic updates are enabled.
    Verify the update carries the selected engine.
16. Verify local logs, diagnostics preview and clipboard, required diagnostic fields, and exclusion of known private test values under the default policy.
17. Observe network activity during management, update checks, and downloads.
    Verify no telemetry or window-management data leaves the Mac.
18. Validate the signed, notarized disk image, Homebrew installation, permission and setup behavior, available source, GPL direction, and retained Paneru notices.

These are documented checks, not newly selected test frameworks or proof of implementation.

### Documented multi-monitor quick check

Run the quick check on the available setup with at least five windows per strip.
Any failure blocks merging the change that caused it.

1. Scroll each strip in horizontal and vertical arrangements without moving off-screen windows to another display.
2. Scroll one strip without changing another strip's focus or scroll position.
3. Move focus and a window to the other display in both directions.
4. Unplug and replug the external display three times without losing windows.
   Strips return when macOS returns their Space.
5. Close and open the lid once with an external display connected.
6. Sleep and wake three times.
7. Force-quit the engine once and verify automatic restart with restored layout.

### Documented release check and hardware matrix

Each scenario runs at university and at home.
Sam's M3 MacBook Air supports at most two simultaneous displays in the documented setup.
Use its built-in display with one external display, or two external displays with the lid closed.
University hardware includes 24-inch and 27-inch monitors.
Home hardware includes a 27-inch monitor and a 32-inch TV.
Run mixed arrangements last on a friend's MacBook Pro that drives three displays.

Each display has at least two native Spaces, and each strip has at least ten windows.
Use a browser, terminal, Electron app, and document app to cover different window behavior.

1. Test the external display on the left, right, above, and below.
   Repeat with the laptop and then the external display selected as the main display.
2. Scroll every strip to both ends using keyboard and trackpad input.
   Test both trackpad targeting settings and verify the intended strip moves.
   Verify display ownership and independence of focus and scrolling.
3. Repeat with different resolutions and scaling, including the 32-inch TV.
4. Move focus and windows in every available physical monitor direction.
   Verify the moved window keeps its column and display-relative width.
   Verify commands toward an absent display do nothing.
5. Unplug and replug the external display 50 times.
   Include disconnection during a scroll animation and during a window move.
6. Close and open the lid 20 times with two external displays connected.
7. Sleep and wake 50 times, including at least one overnight sleep.
8. Rearrange displays, change the main display, and change resolution and scaling while Miri runs.
9. Unplug a display containing a native fullscreen window.
10. Force-quit the engine ten times during a multi-monitor session and verify restart and startup layout restore.
11. Separately force-quit the engine three times within five minutes.
    Verify retries stop and the failure view exposes logs and manual restart.
12. Complete an eight-hour two-display working session without restarts and check engine memory stability.
    The measurable memory pass rule remains unresolved.
13. Complete the two-week daily-use period across university and home without a lost window or repeated crashes.
    A window-loss bug restarts that period.

After each display change in items 5 through 9, verify every window remains reachable.
Verify strips return to their display when macOS returns their Space.

A single failure fails the release blocker.
Failures include lost windows, wrong-display windows, macOS relocation of off-screen windows, and an engine that does not recover.
After a fix, rerun the full checklist from the start.
The release candidate must pass three consecutive full runs under the saved checklist.
The conflict between that rule and one two-week daily-use period is Q6, which Sam decides at the final check before publishing v1.
This draft does not shorten either requirement.

### Confirmed testing seams

Sam confirmed both proposals after drafting.
This confirmation establishes the testing policy and does not add product behavior or prove implementation.
Neither seam nor its test driver has been implemented.

1. **Confirmed primary seam through the packaged app.**
   Use one app-level end-to-end driver for the actual Miri bundle, its real bundled helper, and observable macOS window effects.
   Exercise Settings, menu bar controls, recorded shortcuts, and the accepted lifecycle through user-facing actions.
   Supply external inputs through configuration edits, helper termination, controlled update availability, and known diagnostic data.
   Assert visible state, window accessibility and geometry, persisted configuration, clipboard contents, and process outcomes.
   Keep the documented real-hardware and signed-release checks at this same system boundary, using manual procedures where necessary.
   The driver technology and fixture implementation are not selected.
2. **Confirmed conditional seam at the app's external-services boundary.**
   Add a single narrow boundary only for cases that cannot be produced reliably through the real system.
   Candidate inputs include unavailable setup inspection, controlled crash-count time, and update-service responses.
   Prefer real external controls when they can produce the case reliably.
   Keep the app-facing behavior real and mark substituted cases explicitly in the results.
   For unavailable setup inspection, substitutes verify only the app's response, including **Not checked**, **Unable to verify**, and the gesture-test offer.
   They do not establish real setting inspection, gesture usability, or completion of hardware checks.
   Substitutes cannot pass the actual Accessibility, gesture, display-edge, hardware, signing, or notarization requirements.
   The boundary's introduction depends on a demonstrated limitation of real-system tests.
   Its concrete interface remains unspecified.

Use the primary seam wherever the real system can exercise the case reliably.
Do not introduce separate tests for every internal module or engine algorithm as an accepted requirement of this draft.
Any additional test boundary requires a concrete limitation and a separate testing proposal.

## Out of Scope

The following work is excluded from v1 by the saved release boundaries.
An accepted deferral does not commit every candidate to a future implementation.

- The custom Miri dock, including its default-enabled control, column entries, app icons, same-app count badges, window-title picker, and dimming behavior.
  Miri's ordinary icon in the macOS Dock remains part of v1.
- Tabbed columns and the Control-Option-Shift-T tabbed-column command.
- The minimap and inactive-window dimming.
- Focus borders, focus-follows-mouse, and mouse-follows-keyboard-focus controls.
- A dedicated shortcut to switch focus between floating and tiled windows.
  Clicking and macOS app or window switching provide access to floating windows in v1.
- Advanced per-app window rules, title regular expressions, strip-placement rules, and an app-picker rules interface.
- Drag-to-reorder and cross-display dragging.
- Display exclusions and their proposed configuration controls.
- Portable display layouts, saved reconnection policies, display profiles, monitor matching, and placement that overrides macOS Space migration.
- Paneru's experimental virtual workspaces and additional virtual rows within a native Space.
- Grid arrangements and a maximum-display-count commitment.
  The v2 display-count discussion does not establish a v1 eight-display guarantee.
- Five-finger strip gestures and other gesture controls beyond the accepted v1 selections, target choice, and direction reversal.
- Fixed-pixel width presets, animation duration or damping controls, and Hyper-key recording.
- Alternative automatic-centering controls for `never` and `always`.
- The guided shortcut tutorial, its taught-shortcut selection, and other deferred first-run teaching.
- A public Miri CLI, URL scheme, and Raycast automation commands.
  The engine's internal command-line integration remains part of the accepted helper design.
- Guaranteed Intel support or support for older macOS versions before the recorded need and testing conditions are met.
- Features requiring Screen Recording, Input Monitoring, disabled SIP, kernel extensions, screen capture, or other system modifications.
- A replacement window engine or a permanent Paneru fork.
- Publishing this draft as a GitHub issue during this task.

## Further Notes

### Unresolved product questions and documentation conflicts

1. **Release duration is deferred as Q6.**
   Release scope describes one two-week daily-use period across university and home.
   The release checklist requires three consecutive full runs, and each full run contains that two-week period.
   The status report records the resulting six-week interpretation and says Sam skipped Q6.
   This draft preserves both requirements without choosing a combined duration or changing the release gate.
   On 15 October 2026, Sam deferred Q6 to the final check before publishing v1.
2. **Stack-left movement scope is decided.**
   On 15 October 2026, Sam decided that stacking moves only the focused window.
   The selected engine source moves the entire column, even when the focused window is already stacked.
   Repeated presses merge successive columns toward the first column.
   Miri must change this engine behavior.
3. **The stacking action contract exceeds the selected engine's commands.**
   The accepted reference assigns stack-right and pop-left shortcuts, but the selected engine source has only stack-left and pop-right commands.
   Miri must supply the missing directions rather than remove the accepted bindings.
   Each direction moves only the focused window, and repeated presses must stay safe.
4. **Source inspection identifies possible fullscreen column loss during stacking.**
   The reviewed stack function removes columns before checking its internal fullscreen column type and can return without restoring them.
   This could conflict with the rule that windows remain reachable.
   No runtime reproduction or hardware result exists.
   Reproduce the behavior before a fix, and resolve it in Miri or upstream without claiming that inspection alone proves a lost window.
5. **The memory-stability acceptance rule is not measurable yet.**
   The release checklist requires stable engine memory during an eight-hour session but defines no threshold or observation method.
   Record the measurement method and proposed pass rule before treating this requirement as satisfied.
   This draft does not invent a limit.
6. **Gap validation and several schemas remain unselected.**
   The eight-point defaults are accepted, but the allowed gap range and coordinate mapping are not selected.
   Additional app-only keys, shortcut action identifiers, binding syntax, migration schema, and backup mechanism remain engineering work.
   Do not adopt proposed examples as a verified Miri schema.
7. **Broad feature documents contain proposals beyond the accepted v1 contract.**
   New-window insertion beside the focused window, avoiding focus theft from background windows, nearest-column gesture settling, spring details, and refresh-rate synchronization appear there.
   Engine-side shortcut handling and event-driven idling also appear as proposed engineering behavior.
   Scrolling to reveal the focused window also appears in that proposal document without a separate accepted commitment.
   Those statements lack the same explicit accepted status as the release scope and app checklist.
   Zero gaps appear in the feature proposal while the accepted configuration documents leave the gap range unresolved.
   This draft does not make those statements new v1 acceptance requirements.
8. **Setup recipes are proposed guidance.**
   The three-finger and four-finger macOS setting recipes and disabling automatic Space rearrangement require supported-version verification.
   Proposed macOS tiling-setting changes concern deferred drag-to-reorder behavior.
   They do not add v1 startup blockers or authorize automatic settings changes.
9. **The fallback shortcut set remains unaudited.**
   The accepted reference delegates unlisted bindings to Paneru defaults, adjusted only for macOS conflicts.
   The precise effective set, parser contracts, and compatibility with hidden v2 commands require selected-release verification.
   Native macOS commands in the reference are companion interactions, not Miri-owned shortcuts.
10. **One settled-branches line is malformed.**
    The status report joins numbered-column semantics and new-window sizing in one bullet.
    Release scope and the app checklist record both decisions separately and clearly.
    This draft retains both without changing their meaning.

### Engineering prerequisites and unverified behavior

The first implementation prerequisite is the actual app-and-helper Accessibility attribution prototype required by ADR 0009.
Permission guidance cannot name an assumed identity before that observation.
Shared-understanding confirmation remains pending before implementation starts.

The selected dependency is the saved `v0.5.2` revision, not the earlier inspected commit `8a213313538a352537b26e25131cfe75f1e00724`.
ADR 0008 cites that earlier commit as evidence for display migration.
Its accepted migration policy remains in force, but its cited source does not prove the selected release works on hardware.
Neither engine assessment built, installed, or ran the engine.

The selected-release assessment and status report identify these unresolved engineering facts:

- Pointer-targeted and focused-target trackpad scrolling need integration because the inspected swipe path targets the active workspace.
- The engine enables vertical gesture interception by default.
  Horizontal-only v1 behavior and coexistence with retained macOS gestures need explicit configuration and hardware checks.
- Deprecated gesture fields and the absent `swipe_natural` key cannot be assumed to implement the accepted gesture settings.
- Engine acceptance of a five-finger count does not establish usable hardware behavior or expand v1.
- Width rules also affect startup-discovered windows.
  A blanket rule does not satisfy new-window-only 50% width while preserving existing widths.
- Grow and shrink select presets.
  The inspected `0.05` comparison is a selection tolerance, not the accepted fixed resize increment.
- Outer and per-window padding have different types and contribute differently between adjacent windows.
  Source limits do not select Miri's allowed gap range.
- A missing selected configuration path can fall back to standalone Paneru locations.
  Lua discovery can override selected TOML in Lua-enabled builds.
  Both must be prevented for Miri isolation.
- Ignoring `[miri]` is an inference from deserialization structure, not a tested coexistence contract.
- Clean exit can reposition and resize tracked windows.
  Abrupt failure cannot depend on that handler, and native recovery remains unverified.
- Configuration reload and command reconciliation, private API compatibility and fallbacks, setup inspection, fullscreen return, and display-edge handling remain unverified.
- The full selected-release source audit, reproducible app-and-helper build, native controls, setup checker, diagnostics, bounded logs, signed feeds, packaging, and cask remain uncompleted.

Selecting display-edge snapping or hiding windows partway off-screen would be an engineering proposal requiring actual verification.
Neither candidate mechanism is an accepted implementation decision.

A specification review noted a test-planning ambiguity between the ten force-quits and the separate three-crashes-within-five-minutes check.
The checklist does not specify spacing or manual resets for the ten force-quits.
Define the procedure without changing the accepted crash policy.

### Configuration location and evidence status

The accepted user-editable configuration location is `~/Library/Application Support/Miri/config.toml`.
This is a user-facing configuration contract, not a selected internal module layout.

Current checkout inspection found design documents, a glossary, ADRs, a license, an icon, and local working artifacts.
Git tracks only the README and icon before this draft.
The saved design documents are local files and remain the source of truth for this task.
Creating this draft does not publish them or establish the current GitHub issue state.

Source inspections are historical evidence about the specified revisions.
Accepted direction, implementation completion, automated-test results, and successful hardware validation remain separate states.
No test framework, existing test coverage, signed distribution, or completed hardware check is claimed here.

### Draft review and tracker handling

Sam confirmed the packaged-app seam and the conditional external-services seam.
This confirmation settles the testing policy only.
It does not resolve the recorded product questions, complete engineering prerequisites, or provide the pending shared-understanding confirmation for implementation.
Keep the open product questions recorded rather than inventing answers.

The project uses GitHub Issues on `samanyudas/miri` through `gh`.
Its canonical labels are `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
The to-spec workflow normally publishes a spec with `ready-for-agent`.
Sam's instruction for this task overrides that publication step.
No issue is created or labelled, and this local draft is not represented as implementation-ready.

### Saved sources

The following saved documents supply the requirements, terminology, limits, and open questions:

- [Release scope](../../decisions/release-scope.md) records accepted product direction and v1 boundaries.
- [Design tree status](../../decisions/design-tree-status.md) records settled decisions, open questions, source findings, and verification limits.
- [Configuration](../../decisions/configuration.md) records the accepted configuration contract and explicitly marked proposals.
- [Keybinding reference](../../decisions/keybinding%20reference.md) records the accepted default bindings and customization policy.
- [Setup](../../decisions/setup.md) records planned setup behavior and proposed recipes requiring verification.
- [Features and shortcuts](../../decisions/features%20and%20shortcuts.md) records broader proposals and references the accepted release boundaries.
- [V1 app acceptance checklist](../../decisions/v1-app-acceptance-checklist.md) supplies derived app checks that have not run.
- [V1 acceptance checklist](../../decisions/v1-acceptance-checklist.md) supplies the accepted quick check and multi-monitor release blocker.
- [Selected engine source assessment](../../decisions/engine-v0.5.2-assessment.md) records source inspection of the selected release without runtime validation.
- [Earlier engine assessment](../../decisions/engine-assessment.md) records source inspection of a different revision.
- [V2 roadmap](../../decisions/v2-roadmap.md) separates accepted deferred direction from future candidates.
- [Glossary](../../GLOSSARY.md) defines the domain vocabulary used here.
- [ADR 0001](../adr/0001-build-a-public-foss-app.md) selects a public FOSS app.
- [ADR 0002](../adr/0002-limit-system-access.md) defines the system-access boundary.
- [ADR 0003](../adr/0003-bundle-a-pinned-paneru-engine.md) selects the pinned engine and patch-delivery policy.
- [ADR 0004](../adr/0004-use-gpl-v3.md) selects GPL-3.0-or-later and preserved Paneru notices.
- [ADR 0005](../adr/0005-include-independent-monitors-in-v1.md) places independent monitors in v1.
- [ADR 0006](../adr/0006-use-a-native-app-with-an-independent-engine.md) defines app lifecycle and recovery direction.
- [ADR 0007](../adr/0007-isolate-miri-configuration.md) defines configuration isolation, reload, error, and migration behavior.
- [ADR 0008](../adr/0008-follow-macos-space-migration-for-display-changes.md) selects macOS Space migration for display changes.
- [ADR 0009](../adr/0009-run-the-engine-as-a-helper-process.md) selects the helper process and first permission prototype.
- [Issue tracker conventions](../agents/issue-tracker.md) define GitHub issue operations.
- [Triage labels](../agents/triage-labels.md) define the five canonical tracker labels.
