# Progress

Updated: 2026-10-31 on branch `docs/79-verified`, based on `main` at `48b104e`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The app foundation, engine integration, configuration, default shortcuts, shortcut customization, and gesture controls are merged.
The current milestone is the remaining v1 features: pointer-versus-focus gesture targeting and drag insertion into a stack.
The stack limit and stack overflow are built and await their hardware checks.
The public release path and the complete acceptance runs follow.

## Held edge shortcuts

[#169](https://github.com/samanyudas/miri/issues/169) is implemented in [engine PR #88](https://github.com/samanyudas/paneru/pull/88), merged with no change from the tested head `cd5fdb5`.
This branch pins `378093f`, the merge of #88 and [engine PR #89](https://github.com/samanyudas/paneru/pull/89), whose files match the combined build tested live below.
Sam decided on 30 October that a held edge shortcut stops at the strip's end and only a fresh press crosses to another display.
The engine's event tap ran every key auto-repeat as a new press, so holding ⌃⌥⌘⇧← for one repeat moved the column to the first position and then onto the next display.
The tap now reads the auto-repeat flag, and a repeated edge command reaches the strip's end but never crosses.
Sam then decided that a held key whose fresh press crosses does nothing more, because its repeats carried focus or the column on to the far end of the new display's strip.
The fresh press now records whether it crossed, and the repeats of that hold do nothing after a cross.
Live on 30 October, a held ⌃⌥⌘← or ⌃⌥⌘→ from a strip's end crossed once and stayed on the window a single press lands on, and a held ⌃⌥⌘⇧← took a Finder window across once and left it where it arrived.
On 30 October, with the built-in display left of the external display, the release build carried focus onto the built-in display after one fresh ⌃⌥⌘← press and 3 synthetic auto-repeats.
The build from this branch stopped at the first column, a fresh press then crossed, and 8 more repeats stayed put.
No window moved.
[The keybinding reference](decisions/keybinding%20reference.md) now records the rule, and this settles the held-key question for #79.

## Empty display focus from Finder

[#168](https://github.com/samanyudas/miri/issues/168) is implemented in [engine PR #89](https://github.com/samanyudas/paneru/pull/89), merged with no change from the tested head `2c83c97`.
This branch pins `378093f`, the merge of #89 and [engine PR #88](https://github.com/samanyudas/paneru/pull/88), whose files match the combined build tested live below.
It therefore carries #88's parser hashes in `scripts/check-compat.py`, the same as [#172](https://github.com/samanyudas/miri/pull/172).
Display focus on a display with no window brings Finder to the front with that display's desktop as key window.
When Finder was already in front, macOS ignored that request, so ⌃⌥⌘ toward an empty display did nothing from a Finder window.
The engine now fronts its own window-less process first in that case, which makes the desktop request a real switch without a pointer move.
On 28 and 30 October, live probes with the same macOS calls confirmed the cause and the fix: fronting any window-less process first, the running engine included, moved the menu bar to the target display in both directions, and the old calls never did.
On 30 October, the combined build passed the end-to-end key press with the built-in display below the external display and emptied through a second virtual workspace.
From a Finder window, ⌃⌥⌘↓ moved the menu bar and focus to the empty display, pressed once or held, and ⌃⌥⌘↑ came back.
With the built-in display left of the external display and emptied, a held ⌃⌥⌘← from a Finder window in the first column crossed once to it.
The build without the fix did nothing in both cases, and ⌃⌥⌘↓ from another app still worked.
This settles the Finder note from the #79 checks.

## Arrow, HJKL, and WASD shortcuts

[#79](https://github.com/samanyudas/miri/issues/79) is done and closed.
[#119](https://github.com/samanyudas/miri/pull/119) merged it as `45d73f0`, with the engine half from [engine PR #67](https://github.com/samanyudas/paneru/pull/67).
[The keybinding reference](decisions/keybinding%20reference.md) records the version 4 table and its upgrade rules.
A declined review nit remains: when several bindings hold an upgraded default's new chords, the Settings notice names only the first.

On 31 October, Miri Developer built from `main` at `48b104e` with engine `e7742b8` passed every #79 check live with real key events on all three key sets.
A version 3 copy of Sam's configuration upgraded to the same version 4 bindings Sam has, and the engine bound 71 distinct chords, none with Fn.
With the built-in display left of the external display, as Sam uses it, focus and moves crossed both ways, a single column and a two-window stack reached each strip end and crossed whole, and nothing crossed further left.
A held edge shortcut stopped at the strip's end, and a fresh held press crossed once and stayed, as the held edge section above describes.
With the displays stacked for the session and the built-in display emptied through a second virtual workspace, the within-strip actions, both edge stages, display focus and moves, insertion after the active column, ⌃⌥N, two- and three-window stacks, and an empty destination all passed.
Focusing the empty display worked from a Finder window too.
When the destination's last-focused window had closed, display focus went to its most visible window.
Settings > Shortcuts listed all three chords for every directional action and the four replaced actions with no shortcut.
No window outside the test changed display or order, and the pointer never moved.

## Windows return to their display

[#142](https://github.com/samanyudas/miri/issues/142) is implemented in [engine PR #75](https://github.com/samanyudas/paneru/pull/75), merged as `f20b00e`. Its tree matches the tested head `e1705af`.
`main` pins `5075a4a`, which also carries engine PR #76 for #103 and engine PR #77, a test deadline.
macOS moves Spaces between displays when a display disconnects, and on replug it hands the main display every Space that existed before, the built-in display's own Space included.
The engine followed the Spaces, so the built-in display's windows stayed on the external display.
The engine now records each display's columns and stacks on the first event of a display change, before macOS destroys any Space, in `src/ecs/display_homes.rs`.
After each reconcile pass it moves back every window whose Space macOS moved to another display or destroyed, in its old order and stack.
Windows that never left keep their place, a window opened meanwhile stays where it was opened, and a window moved to another Space on purpose stays there.
ADR 0008 and the display section of the release scope now describe this behavior.

On 28 October on Miri Developer, a software unplug of the external display (`SLSConfigureDisplayEnabled`, app-only) reproduced the bug on engine `c1f2b5e`: the built-in display's windows ended up in a hidden Space of the external display.
On engine `fa1f098`, three unplug cycles with stacks on both displays returned every window to its display, order, and stack, and a window opened while unplugged stayed on the built-in display.
One cycle also hit the hardware variant: macOS destroyed the built-in display's only Space while it held windows, and they still came back with their stack.
Turning the built-in display off in software could not be undone in software, and only a sleep and wake brought it back.
After that wake, the engine dropped six windows whose AX elements died, which is [#147](https://github.com/samanyudas/miri/issues/147).
Later on 28 October Sam ran a cable unplug, a lid close, and a sleep on engine `e1705af`, with the layout recorded every 4 s.
The cable unplug returned every window to its display, order, and stack.
After the lid and the sleep, the windows the engine still managed came back correctly, but #147 dropped others: their AX elements died and the engine gave up after 1 s.
#142 stays open until #147 is fixed and the lid and sleep checks pass.

## Side-by-side displays

[#103](https://github.com/samanyudas/miri/issues/103) is fixed by [engine PR #76](https://github.com/samanyudas/paneru/pull/76).
The engine hid an off-screen column by leaving a sliver at mid-height and hanging the rest of the window past the display edge.
With another display beside that edge, the window lay mostly on it, so macOS moved it into that display's Space and drew it there.
On a display arrangement change, macOS first pulled such a window back onto its own display, the engine slid it back across the other display, and the engine's topology read then adopted it into that display's strip.
`position_layout_windows` in `src/ecs/layout.rs` now checks the frame a window shows.
If its center, or more of it, lies on another display, the window tucks below its own display's bottom edge.
A frame that no tuck improves, such as one above a display directly below, stays as before.
Free sides keep the mid-height sliver, so arrangements with the displays above and below each other keep their behavior.
Sam chose the bottom corner on 28 October.

Engine PR #76 hung the window past the bottom corner on the side it hangs past, and sat it flush inside that side when a display was beyond the corner.
Flush, the whole width of the window showed along the bottom edge, and Sam rejected that bar.
Step 1 of [#150](https://github.com/samanyudas/miri/issues/150) changes the tuck on engine branch `miri/150-free-corner-hiding`, at `6fda494`.
The window now hangs past a free bottom corner of its own display with 1 point of its width showing.
A free corner has no display beyond it.
The engine tries the corner on the side the window hangs past first, then the other bottom corner.
Only when neither corner is free does the window sit flush, as before.
Harness tests in `src/tests/side_by_side.rs` cover each case, and the two corner tests fail on `5075a4a`.
Sam ran the same change as prototype engine `fa76e14` on 28 October with the displays side by side: no bar showed at the bottom, and every window stayed in its Space.
The step 1 build passed the side-by-side live check on 28 October, including scrolling to both ends without moving windows between Spaces.

Step 2 of #150 is on engine branch `miri/150-edge-slice-geometry`, at `ed67edd`.
When a column tucks, the engine now records an `EdgeSlice` on each of its windows in `src/ecs/shared_edge.rs`.
An `EdgeSlice` holds the sliver the window would show with the other display moved away, in screen points and in the window's own points.
For each display and side, `showing` keeps every front window of the hidden column nearest the edge in strip order.
The engine logs that set at debug level as `showing edge slices: [...]` each time it changes.
Harness tests in `src/tests/shared_edge.rs` compare each slice with the sliver of the same layout with the other display below.
They also cover a hidden stack, the nearest column only, both sides of a middle display, free edges, stacked displays, an inactive strip, and scrolling the column back.
On 28 October, the logged rectangle `(0,38)-(5,1432)` matched the same window's real sliver with the displays stacked.
Step 3 adds the Settings switch and the Screen Recording prompt, in [#152](https://github.com/samanyudas/miri/pull/152).

Step 4 of #150 is on engine branch `miri/150-edge-slice-photos`.
The engine reads `[options] shared_edge_slices`, which is off when absent.
With the switch on and `CGPreflightScreenCaptureAccess` true, each showing slice gets a borderless, non-activating panel at its place, one level below the dim overlay.
`src/ecs/slice_photos.rs` holds the photo state of each slice, and `src/slice_screen.rs` draws the panels and takes the photos with ScreenCaptureKit.
The first photo is taken when the slice shows, and the panel stays out of sight until it arrives.
After that, a photo is taken every 2 seconds while the panel's occlusion state is visible, and the panel repaints only when the photo's pixels changed.
A window gone or a failed photo closes its panel, and a refused photo closes every panel until the config or the permission changes.
The engine logs each step at debug level, with lines that start `edge slice`.
Harness tests in `src/tests/slice_photos.rs` cover the first photo, the refresh, repaint, stale photos, the occlusion cut, the switch and permission gates, and the closing cases.
The prior live session on 28 October verified the granted switch, successful engine captures under Miri Developer's Screen Recording grant, a panel at the logged rectangle, matching edge pixels, and updates about every 2 seconds.
Photos stopped with the switch off, under fullscreen, during display sleep, and while locked.
The initial CPU diagnosis found repeated window enumeration, so engine `14a08e4` reuses each slice's capture filter.
That engine also cancels unwanted pending photos and defers photos of moved panels while unseen.
Sol approved those fixes in round two.
On 29 October, with a release engine built from `14a08e4` and one slice showing, the engine used a median 1.77% of one core with the switch on (1.67% to 1.87%, 5 runs of 30 seconds) and 0.80% with it off (0.67% to 1.03%, 5 runs, alternated).
A slice whose window changed every second measured the same, 1.77% to 1.87% over 3 runs.
Each run took 15 photos, and the engine looked windows up 4 times for 83 photos.
What limits the remaining 1 point of a core is not yet known.

Step 5 of #150 is on engine branch `miri/150-slice-input`, which this branch pins.
The event tap holds back a press on a painted panel, in `src/platform/slice_tap.rs`, so the window beneath the panel never gets it.
The engine then focuses the panel's window and scrolls it into view the way a focus command does, in `src/ecs/slice_input.rs`.
The press lands on the pressed row, at least 12 points inside the window edge that faces the slice, because the outer 3 points are the resize border.
In a live test, a press on the outer points reached no view in Helium or an AppKit window, and two quick clicks widened the window through the macOS double click on a window edge.
Once the window rests on a display and the window server's hit test at that point returns it, the engine posts the press again at the HID level, tagged with its press id.
The tap lets that press through, then the user's drags and release, so a drag goes on in the app.
A release during the slide is held back, and the tap posts it right after the press.
A press that the user dragged and released during the slide is dropped when it arrives, and the window stays focused and revealed.
In a live test of a quick click, the tap saw the posted press before the user's earlier release.
The release then reached Helium and an AppKit view at the panel, about 1190 points from the press, so a button would see a cancelled click.
The tap now stamps each event with its time, the event timestamp for the user's events and the tap's own reading of the same clock for a posted press.
A drag or release that the user made before the posted press went through now reaches the app moved as far as the press.
A Sol review found that a second press during the slide reached the window under the pointer once the panel had closed, and the first press was then dropped.
While a press waits for its window, the tap now drops further presses with their drags and their release, so a fast double click during the slide acts as one click.
A second review found that this check went by the order in which the tap saw events, not by when the user made them.
A second press made before the posted press went through, but seen after it, still reached the window under the pointer.
The tap now notes when the posted press went through, and also drops a press the user made before that time.
The tap now also keeps each dropped button on its own, so a held left press that expires no longer lets through the drags and release of a dropped right press.
After 1.5 seconds without arrival, by event time in the tap and by frame time in the engine, the tap and the engine drop the press, and focus and the scroll stay.
Hover over a panel reaches only the panel, and the tap drops scroll over a panel.
The engine's window lookups treat a point under a panel as having no window, so focus-follows-mouse and click handling ignore the window beneath.
The engine logs each step at debug level: `edge slice press swallowed`, `revealing`, `arrived`, `delivered`, `gave up`, `expired`, `dropped`, `edge slice release moved with its press`, and `edge slice gesture passed through`.
Harness tests in `src/tests/slice_input.rs` drive the engine through the tap's own state machine, with the window server mocked, and fail when the hold, the arrival check, the release, the late release, the second press, the give-up, or the hover and scroll cuts break.
On 28 October, a build at engine `c99fbe8` delivered quick clicks with releases 30 to 150 ms after the press, double clicks, and 20-move drags to an AppKit test window and to Helium, and nothing reached the window beside the slice.
On 29 October, Miri Developer built from this whole stack at engine `e30ba61` ran with the displays side by side.
Turning the switch on drew two slices on the shared edge, one per display, with the test window's playing video in its slice.
Quick clicks of 30, 80, and 150 ms, a double click, and a 20-move drag on that slice reached the test window 12 points inside its edge, as one press and release at one point.
A second press 20 or 30 ms after the first was dropped in 3 of 3 runs, once when the tap saw it after the window arrived but before the delivery, and the first press still reached the window as one click.
Turning the switch off closed both panels.
The give-up after 1.5 seconds is checked only by harness tests.
Those checks used software clicks only, which carry nanosecond timestamps.
At the HID tap, real trackpad and mouse events carry mach ticks, and the tap read them as nanoseconds.
On Sam's M3, every real press after one delivered slice press was then dropped until Miri quit.
Engine `a0c88bf`, merged as `863558c` from [paneru#83](https://github.com/samanyudas/paneru/pull/83), reads each user event's timestamp on the engine's clock.
On 29 October, a build at `a0c88bf` delivered 10 of 10 real trackpad clicks on slices, and no press was dropped.
The same log showed a quick click's release landing as far again from the press, because posting the press had already moved the pointer.
Engine `9e20d4a`, from [paneru#84](https://github.com/samanyudas/paneru/pull/84), moves an early drag or release only while it is still on the panel.
On 29 October, a press on a slice with its release at the moved pointer reached the window at (836, 700) for both, in 3 of 3 runs, where the previous engine released at (1670, 700).
Revealing a tucked column used to pop it into place, and pushing a column off a shared edge made it vanish until a new photo arrived.
Engine `ec7fc7c`, from [paneru#85](https://github.com/samanyudas/paneru/pull/85), lets photos stand in for windows wherever the real window cannot show at a shared edge.
A revealed window's photo slides in with the row and the real window takes over under it, and a column pushed off the edge slides out under its photo.
Each window keeps its last photo, so a later crossing paints at once, and every hidden column's photo follows its place in the row.
On 29 and 30 October, Sam confirmed a slice click slides smoothly, and burst captures of rapid keyboard presses on Sam's M3 showed no bare edge.
The first crossing after the engine starts still moves at once, because no photo is kept yet.
Half-second stalls after some focus changes are [#162](https://github.com/samanyudas/miri/issues/162), and short gaps between ordinary columns are [#163](https://github.com/samanyudas/miri/issues/163), described below.

On 28 October on Miri Developer, Sam's built-in display moved from below the 27-inch display to its left.
On engine `8b450d6`, Grok moved from the 27-inch strip into the built-in strip, which parked it back over the 27-inch display.
Moving the display back put Grok at the end of the 27-inch strip.
On engine `cc9955a`, the same move tucked Grok into the 27-inch display's bottom-left corner, in its own strip and Space.
Scrolling the 27-inch strip to its last and first columns kept every window in Space 515, and moving the display back left every strip and order unchanged.
macOS keeps about 32 points of a tucked window above the bottom edge, so the visible corner is about 5 by 32 points.

### Window contents on shared edges

[#150](https://github.com/samanyudas/miri/issues/150) step 3 adds the **Show window contents on edges next to another display** switch to Settings > Layout, off by default.
It writes `[options].shared_edge_slices`.
Turning it on calls `CGRequestScreenCaptureAccess`, and without the permission the switch stays off with a note and an **Open Screen Recording Settings** button.
Each setup recheck calls `CGPreflightScreenCaptureAccess` and turns a saved switch off with the same note when the permission is gone.
ADR 0002 now allows this one Screen Recording use.
This branch sits on top of steps 1, 2, 4, and 5, so the switch turns on photos and input that already work.
On 28 October, the step 3 build showed the macOS prompt naming Miri Developer.app, kept the switch off with the note after Deny, and showed no second prompt on retry.
Its button opened the Screen & System Audio Recording pane, which listed one Miri Developer.app entry.
After Sam granted that entry, the switch stayed on and wrote the key, with no prompt.
Not checked yet: a grant revoked while the switch is on.

## Gaps between columns while the row scrolls

[#163](https://github.com/samanyudas/miri/issues/163) is partly fixed by [engine PR #87](https://github.com/samanyudas/paneru/pull/87) and [engine PR #90](https://github.com/samanyudas/paneru/pull/90), merged into `miri/v0.5.2` at `5bee78b` and `986c53c`.
Engine PR #87 writes one app's windows from the back of the motion to the front, and keeps Helium's `AXEnhancedUserInterface` off for a whole motion.
That removed most gaps between windows of the same app.
Gaps between windows of different apps stayed, because each window eased to its target on its own while apps take a move at different speeds: Spotify at once, Helium 15 to 40 ms later, and up to a few hundred ms later right after a focus change.
Engine PR #90 paces the row at its slowest window.
While a row animates, no window gets closer to its target than the column behind it, as the window server shows that column.
Sliding photos at the shared edge are held the same way.
A window whose app took every move of a whole motion in time paces from where the engine puts it, so a row of quick apps moves together.
A window that shows no progress for 250 ms stops pacing the row, so a hung app cannot stall it.
The shown frames are read on a thread of their own, on a window server connection of their own: on the main connection the read waited for the engine's own drawing and froze the engine for 500 ms at a time.
On 30 October, 4 alternating rounds of 12 presses on Sam's 27-inch row, with fast-release engines on top of #162, measured desktop between different apps at 359 ms per burst without pacing and 0 ms with it.
The row starts and finishes about as fast as before, and quick apps pause more often mid-motion: 12 pauses over 40 ms per burst instead of 7.
The gaps left come from windows that park or un-park, which snap without an animation, so #163 stays open for them.
[Engine PR #91](https://github.com/samanyudas/paneru/pull/91), merged into `miri/v0.5.2` at `e7742b8`, fixes two cases that #90 left.
When focus moves from one app to another, pacing forgets what it saw of both apps' windows, because an app can turn slow right after a focus change.
In 3 sessions of 10 tries that switch apps and reverse at once, desktop showed in 1 of 10 tries each time before this fix and in none after it.
A photo sliding in at the shared edge now closes only once the window server shows its window at rest, or after 250 ms.
Before, it closed as soon as the app took the move, and the bare desktop flashed where the photo had been.
The slice panels also take their places before the frame's window writes, so the window ahead no longer moves a frame before the photo grows beside it.
Quick apps pause a little more often mid-motion: Spotify paused 4 times over 40 ms per burst instead of 2.
A focus move between two windows of one app still resets nothing, and one burst of 4 showed 33 ms of desktop between two Helium windows.
The recordings and frame captures were removed for privacy and stay local.

## One strip per native Space

[#89](https://github.com/samanyudas/miri/issues/89) is fixed by [engine PR #73](https://github.com/samanyudas/paneru/pull/73), merged as `ba198d9`. Its tree matches the tested head `ade3f05`.
`main` pinned `c1f2b5e`, which includes `ba198d9`.
Mission Control can drag a window to an inactive Space, and the engine learns of it only when that Space activates or a display topology read runs.
On a topology read, `place_extracted_strip` in `src/ecs/display.rs` reused the Space's first row only when that row was empty.
Otherwise it opened a new virtual row parked at the display corner, and v1 has no UI for that row.
Windows from a removed display took the same path.
The engine now appends the moved windows, with their columns, to the end of the Space's selected strip, and opens a strip only when the Space has none.
The engine's workspace popup flashed the row number on every native Space switch, which read as Miri making extra desktops.
The engine now defaults `workspace_popup_status` to `false`, as it does for `focus_follows_mouse`.
Miri cannot write that key into existing configurations, because they define only `[decorations.menu]`, and Miri refuses to add keys to the implicit `[decorations]` table.

On 27 October on Miri Developer, a Finder window dragged in Mission Control to the other Space, followed by a 1-point app-only display origin change, landed alone in a new row 3 on engine `1fd95b1`.
Focusing it hid the Space's other windows and flashed "3".
The same steps on engine `fca146c` appended the window to the end of the destination Space's visible strip, and focusing it changed no row.
On engine `4e26369`, four native Space switches showed no number, and Settings showed no configuration error.
Rows that older builds saved stay in the session until their windows move.
On Sam's Mac, `virtualmovenum` moved Spotify and one Helium window back into their Spaces' visible rows.
On 28 October Sam passed the original Mission Control drag by hand, and the same drag followed by sleep and wake.
Unplugging and replugging the external display left the built-in display's windows on the external display, as on `main`.
[#142](https://github.com/samanyudas/miri/issues/142) tracks the planned restoration that Sam decided, and [#143](https://github.com/samanyudas/miri/issues/143) and [#144](https://github.com/samanyudas/miri/issues/144) track the cross-display drag and broken stacks.

## Apps busy at launch

[#63](https://github.com/samanyudas/miri/issues/63) is partly fixed in [engine PR #74](https://github.com/samanyudas/paneru/pull/74).
`main` pinned its merge commit `c1f2b5e`, which also carries [engine PR #73](https://github.com/samanyudas/paneru/pull/73) for [#89](https://github.com/samanyudas/miri/issues/89).
An app that blocked its main thread for more than 5 s right after launch never got its windows managed, even after the user switched to it.
The engine now parks such an app, asks it for its AX role off the main thread every 500 ms, and admits it once it answers.
An app that answers but is busy again by the next registration waits 1, 2, 4, 8, 16, then 30 s between tries.

On 27 October, live fixture checks on Miri Developer gave these results.
A 10 s block stayed unmanaged on `1fd95b1` and was managed at 10.9 s on `ea9732d`.
An app blocked 1000 of every 1050 ms made 7 main-loop attempts in 45 s and was managed within 3 s of calming down.
The `--busy 300,350` probe managed 575 of 576 windows.
The one miss is the remaining part of #63: the launch scan lists an app's windows once and skips a window whose details time out.
The original 4-in-32 misses did not reproduce on `1fd95b1` in 29 rounds.
On 28 October, the 10 s block was managed at 10.9 s in 2 of 2 runs on `c1f2b5e`.

## Freeze after a keyboard focus change

[#162](https://github.com/samanyudas/miri/issues/162) is fixed by [engine PR #86](https://github.com/samanyudas/paneru/pull/86), merged into `miri/v0.5.2` at `8b026d6`.
After many focus changes, Helium's focus notifications name the macOS caret indicator, a `CursorUIViewService` window that gets a new id on each text-field focus.
The engine tracks no such window, so `auto_discover_unmanaged_focused_windows` in `src/ecs/systems.rs` asked every app for its focused window and its window list on the main loop.
Each question waits up to the 250 ms Accessibility timeout, so one busy app froze the row for about 500 ms, and the animation then took one capped step.
The engine now asks the window server which process owns the window, and asks only that app, or no app when the engine tracks none.
Harness tests in `src/tests/interaction.rs` fail on `ec7fc7c`.

On 30 October on Miri Developer with a debug engine, a test app that blocks its main thread 950 ms of every second reproduced the freeze on `ec7fc7c`.
In 16 Control-Option-Left and Right presses on the 27-inch row, a discovery scan took up to 714 ms, and 4 frames took 250 ms or more, the longest 733 ms.
On the fix, the same presses gave no frame of 150 ms or more, the longest 118 ms, and each discovery took 0 to 5 ms without asking any app.
On `ec7fc7c`, scans that met no busy app still took 35 to 124 ms after each focus change into Helium.
Frames of 40 to 120 ms still follow most presses on the debug engine, from other per-press work.
Sam's 29 October freeze is the same mechanism by inference: two 250 ms timeouts made the 490 ms gap, and the resolver timed out on a busy app during it.

## Re-tiled window slot

[#125](https://github.com/samanyudas/miri/issues/125) is implemented in [engine PR #69](https://github.com/samanyudas/paneru/pull/69), merged as `d829a65`.
Floating a tiled window now records its slot, and tiling it again returns it there while its row is on screen.
For a floated window, that slot wins over a rule's `index`.
Minimized windows keep their old behaviour.
Its tree matches the tested PR head `10ea677`, and `main`'s engine pin `1fd95b1` includes it.
This branch removes its entry from [Known limitations](docs/limitations.md).

On 27 October, a live check with three Finder windows ran on Miri Developer.
On the `maximize-app` build, a floated window that popped right re-tiled after its neighbour.
On this branch's build, the same geometry returned the window to its slot.
Sol approved the engine change in round 2 of sol-loop, after round 1 found the rule `index` case.
Later on 27 October, a build of `main` with engine `1fd95b1` passed the same check: B popped from x=490 to x=522, right of its neighbour A, and re-tiled between C and A.

## Engine panic when stopped during startup

[#121](https://github.com/samanyudas/miri/issues/121) is verified on `main` at `7499990` and closed.
The fix is engine `1fd95b1`, the merge of [engine PR #71](https://github.com/samanyudas/paneru/pull/71).
The ECS used to get `Config` from an `Event::InitialConfig` copy in the event channel, and a stop during startup queued `Event::Exit` ahead of it.
The first frame then ran without `Config` and panicked with "Resource does not exist".
The engine now inserts the config at build time, and `Event::InitialConfig` is gone.
A clean exit then saved the empty startup layout over the session, so the engine now drops `StateFile` when an exit arrives while startup gathers processes.
A probe launched the real engine with temporary XDG folders and its own Mach service name, then sent SIGINT 25 to 100 ms after launch.
Before the fix, 10 of 10 runs panicked.
With the fix, 12 of 12 runs exited with code 0 and kept a seeded 11-column session.
The real app on Sam's desktop, quit with AppleScript, exited without a panic in 8 of 8 runs.
A quit that reached the engine before session restore saved an empty session (13 columns to 0) in 4 of 4 runs.
That interval runs from about 0.1 s to 0.7 s after the engine starts, and [#134](https://github.com/samanyudas/miri/issues/134) tracks it.
A quit after session restore kept all 13 columns in 5 of 5 runs, and the next start restored 15 windows with none missing.
#134 is now fixed, so that row is gone from [Known limitations](docs/limitations.md).

## Session kept when the engine exits before startup finishes

[#134](https://github.com/samanyudas/miri/issues/134) is fixed by [#136](https://github.com/samanyudas/miri/pull/136), merged as `f8cffa0` with engine `8b450d6` from [engine PR #72](https://github.com/samanyudas/paneru/pull/72).
The exit save wrote the half-built startup layout, which has strips but none of the windows startup is still discovering.
The engine now skips the exit save while `Initializing` exists.
On 28 October, Miri Developer built from `main` at `f8cffa0` kept a 9-column session byte-identical for AppleScript quits 0 to 300 ms after the engine started, and saved all 9 columns on a quit at 2 s.
#134 is verified and closed, and this branch removes its row from [Known limitations](docs/limitations.md).

## Known limitations inventory

[#91](https://github.com/samanyudas/miri/issues/91) is implemented on this branch as [Known limitations](docs/limitations.md).
The README and SUPPORT.md link to it.
The audit filed [#120](https://github.com/samanyudas/miri/issues/120) to [#125](https://github.com/samanyudas/miri/issues/125) for confirmed defects that had no issue, and Sam chooses each fix.
#120 is fixed and closed, so the page no longer lists it.
Add each newly confirmed limitation to that page, and remove an entry when its fix is verified.

## Menu-bar apps that open windows later

`main` pins engine `0d023e2`, the merge of [engine PR #70](https://github.com/samanyudas/paneru/pull/70).
Docker Desktop runs as a menu-bar app until its dashboard opens, and then it becomes a regular app.
The engine dropped such an app when it was not regular at engine start, or 5 seconds after its launch, so the dashboard was never tiled.
The engine now keeps the process, and its activation-policy observer starts a new launch watch when the app becomes regular.
Sol approved engine PR #70 in round 1 of sol-loop.
The pin also brings engine PRs #67, #68, and #69, which open PRs #127 and #129 pin on their own.
Engine PR #67 added the `focusedge` and `moveedge` verbs, so `EngineCommand.swift` now mirrors them and `check-compat.py` records the new parser hashes.

The test `a_menu_bar_app_that_becomes_regular_later_is_tiled` fails before the fix and passes after it.
On 27 October, a live check on Miri Developer closed the Docker dashboard, restarted Miri, and opened the dashboard from Docker's menu.
The `main` build at `7bbecc5` never tracked the dashboard.
The fixed build tiled it as a full-height column and focused it.
[#133](https://github.com/samanyudas/miri/issues/133) is verified on `main` at `b8887ef` and closed.

## Windows of busy apps on a hidden Space

[#68](https://github.com/samanyudas/miri/issues/68) is fixed on `main`.
The fix is [engine PR #68](https://github.com/samanyudas/paneru/pull/68), merged as `23bcf1b`, which `main`'s engine pin `0d023e2` includes.

The startup brute-force scan stopped after 250 ms and at element 0x7fff.
An app numbers its elements in creation order, so a busy app's newest window sits past both limits.
On 27 October a new Helium window got element 32890, and the scan gave up at element 15616.
The scan now runs until every window resolves or 0x4000 ids in a row own no window element, with a 2 s ceiling.

On 27 October, `/tmp/miri68/repro.sh` placed Helium windows 55561 and 62288 on a hidden Space and relaunched Miri Developer.
Engine `3fee523` left both unmanaged with restore `missing=2`.
This branch managed both on 4 of 4 relaunches, and restore reported `missing=0`.
Engine start to initialization went from 0.75 s to about 1.2 s on Sam's Mac.

On 27 October, a build of `main` at `b8887ef` with engine `0d023e2` passed the same check on 3 of 3 relaunches.
Helium windows 64426 (element 33795), 55561, and 63045 on a hidden Space were managed, and restore reported `missing=0`.
A Helium window minimized before the relaunch joined its strip when it was restored, without focus.
#68 is closed, and this branch removes its entry from [Known limitations](docs/limitations.md).

## Engine left running after Miri dies

[#33](https://github.com/samanyudas/miri/issues/33) is implemented on this branch.
The fix is engine `4158e8f`, the merge of [engine PR #61](https://github.com/samanyudas/paneru/pull/61), which the engine pin `3fee523` from `main` includes.
Sol approved engine PR #61 in round 2 of sol-loop, after round 1 found that an exit during engine startup was lost, which `aa10128` fixes.
Miri passes its PID to the engine in `PANERU_PARENT_PID`.
The engine watches that process with a kqueue `NOTE_EXIT` filter and exits through its normal cleanup when the process ends.
Miri also treats SIGTERM as Quit, so `kill` stops the engine and recovers windows.
At launch, Miri stops any `miri-engine` whose parent is launchd, then recovers windows, because such an engine holds the Mach service.

Unit tests cover the parent watch, the environment, and finding and stopping an orphan.

On 27 October, `/tmp/miri33/live-check.sh` ran against the real app, with the `azerty-digits` build as the build before the fix.
After SIGTERM on that build, its engine survived with parent PID 1.
The fixed build stopped that orphan at launch.
SIGTERM on the fixed app ended the app within 400 ms, together with its engine.
SIGKILL on the fixed app ended its engine within 600 ms.
The first run found that the SIGTERM handler deadlocked, because it called terminate inside a main-queue callout, and the fix is on this branch.
That run also showed that an engine interrupted during its startup can panic with "Resource does not exist", which [#121](https://github.com/samanyudas/miri/issues/121) tracks.

## Maximized column

[#106](https://github.com/samanyudas/miri/issues/106) keeps a maximized window in its row, so focus moves and swipes scroll past it.
[Maximizing a window](decisions/release-scope.md#maximizing-a-window) records the rules Sam chose on 26 October.
Engine `3fee523` and every later pin include engine PRs [#57](https://github.com/samanyudas/paneru/pull/57), [#58](https://github.com/samanyudas/paneru/pull/58), [#60](https://github.com/samanyudas/paneru/pull/60), [#63](https://github.com/samanyudas/paneru/pull/63), and [#64](https://github.com/samanyudas/paneru/pull/64).
They make a maximized tiled window a display-wide column, make `maximize` the one toggle with `fullwidth` as its older name, and add `[options].maximized_window_side`.
They also restore a maximized window before width, stack, float, and drop actions, and keep maximize in the saved session across an engine restart.
The pin also brings the Picture-in-Picture level fixes from engine PRs [#56](https://github.com/samanyudas/paneru/pull/56) and [#59](https://github.com/samanyudas/paneru/pull/59), and engine PRs #53, #55, #61, and #62.

This branch builds the app part.
Layout settings has a **Maximized stacked window opens** picker, and the ⌃⌥F default is now `window_maximize`, labeled Maximize or restore window.
A file that binds `window_fullwidth` keeps that binding, and Settings lists it under the same action.
After a restart, the engine still focuses the first column, so a maximized window in another column comes back partly in view until it is focused, like any wide column.
An unfocused Lua `SetWidth` stores its ratio but never applies it, for any window.
This predates #106.

On 27 October, this branch's build at engine `3fee523` ran a live check on the 2560 by 1440 main display and the built-in display, with throwaway Finder windows and synthetic input.
First, the build from `main` reproduced the defect: a maximized window filled `0,30 2560x1410`, and after a focus move its neighbor showed on top of it at its slot.
With this branch, a maximized window filled `0,30 2560x1410`, and focus moves east and west scrolled past it 3 of 3 times with no overlap and no change of size.
⌃⌥F, through Sam's `window_fullwidth` binding, and a title-bar double-click toggled the same state, and restore returned the exact earlier slot.
On a floating window, both filled the usable area and restored the exact floating frame.
A stacked window popped out to the right, and to the left after the Settings picker was changed to **Left of its stack**, and restore put it back in its stack slot.
Grow restored first and then grew from the earlier width, a stack command restored first, and a new window opened beside a maximized window, which stayed maximized.
Display moves filled the built-in display and then the main display again, and no native full-screen Space appeared.
After the engine was killed, the session file held the maximize with width share 0.5, the restarted engine showed the window maximized, and the toggle restored its 1276 point width.
Synthetic title-bar drags of the maximized window did not register, so the drag rules and the pointer edge resize are checked only by engine tests.
The acceptance ledger rows stay Pending until a frozen release candidate runs them.

## AZERTY digit shortcuts

[#31](https://github.com/samanyudas/miri/issues/31) is implemented on this branch, which pins engine `28f550f` from [engine PR #53](https://github.com/samanyudas/paneru/pull/53).
On AZERTY only the keypad types digits without Shift, so the engine bound `ctrl+alt-1` to keypad 1.
A key name now matches a main key's character, then a US position, then a keypad key's character, then a fixed key.
The digit names therefore press the top row, and `keypad1` and the other keypad names still press the keypad.
`KeyLayout.keyCode(for:)` follows the same order, so Settings labels ⌃⌥1 as ⌃⌥& on AZERTY, which is the key's unshifted character.

On 26 October, a probe test that calls the engine's own `generate_virtual_keymap` ran with the French layout selected.
Engine `d7a4c3f` resolved `1`, `2`, and `0` to keypad codes 83, 84, and 82, and the fix resolved them to top-row codes 18, 19, and 29.
The fixed app's engine, started under French, logged the same top-row bindings for ⌃⌥1, ⌃⌥2, and ⌃⌥0.
Synthetic key presses were unreliable in that run with both builds, so no press result counts as evidence.

## macOS Fill near the screen bottom

[#108](https://github.com/samanyudas/miri/issues/108) is fixed on this branch, which pins engine `594a6c5`, the merge of [engine PR #52](https://github.com/samanyudas/paneru/pull/52).
After macOS Window > Fill, a tiled window now returns to its slot instead of keeping the Fill height past the display's bottom edge.

On 26 October, a throwaway Helium window in its slot at `1352,38 1200x1394` on the 2560x1440 display ended at `1352,38 1200x1410` after Fill, 8 points past the bottom.
The engine harness reproduced it with the mock's sticky bottom, which models macOS ignoring a small shrink near the screen bottom.
The tile restore had turned off the size check that lowers and regrows a window in that case, and then kept the frame as the app's refusal.
With engine `7bcd7d6`, 3 of 3 Fills returned the same window to `1352,38 1200x1394`, and a Fill on the built-in display left it at its slot.
These are automated observations driven by menu clicks through Accessibility, not physical input.

## Title-bar maximize

Engine `e6c8ebc`, the merge of [engine PR #43](https://github.com/samanyudas/paneru/pull/43), built this for [#88](https://github.com/samanyudas/miri/issues/88), and the branch now pins the later engine `d7a4c3f`.
The [release scope](decisions/release-scope.md#maximizing-a-window) records the rules.
A double-click on a window's top bar fills the usable area of its display, and the next one restores it.
The window keeps its place in the layout while maximized, so its neighbors never move.
[#106](https://github.com/samanyudas/miri/issues/106) replaces this model with a maximized column that stays in its row.

All of #88's code is on `main` through #97, #99, and #116, and ⌃⌥F and the double-click send the same `ToggleMaximize` trigger.
[Engine PR #65](https://github.com/samanyudas/paneru/pull/65) adds a test that a maximized window on an unplugged display stays maximized and restorable, which no test covered.

On 27 October, the build of `main` at `fd16a22`, with engine `1fd95b1`, passed the #88 criteria as #106 revised them, except the gaps below.
Since the earlier check on `3fee523`, that engine adds display moves from engine PR #67, the re-tile slot from #69, and the hidden-Space scan from #68.
A tiled Finder window filled `0,30 2560x1410` and restored its exact frame.
Its neighbors kept their sizes, scrolled aside while it was maximized, and returned to their exact frames on restore.
Four cycles that mixed the double-click and `window maximize` returned the same frames, and focus moves scrolled past the maximized window.
A stacked window returned to its stack slot, and with its stack mate closed it became a full-height column at its old width.
With `stack_limit = "fit"`, a window maximized out of a full 7-window stack returned as a column right after the stack once the stack was full again.
A floating window filled the usable area and returned to its floating frame by both triggers.
`movedisplay south` filled the built-in display at `302,1486 2048x1286`, the restore there kept the width share, and a move back north restored on the large display.
The window stayed maximized while its display switched to another native Space and back.
System Settings filled the height at its 740 point width limit, a throwaway Helium window passed 2 cycles on its tab strip, and `AXFullScreen` stayed false.
A double-click on Finder's view switcher left the window alone, a title-bar drag reordered the row, and the close button closed the window.
These are automated observations on real windows, driven by synthetic mouse events and engine commands, not physical input.
A follow-up run on the same build covered the rest.
A window maximized out of a 3-window stack rejoined at the clamped slot after a mate closed, and a stacked window moved to the built-in display restored as a column there.
A maximized floating window dragged to the built-in display filled it and restored at its earlier size and offset.
A maximized tiled window dragged to empty space on the large display filled it and joined its layout.
Sam unplugged and replugged the large display by hand, and the maximized window on it stayed maximized and restored at its earlier width.
Not checked on this build: physical mouse input, and side-by-side displays, which wait for [#103](https://github.com/samanyudas/miri/issues/103).
[#88](https://github.com/samanyudas/miri/issues/88) is verified and closed, and the [issue comment](https://github.com/samanyudas/miri/issues/88#issuecomment-6443382323) records each criterion.

On 26 October, current `main` with engine `6325638` reproduced the defect on the primary display.
A double-click on a Finder title bar let macOS zoom Finder to 868 points wide, and the engine took that as the column's width, which moved T3 Code 156 points left.
With the candidate, Finder, a stacked Finder window, a Finder window on the built-in display, a Helium window, and a floating Helium window each filled the usable area and returned to their exact frames.
The other windows kept their frames throughout.
A double-click on Finder's back button left the window alone.
These are automated observations on the real windows, driven by synthetic mouse events, not physical input.

macOS ignores a small shrink that leaves a window's bottom edge near the bottom of the screen, but it lets a window grow into that zone.
A restore therefore first ends 100 points above the slot and then grows into it.
The same rule can also stop the layout from shrinking a newly opened window that touches the screen bottom into its slot.
That layout case exists without this branch and may explain [#58](https://github.com/samanyudas/miri/issues/58).

## Maximized windows across displays

Engine `ab3ce39`, the merge of [engine PR #49](https://github.com/samanyudas/paneru/pull/49), which follows [engine PR #44](https://github.com/samanyudas/paneru/pull/44), built this for [#87](https://github.com/samanyudas/miri/issues/87), and the branch now pins the later engine `d7a4c3f`.
A maximized window that a display command moves, or that a title-bar drag drops on another display, fills that display's usable area.
A new column that arrives from another display is never wider than the destination's tiling area.

On 26 October, the build of `feat/title-bar-maximize` with engine `e6c8ebc` reproduced the defect.
A maximized Finder window moved south by `movedisplay south` stayed at `0,30 2560x1410` on the large display, while the engine placed its slot on the built-in display.
Dragged by its title bar to the built-in display, it ended at `-6,1505 800x1278`, partly off the display.
A Helium window on the built-in display had kept a frame 8 points wider than the tiling area from an earlier move, with its left edge off the display.

With engine `39de6ed`, `movedisplay north` and `movedisplay south` made a maximized Finder window fill `0,30 2560x1410` and `182,1486 2048x1286`, and it kept focus.
That engine found the dropped window under the pointer, and its title-bar drag failed live, because macOS dropped Finder 18 points below the pointer.
Engine `4f07509` chose the display by the window's centre, and drags in both directions then filled the same frames.
Review found that a low drop within the large display could put the centre on the built-in display, while macOS keeps the window on the display under the pointer.
Engine `7e937a1` therefore remembers the pressed window and uses the display under the pointer at the release.
With it, title-bar drags down and up filled the same frames, and a low drop within the large display left Finder at `0,885 2560x1410`, although its centre was over the built-in display.
A drag within one display left the window where it was dropped, and the next double-click restored its slot.
These are automated observations on real windows, driven by synthetic mouse events and engine commands, not physical input.
Engine `0ce219c` adds only a test for side-by-side displays, and that test fails without the fix.
Later on 26 October, with the same fix, a throwaway Helium window passed the same display-command, drag, low-drop, and restore checks with the same frames.
After macOS Fill, `movedisplay south` gave Helium `1264,1486 958x1270`, inside the built-in display's tiling area.
Sam checked the stacked arrangement by hand, with a real mouse, and steps 1 to 5 passed.
With the displays side by side, the off-screen columns moved to the other display, so the side-by-side check could not run (#103).
Sam also found that a drag of a maximized window showed no drop line, which a drag after a restore did show.
Engine PR #49 shows the line while a maximized window is over another display, and the drop puts the window in that display's layout at the line.
Over its own display the drag stays a free move with no line.
With engine `1b55f53`, a maximized Finder window dragged within the large display moved to `0,586 2560x1410`, and the layouts did not change.
Dragged onto the built-in display, it filled `234,1486 2048x1286`, kept focus, and joined the built-in display's layout after the Helium column.
The next double-click restored it to its new slot at `1636,1494 638x1270`.
The synthetic run could not show the line clearly, because the built-in display's full-width column puts it at the display edge.
Sam then dragged a maximized window by hand on 26 October and confirmed that the drag works.
Not checked live yet: a horizontal display arrangement, which waits for #103.

macOS Fill on a tiled window on the large display leaves it at `1352,38 1200x1410`, so its bottom edge is 8 points below the display.
Sam's build from `keyboard-focus-pointer` does the same, so this branch did not cause it.

## Picture-in-Picture windows

[#77](https://github.com/samanyudas/miri/issues/77) is implemented on this branch, which pins engine `d7a4c3f`.
That pin includes [engine PR #50](https://github.com/samanyudas/paneru/pull/50) for this issue and [engine PR #51](https://github.com/samanyudas/paneru/pull/51), which stops a flaky SIGABRT in the engine tests.
It also includes engine PRs #44, #48, and #49, which merged into the fork branch first.
A window that its app keeps above the normal window level now floats when it opens, unless a rule sets `floating = false`.
Such a window also takes keyboard focus once when it opens, because Chrome opens its Picture-in-Picture window without focus.
The float toggle and tile overrides work on it as on any other automatically floating window.

On 26 October, the running build at engine `58e5c7d` reproduced the defect with a throwaway Chrome instance.
The Chrome video window and the Document Picture-in-Picture window both sit at window level 3 with the macOS all-Spaces tag.
Miri tiled both, stretched them to the column height, and left focus on the previous app.
With the candidate, both floated and took keyboard focus once, and Chrome became frontmost.
Focus then moved to T3 Code and stayed there, and the video window stayed above every ordinary window.
On the primary display, the video window belonged to both native Spaces and stayed visible above Notes after a Space switch and back.
Closing it left the Chrome source window's tile unchanged, and an engine restart with the window open floated it without taking focus.
The macOS system Picture-in-Picture window, owned by `PIPAgent` at level 19, is the one Safari and IINA use.
Miri does not manage it, and it ignored the keyboard even when made frontmost, so it cannot take keyboard focus.
IINA's player window, which Sam's IINA keeps on top with `alwaysFloatOnTop`, now floats too.
QuickTime Player and IINA hide their player window during system Picture-in-Picture, and its Restore button brings the same window back.
On 26 October at engine `d7a4c3f`, QuickTime came back at the same 640 by 360 frame in its old column, and the whole display layout matched the layout before Picture-in-Picture.
IINA, which floats, came back at the same frame.
For the fallback, QuickTime sat alone in virtual workspace 2, entered Picture-in-Picture, and the display switched to workspace 1.
After Restore, it appeared on the shown workspace 1 at its old size, fully visible at the right edge of the display.
Sam accepted the system Picture-in-Picture focus limit and chose that a Picture-in-Picture window stays on the display where it opened.
These are automated observations driven through the Chrome DevTools protocol and Accessibility, not physical input.
Private local evidence is in `/tmp/miri77/` on Sam's Mac.

A recheck on `main` `12323e5` found a race in criterion 2 and criterion 4.
In 1 of 8 trials, the first Picture-in-Picture window in a fresh Chrome profile tiled at 2013 by 1402 and did not take focus.
Chrome shows that window at the normal level and raises it to level 3 between 20 ms and 90 ms later, and the engine read the level only once.
[Engine PR #56](https://github.com/samanyudas/paneru/pull/56) reads a newly tiled window's level again each frame for one second.
If the level rises, the engine floats the window, gives back the frame it opened with, and focuses it once.
A native test app that raises its window 150 ms after it opens tiled on the old engine.
With engine `aba75ea`, raises after 60, 150, 300, and 600 ms all kept the window floating at its own frame.
The engine query leaves out that test app's floating-level window, before and after the change, but it lists Chrome Picture-in-Picture windows.
A Sol review found that a window arriving without a size could be tiled before its level was known.
[Engine PR #59](https://github.com/samanyudas/paneru/pull/59) leaves such a window untiled until its level check ends, so a raised window floats at the frame its app gave it.
Both fixes reached `main` with the engine pin `3fee523` from [#116](https://github.com/samanyudas/miri/pull/116).
On 27 October, the build at engine `3fee523` floated and focused 3 of 3 first-time Chrome Picture-in-Picture windows, and the test app kept its frame for raises after 150, 300, and 600 ms.
Private local evidence is in `/tmp/miri77b/` on Sam's Mac.

## Keyboard focus and pointer separation

[#90](https://github.com/samanyudas/miri/issues/90) is implemented on this branch, which pins engine `58e5c7d`, the squash merge of [engine PR #41](https://github.com/samanyudas/paneru/pull/41).
Its tree is identical to the tested `d4340b7`.
The engine now defaults `focus_follows_mouse` and `mouse_follows_focus` to `false`.
Centre column, display focus, and display moves move the pointer only when `mouse_follows_focus` is on.
Display focus on a display with no visible window focuses that display's Finder desktop, so its menu bar becomes active without a pointer move.
`[options].focus_follows_mouse = true` is a hidden key that turns pointer-driven focus back on.

On 26 October, the running build at engine `4ba2bf0` reproduced every reported symptom with synthetic input and throwaway Helium windows.
Pointer movement focused the window under it, and keyboard focus, Centre column, display focus, display moves, a new window, and red-button closes moved the pointer.
The candidate build kept the pointer in place in all of those cases, and pointer movement no longer changed focus.
Closing a background window kept the focused window, and closing the focused window changed focus once to its neighbour, in columns and in a three-window stack.
An empty display, made with an empty virtual workspace on the built-in display, became the active display with Finder frontmost and no false focused window.
The hidden key restored pointer focus, and the original configuration was restored byte-for-byte afterwards.
These are automated native observations with synthetic events.
On 26 October Sam closed a background window and the focused window with their red buttons, using a mouse and the trackpad, and reported that it works as expected.
Sam also closed windows in an overflowing stack and reported that it works as expected.
Private local evidence is in `/tmp/miri90/` on Sam's Mac.

## Constrained window width and tile override

This branch pins engine `6325638` for [#93](https://github.com/samanyudas/miri/issues/93), which merges [engine PR #42](https://github.com/samanyudas/paneru/pull/42).
The [release scope](decisions/release-scope.md#stacks) records both accepted rules.
A stacked window records the widest and narrowest widths it refused.
A member at its widest no longer sets the column width, so it keeps its own size at the left edge and the rest of the column stays empty.
A column also reserves a member's refused minimum width.
Tiling a window with the float toggle while a floating rule matches it records an override in the engine's `tile-overrides.json`.
The override survives an engine or Miri restart while that window stays open, and floating the window again or closing it ends the override.
A window is known by its window number, process ID, and process start time.

On 26 October, current `main` reproduced the defect on the primary display.
System Settings, which accepts no more than 740 points of width, sat above Spotify, which accepts no less than 800.
The column took 748 points, so T3 Code covered the right 52 points of Spotify.
With the candidate, the column reserves 808 points, Spotify stays fully visible, and the desktop shows to the right of System Settings.
Unstacking, restacking, reordering, a width step, a second stacked column of two Helium windows, and a move to the built-in display and back all kept that spacing.
Miri Settings stayed tiled after an engine-only restart, and floating it again or closing it removed its override entry.
These are automated observations on the real windows, driven through the engine's command socket, not physical keyboard input.

### Automatic floating of fixed-size windows

This branch pins engine `ae05362`.
A window whose size macOS reports as not settable now floats when it opens, unless a rule sets `floating = false`.
The float toggle tiles such a window with the same override as a rule-floated window.
A window that opens floating now also takes focus.
A floating window that is minimized, including one minimized when the engine starts, floats again when it is restored instead of tiling.
Before, macOS reported its focus before the engine tracked it, so the float toggle acted on the previous window.

On 26 October, synthetic key presses drove the hotkey path on the primary display.
A fixed-size test app, 420 by 332 points, floated when it opened and took focus.
Control-Option-T tiled it and wrote its override.
It stayed tiled after a full Miri restart, a second press floated it and removed the override, and quitting the app removed the override again.
Stacked under Spotify with Control-Option-], it kept its 420 by 332 size at the column's left edge.
System Settings stacked onto Spotify with Control-Option-] in an 808-point column, and Ghostty started past Spotify's right edge.
Moving Settings to the top and moving focus within the stack by key kept that spacing.
No physical keyboard or mouse input was used.

### Fixed-size windows in stacks

This branch pins engine `3bdae94`, which merges [engine PR #46](https://github.com/samanyudas/paneru/pull/46) and [engine PR #47](https://github.com/samanyudas/paneru/pull/47).
On 26 October, Sam chose to give a fixed-size window's spare stack height to the other windows.
A window that cannot be resized now keeps its own height in a stack, and the spare height goes evenly to the resizable windows.
In a stack of only fixed-size windows, they stack from the top and the rest of the column stays empty below the last one.
A window that opened floating now gets its padding when it is tiled, so it lines up with its column.
Quitting an app now ends the tile overrides of its windows, as closing them does.

On 26 October, on the primary display with synthetic key presses:
Calculator stacked under Spotify left Spotify 994 points with no gap or overlap.
Digital Color Meter as a third member gave Spotify 777, Calculator 408, and Digital Color Meter 217 points of the 1402-point column.
After a Miri restart, all three sat at the same left edge with 8-point gaps.
Quitting Calculator emptied `tile-overrides.json`.
These checks ran before the last engine review fixes, which tests cover.
[#101](https://github.com/samanyudas/miri/issues/101) tracks a false minimum height that a resizable window records when it refuses a small shrink at the bottom of the screen.

### Refused width after a display move

This branch pins engine `f9c4837`, the merge of [engine PR #54](https://github.com/samanyudas/paneru/pull/54).
A window moved to a narrower display gets a width scaled by the two displays' widths, and the strip scrolls for that width.
A window that refuses the narrower width keeps its own, and the strip now scrolls again so the focused window stays on the display.

On 26 October, `main` at `9bfa927` left two moved windows partly past the right edge of the 2048-point built-in display until the next focus change.
A window with an 1100-point minimum width was asked for 886 points and kept 1108, so 214 points stayed off the display.
A fixed-size 600-point window tiled with ⌃⌥T was asked for 486 points and kept 608, so 114 points stayed off the display.
With engine `4216682`, which has the same files as `f9c4837`, both windows ended at x=2323, inside the display.
These are automated observations with synthetic key presses, not physical input.

## False minimum height at the screen bottom

This branch pins engine `8639fdb` for [#101](https://github.com/samanyudas/miri/issues/101), which merges [engine PR #48](https://github.com/samanyudas/paneru/pull/48).
macOS ignores a small shrink that leaves a window's bottom edge near the bottom of the screen.
The engine took such a kept height as the window's minimum, so a window stacked under it overlapped.
The size check now lowers the window and grows it back once, and only a height the window keeps after that counts as its minimum.

On 26 October, Font Book was resized through Accessibility to end at the screen's bottom edge, and Miri was restarted.
The previous engine logged that Font Book and T3 Code kept 1410 and 1418 points when asked for 1402, and recorded those heights as minimums.
The candidate engine brought both to the asked height with no refusal logged.
A window on another macOS Space, which Accessibility does not list, still keeps its height.

## Bracket directions for stack shortcuts

[#92](https://github.com/samanyudas/miri/issues/92) is implemented on this branch.
An opening bracket now means left and a closing bracket means right for joining and popping out.
⌃⌥[ joins the column on the left, and ⌃⌥] joins the column on the right.
The pop-out shortcuts already followed this rule and did not change.
Default-set version 3 moves an upgraded file's join bindings only while they keep the exact value Miri wrote and the new chord is free.
A blocked move keeps the old chord, and the Shortcuts settings page reports it.
The engine's default configuration has an empty `[bindings]` table, so it adds no bracket bindings of its own.

On 26 October, the running pre-change build from the PR #76 worktree reproduced the old direction: ⌃⌥[ joined the middle test window into the column on its right.
The branch build then upgraded Sam's real version 2 configuration: only the version and the two join lines changed, after a byte-identical backup.
On three throwaway Helium windows, synthetic key events showed each join and pop-out direction, a join from inside a stack, a repeated join, and no-ops at both strip edges and for a pop-out outside a stack.
Focus stayed on the moved window, and all three windows stayed visible.
A fresh install wrote the new defaults at version 3.
A customized version 2 file kept both join bindings, and Settings showed the kept-chord notice and the actual chords.
These are synthetic key events in the real app, not physical key presses.
Sam's configuration and the previously running build were restored byte-for-byte afterward.
Private local evidence is in `/tmp/miri92/`.

## Drag target and empty display fixes

This branch pins engine `4ba2bf0`, which merges [engine PR #39](https://github.com/samanyudas/paneru/pull/39) for [#72](https://github.com/samanyudas/miri/issues/72) and [engine PR #40](https://github.com/samanyudas/paneru/pull/40) for [#73](https://github.com/samanyudas/miri/issues/73).
Engine PR #39 implements the drag rule in [release scope](decisions/release-scope.md#dragging-windows).
Engine PR #40 implements the expected result in #73, which keeps focus where it is.
Each change has tests that fail without it, and Sol approved both.
Live on Miri Developer on 26 October, a stacked Finder window grabbed at the right end of its top bar and dragged straight down showed the bottom insertion line and reordered the stack.
Closing three Finder windows that filled the primary display, with focus on the built-in display, left Grok Bot and Ghostty in view and focus unchanged.
On 27 October, [engine PR #66](https://github.com/samanyudas/paneru/pull/66) added the missing #72 tests: a stack member grabbed near its left edge, and an edge hold that follows the pointer when the window is grabbed off-centre.
Each new test fails when its rule is broken.
On 27 October, Sam's real-mouse check passed the left-edge grab.
Sam's right-edge grab dragged straight down moved the window to the built-in display, because that display sits directly below the primary display and the pointer crossed onto it.
The same day, an agent ran synthetic drags with two Finder windows on Miri Developer built from engine `3fee523`, with the primary display above the built-in display:

- A right-edge grab and a left-edge grab, each released over the lower window of its own stack on the primary display, showed the bottom insertion line and reordered the stack.
- A right-edge grab dragged past the primary display's bottom edge became a new column on the built-in display.
- A drag from the built-in display into a primary-display column showed one insertion line, on the primary display only, and joined that column.

Synthetic drags do not replace Sam's real-mouse check (#71).
Later on 27 October, Sam's real-mouse right-edge grab, released over the lower window of its own stack on the primary display, reordered the stack.
Sam ran every real-mouse check on Miri Developer built from `main` at `7bbecc5` with engine `3fee523`.
The faint white insertion line over white windows belongs to [#86](https://github.com/samanyudas/miri/issues/86).
#72 can close after this PR merges, because the engine tests for the left-edge grab and the edge hold land with it.
[#74](https://github.com/samanyudas/miri/issues/74) tracks engine `window_writes` tests that fail under heavy machine load.

## Unknown-key configuration warnings

The remaining [#26](https://github.com/samanyudas/miri/issues/26) warning gap is implemented on this branch.
Miri validates binding names with the same keyboard-layout resolver it uses for recorded shortcuts.
Unknown characters now produce the existing configuration error in Settings and the menu bar, and Miri leaves the invalid file unchanged.
Valid US, German, and French layout characters remain accepted.
The resolver compares UTF-8 bytes to match Rust, so a decomposed Unicode spelling does not match a composed character by mistake.
This extends Sam's original engine and app repair in [PR #27](https://github.com/samanyudas/miri/pull/27), without changing its engine pin or commits.

On 26 October, the signed current-source baseline reproduced the missing Settings warning for `ctrl+alt-?`, while engine `03a7420` logged `invalid key '?'`.
The candidate showed the warning and preserved the invalid file byte-for-byte.
Replacing it with the supported `ctrl+alt-=` cleared the warning.
Sam manually confirmed the candidate's menu-bar configuration-error message.
The original configuration was restored byte-for-byte after testing.
These are automated native Settings observations and a manual menu-bar observation, not a fresh physical keyboard test.
The issue retains Sam's earlier physical named-typo confirmation.
Private local evidence is in `/tmp/miri26-evidence/` and the check logs in `/tmp/miri26-*.log`.
Sol approved the final behavior in two GPT-6.1 Sol rounds on high effort.
Its one Unicode finding is fixed, with a failing regression before its repair.
All 148 final Swift tests pass.
The full `make check` passed, including strict lint, 41 library and 803 engine tests, granted permission observation, native fixture recovery, and DMG packaging.
After the one-line Unicode repair, the final Swift lint, signed build, granted permission observation, native fixture recovery, and DMG packaging passed again.
The final signed app also showed the `?` warning and preserved the invalid configuration byte-for-byte, then the original configuration was restored.
A fresh synthetic keyboard probe was inconclusive because Computer Use and the engine reported different focused windows.
It is not additional physical-key evidence.
The issue stays open until the landed revision passes its acceptance checks.

## macOS tile restoration fixes

Engine `03a7420` merges [engine PR #38](https://github.com/samanyudas/paneru/pull/38) for [#58](https://github.com/samanyudas/miri/issues/58) on top of engine PRs #36 and #37.
When the engine detects a same-display fill or tile, a window dragged onto the menu bar or a screen edge returns to its column from before the drag, with its own size and focus.
The engine undoes its own drop when macOS tiles the dropped window within one second.
It also restores a fill that macOS finishes after the restore or puts back after the hold, and it matches move and resize notifications that name no window ID, which Helium sends often.
Each change has a regression test that fails without it.
Live on Miri Developer with Helium, the old engine moved the window to a new column after an edge tile 3 of 3 times and kept the fill size in 3 of 3 fills; the fix passed 32 of 32 mixed tries.
A drag that macOS does not fill can still leave the window 8 points up against the menu bar, which is a separate, older defect.
A drop onto another display that macOS then tiles is not undone.

## Stack resize and engine restart fixes

This pin also brings engine `c2d7d38`, which merges [engine PR #36](https://github.com/samanyudas/paneru/pull/36) and [engine PR #37](https://github.com/samanyudas/paneru/pull/37).
They fix five #40 defects that a live rerun on 25 October reproduced on `4890749`.
Engine PR #36 keeps a height step off windows outside the step, keeps an even split beside a learned minimum, and lets a grow step pass a neighbour at its minimum.
Engine PR #37 keeps windows on a hidden native Space managed after a restart, keeps each window on its strip's display at exit, and shows every display's restored strip inside the display padding.
Each defect has a regression test that fails without its fix.
The live rerun on Miri Developer passed every case on the built-in display with Helium, T3 Code and Ghostty, and three Restart Engine runs restored all windows that the scan reached.
Evidence is in `/tmp/miri-e2e-20261025/` on Sam's Mac and is not published.

Two gaps remained open.
[#68](https://github.com/samanyudas/miri/issues/68) is now fixed on `main` through engine `23bcf1b`.
[#69](https://github.com/samanyudas/miri/issues/69): restore does not keep a strip's scroll offset, so a strip whose focus moved starts at its first column after a restart.

## Stack sizing and order fixes

[Engine PR #34](https://github.com/samanyudas/paneru/pull/34) merged as `e4137a4` and fixes the #42 mixed-app ordering.
`AXRaise` puts a background app's window just below the frontmost app's focused window, so `raise_in_order` now checks each raise against earlier entries only and puts the focused window back in front after a raise of another frontmost-app window.
[Engine PR #35](https://github.com/samanyudas/paneru/pull/35) merged as `4890749` and fixes the #40 fresh-window overlap.
The size check read a Chromium-style late resize as the old full height and stored it as a minimum, so a window still taller than requested is now read again after 500 ms first.
An app that applies a size more than 500 ms late can still have its old height learned.
Each PR has a regression test that fails without its fix.
Both pass 52 library and 878 binary tests with defaults, 41 and 788 without, strict Clippy, and rustfmt.
Greptile scored both 5/5, and one Sonnet sol-loop round approved both with nits only.

A signed Miri Developer build with candidate engine `07b55ae`, both fixes on `896d887`, ran native fixture checks on 25 October.
The #42 mixed column `A1, B1, A2` passed 13 of 13 order checks, against 9 of 13 on base `896d887`.
The #40 gate fixture showed no stale minimum with a 300 ms delay, a 1000 ms delay, or dropped writes, and the fresh-window repro passed 3 of 3 runs.
Evidence is in `.audit/fullsend-stacks-20261025/`.
Sam's trial build was restored afterwards.
Two of Sam's windows, Spotify and a wide Helium window, ended in a virtual workspace that the restored trial engine does not show, so it parks them at the corner.

This branch pins `4890749`, which also brings in engine PR #30, `896d887`, the per-app background window writes.
The merged engine's non-test source is identical to the natively tested candidate `07b55ae`.
Only the test mock differs.
The sol-loop nit commit for #34, a variable rename and two comment changes, missed the merge and is still pending.
On 25 October, `make check` passed with the pin: 144 Swift tests, 41 library and 789 engine tests, strict lint, the signed build, `observed-granted` permission observation, fixture recovery, and DMG packaging.

## Native issue verification

PR #65 is merged, and agents now verify and close issues without a release wait.
The 24 October native audit used a fresh signed build from the tree-identical `34f2f6d` head and the published engine pin `f831216`.
It confirmed [#39](https://github.com/samanyudas/miri/issues/39), [#44](https://github.com/samanyudas/miri/issues/44), and the bounded retry in [#48](https://github.com/samanyudas/miri/issues/48).
Their issue comments record the native observations, passing regression tests, and limits.
[#26](https://github.com/samanyudas/miri/issues/26) was reopened because a native check confirmed the missing Settings error for an unresolved single-character binding.
The earlier named-typo repair still works.

The mature-window lane for [#40](https://github.com/samanyudas/miri/issues/40) passed equal splitting, minimum-height redistribution, retained manual sizing, and membership removal.
The fresh-window lane failed, so #40 stays open for triage.
[#33](https://github.com/samanyudas/miri/issues/33) and [#58](https://github.com/samanyudas/miri/issues/58) reproduced their app-death and height-restoration failures.
One busy-launch cohort admitted all 18 windows, which does not clear the intermittent discovery defects in [#59](https://github.com/samanyudas/miri/issues/59) and [#63](https://github.com/samanyudas/miri/issues/63).
The remaining keyboard, gesture, overflow-ordering, and drag criteria still belong to their open issues.
No release-candidate acceptance row was passed by this audit.

All test apps and engines exited, the original Miri support folder was restored byte-for-byte, and existing user-window frames were unchanged.
The private local evidence is in `.audit/native-issue-verification-20261024/`.
It includes unrelated window titles in baseline captures and must not be published wholesale.
Only sanitized observations were posted to GitHub.
No product source or engine pin changed.
A manual checklist is prepared in `.audit/native-issue-verification-20261024/manual-checklist.md` for Sam's combined hardware results.
It covers seven open-issue scenarios and four optional physical checks for closed issues.
The confirmed code gaps in #26, #31, and #33 need no repeated manual reproduction.

Sam's follow-up reports a pass for #35, correcting an initial reference to #33.
His #40 observations match adjacent-pair height resizing, equalization after removal, and horizontal row selection with the destination's last row as a fallback.
Those observations do not resolve the earlier fresh-window failure, so #40 remains open.
Overlap is expected only when the windows' minimum heights cannot fit, under #42's top-bar and focus-ordering rules.
The supplied #42 recording shows wallpaper and a cursor without application windows, so it cannot verify those rules.
No issue was closed from this follow-up.

The autonomous follow-up used the same signed merged-build artifact and engine `f831216` in `.audit/stack-repro-20261024/`.
Fresh flexible and constrained #40 cases passed with animations enabled and disabled.
Five flexible native fixture windows also split without overlap, and removing a constrained sixth member restored their equal shares.
The earlier fresh-window failure remains unexplained, so #40 stays open.

The #42 mixed-app column `A1, B1, A2` reproduced the wrong native order on every return to A2 in three focus walks.
Five paired trials then changed the wrong order `A2, A1, B1` to `A2, B1, A1` with a direct native raise of B1.
A2 remained the focused/frontmost window at both endpoints.
The source-derived explanation is the overly broad exclusion of frontmost-app windows in `raise_in_order`, which skips B1's raise.
The native counterexample disproves an unavoidable platform limit for this fixture case, but it does not directly trace that engine branch.
Independent review excluded the distinct-app comparison because its third window was on another display.
No product fix was applied, and #42 stays open.
The previous trial build at engine `5daaa0f` and its original configuration were restored after testing.
On reload, the trial app removes the derived `swipe.gesture.fingers_count` entry, while the original user-facing settings remain unchanged.
Final verification found no changed existing window frames.
The independently reviewed observations are posted on [#40](https://github.com/samanyudas/miri/issues/40#issuecomment-6384818919) and [#42](https://github.com/samanyudas/miri/issues/42#issuecomment-6384816787).

## Stack ordering and window admission repairs

[Engine PR #32](https://github.com/samanyudas/paneru/pull/32) merged into `miri/v0.5.2` as `50f49fc` for #42.
It keeps an overlapping stack of windows from different apps in order after focus changes.
`AXRaise` returns before a background app reorders its window, and it places that window just below the frontmost app's windows.
The engine now raises only windows that need to move, waits up to 50 ms for each raise to show, and waits up to 500 ms for the focused window to show in front.
Native focus walks with four fixture apps failed 7 of 12 steps on `9ac7ec7` and passed 96 of 96 on the fix.
While Finder is frontmost with no window, the previously focused stack window can remain in front instead of returning to its overlapped place.
The bounded focus-first experiment on 24 October used four native fixture apps and returned focus to Finder after activating each app in stack order.
The captured run left the wrong order without pauses and restored D1, C1, B1, A1 with 50 ms and 150 ms pauses.
The helper at `/tmp/miri-42/ff.swift` sets `AXFrontmost` for each app and then Finder.
It does not issue a separate `AXRaise`, so this records activation with the running engine rather than an isolated focus-and-raise implementation.
The workaround would take focus from Finder while cycling through the apps.
No engine change is included, and the Finder limitation is recorded in [release scope](decisions/release-scope.md#stacks).
Sam limited this investigation to one workaround attempt, so it ends here.
These results come from the prior session's captured output, not a fresh native run.
Two windows of one app with another app's window between them still cannot be fully ordered.

[Engine PR #33](https://github.com/samanyudas/paneru/pull/33) merged as `f831216` for #59.
macOS can announce a launch before `NSRunningApplication` knows the process, and the engine now looks it up again instead of dropping the process after 5 s.
An app that shows no window within 10 s now stays managed, so a later window enters the layout.
The float command now toggles a window only when macOS reports it focused in the frontmost app.
Native launch probes missed none of 320 ordinary windows, a window shown 12 s after launch was managed after 13 s, and the float key ignored an unmanaged focused window.
An app whose observers cannot register for 5 s is still dropped, and an app that keeps its main thread blocked can wait for a later event.

Both engine PRs passed two Sol rounds and scored 5/5 in Greptile.
This branch pins `f831216`.

## Previous acceptance repairs

[Engine PR #31](https://github.com/samanyudas/paneru/pull/31) merged into `miri/v0.5.2` as `9ac7ec7ef6bd4ecd60bca4019e40a22730b25cf5`.
[Miri PR #61](https://github.com/samanyudas/miri/pull/61) merged as `3898f6fd8e3f27bc6b4f7eab0a3e43d43c2797a9` and pins this published revision.
It keeps size-refusing stack windows on the display where the engine placed them.
It also exposes the eligible focused survivor after removal and preserves focus when a background window is destroyed.
The visibility request waits for scrolling or drag placement to finish and then checks the current focus.
Keyboard focus placement and workspace restoration retain control.
[Issue #60](https://github.com/samanyudas/miri/issues/60) tracks the close and visibility failure.

Sol approved the source and tests after five bounded review rounds.
Greptile reviewed the final engine revision at 5/5, and both PR checks passed.
Independent native verification returned PASS+NOTES on engine `1cbb987` before its tree-identical squash merge.
The verifier reproduced BASE moving a constrained window to the built-in display, stealing focus after background close, and leaving a focused survivor at x=-32.
The candidate retained the external display and focus, and corrected the survivor to x=8.
Native AX close, SIGTERM, graceful quit, and synthetic modifier-scroll checks passed within their recorded scope.
Physical touchpad behavior and exact native swipe timing remain unverified.
The engine passes 41 library and 759 binary tests without defaults, and 52 library and 849 binary tests with defaults.
Formatting and strict Clippy pass in both configurations.
Miri's full `make check` passes with the published pin.
This includes compatibility, 144 Swift tests, 41 library and 759 engine tests, strict lint, the signed build, permission observation, window recovery, and DMG packaging.
Sol approved the three-file Miri integration and verified parser compatibility and the minimum-height wording.
Independent verification of the final Miri artifact returned PASS+NOTES on `1fcfa57`, whose tree matches the merged revision.
The signed app and read-only DMG match completely, and fresh native closes preserve focus and final visibility.
All integration PR checks passed before merging.
Both PR watchers are stopped, and the verified app remains running with one engine child.
The DMG inspection left a nonblocking installation prompt that computer use could not inspect because it timed out.
No installation occurred.

The macOS tiling setup check already merged in [PR #57](https://github.com/samanyudas/miri/pull/57) as `601b056`.
The keybinding reference now distinguishes a 200-point layout slot from its 192-point native window with default gaps.
The overlap-order retry prototype failed 6 of 12 native focus steps and was removed from the shipping diff.
Overlap ordering and the documented stack-focus switch remain unresolved under #42.
[Issue #59](https://github.com/samanyudas/miri/issues/59) tracks intermittent window discovery and remains unfixed.
[Issue #58](https://github.com/samanyudas/miri/issues/58) separately tracks macOS tile height.
These changes do not complete frozen-release acceptance.
The evidence and decision trail remain in `.audit/acceptance-pickup/` in the repair worktree.

## Done

- `chore/agent-owned-issue-closure` removes the GitHub Actions issue lifecycle and its dedicated harness tests and fixtures.
  Agents verify every acceptance criterion on landed code, post evidence, and close completed issues under the [issue lifecycle](CONTRIBUTING.md#issue-lifecycle).
  Partial or unverified issues remain open, and release distribution acceptance stays separate.
  The lifecycle notes below are historical evidence for the retired automation.
  No live issue or label was changed.
- `branding/window-mark` replaces the README's pink M logo with the blue and violet window mark.
  `assets/` also contains running and stopped menu bar SVGs and usage notes.
  SVG parsing and a browser preview passed for all three assets, including the menu bar marks on light and dark backgrounds.
  `make lint` passed on current `main` plus these assets, including all 18 harness tests.
  `make native` was skipped because this change contains only SVG assets and documentation.
  The native app does not yet load these assets, and the Paper UI screens remain unexported because Paper Desktop was closed.
- The v1 specification and product decisions are merged (#3).
- The Accessibility permission prototype is merged (#4).
  Enabling only the Miri entry authorizes both the app and its engine in the development build.
- The development harness is merged (#10), tracked by #9.
- PR #11, the Miri Developer identity, merged into `chore/repo-harness` after #10 had already merged that branch.
  Its commits never reached `main`, so `feat/v1-app-core` carries them.
- `feat/v1-app-core` adds the first production app slice:
  - `MiriCore`, a tested library with a TOML 1.0 parser that edits single values without touching the rest of the file.
  - Miri-owned `config.toml` with the accepted defaults and derived engine keys for gaps, presets, animation, and floating Settings.
  - An engine supervisor with an isolated environment, bounded logs, and a three-crashes-in-five-minutes restart limit.
  - App-side window recovery after every engine exit, verified live against the fixture window.
  - A setup checker, redacted diagnostics with a preview, and the menu bar and Settings UI.
- The engine fork change samanyudas/paneru#5 hides the engine's menu bar item through `[decorations.menu].visible`, which Miri sets to `false`.
  It also creates a missing `PANERU_CONFIG` file in place instead of falling back to standalone Paneru's files.
- The engine fork change samanyudas/paneru#6 makes stacking move only the focused window, in both directions, and adds pop-out to the left.
  It also stops a stack command next to a fullscreen column from dropping windows out of the layout.
- Sam decided on 15 October 2026 that stacking moves only the focused window, and deferred Q6 to the final pre-release check.
- PR #12, the first production app slice, merged into `main` on 15 October 2026 with #13 still open.
- samanyudas/paneru#7 merged into `miri/v0.5.2` on 16 October 2026 as engine `0341353`.
  It fixes #14: Stop and Quit no longer move floating, minimized, or hidden windows.
- Sam decided on 16 October 2026 that a current floating rule wins over a saved tiled placement (#15).
  samanyudas/paneru#8 merged into `miri/v0.5.2` on 16 October 2026 as engine `39def42`, which does this.
  A live run on the built-in display confirmed that a floating rule now wins after a restart.
- The issue lifecycle job that labels issues a merged PR references failed with HTTP 403 on every merge until #18.
  Its token lacked `pull-requests: read`. A harness test now checks each workflow job's scopes against its API calls.
- The release, timed-close, and reopen stages of the issue lifecycle have not run live, because no stable release exists.
  A harness test runs their real job scripts against a fake `gh`.
  A dispatched run of the close job passed on `main` on 16 October 2026.
  No issue carried `please confirm close`, so that run proved only that the job starts with its permissions and its script parses.
- On 16 October 2026, `make check` passed on `main`, and a live headless Claude session showed the guard block a push to `main`, a force push, a PR merge, a release, `tccutil reset`, and `defaults write`.
- #13 shrank a window in 1 of 35 runs, across the built-in display and a 2560 x 1440 external display.
  The engine requested only height changes in every run.
  After a screen lock, three windows were at exactly half width, and no engine had run since their last check.
  macOS tiling is the main suspect, but Sam may have moved them, so this is not confirmed.
  #13 was closed as completed on 16 October 2026 after these runs.
- `feat/default-bindings` writes the accepted default shortcuts to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
  A new install gets the full set.
  An existing file gets each default whose engine command it does not bind under any alias, with only the default's free chords.
  `[miri].default_bindings_version` records the offer, so Miri never re-adds a binding the user deleted.
  A live run on 16 October 2026 sent all 43 bound chords as synthetic key events, and the engine ran each command.
  The engine's behavior differed from the accepted behavior only where the engine mapping records it, such as a numbered jump into a stacked column focusing the top window instead of the last-focused one.
  Some actions stay unbound or behave differently, as the [engine mapping](decisions/keybinding%20reference.md#engine-mapping) records.
- PR #27 merged into `main` on 18 October 2026 and pins engine `3455e37` on `miri/v0.5.2`, the squash merge of samanyudas/paneru#11, which follows samanyudas/paneru#9 and #10.
  The engine adds five-percentage-point resize steps (#22), directional display focus and move (#23), and column jumps that return to a stack's last-focused window (#24).
  It drops a binding whose key name it does not know, instead of binding the A key (#26).
  Vertical focus and swap no longer cross to another display at a column's edge.
  Display focus preserves the selected virtual workspace and skips background native tabs.
  The Lua display commands reject positional directions.
  The merge also brought window-recovery fixes that preserve window state and geometry when an Accessibility handle is replaced.
  Miri's default set is now version 2. An upgrade replaces the four version 1 resize bindings only where they still have Miri's value.
  Miri reports a binding the engine cannot read, and owns ⌃⌥Q for Stop (#25).
  On 16 October 2026 the built app upgraded Sam's real version 1 file as designed, and the engine parsed all 51 bindings in it.
- samanyudas/paneru#10, merged as `0010611`, fixes a Rust 1.98.1 Clippy `float_cmp` error that `67debbc` introduced in a recovery test.
  On 17 October 2026, `make lint`, Swift lint, 69 Swift tests, the app build, and both end-to-end checks passed at `67debbc`, which has the same source apart from that test.
- A live run on 15 October 2026 on the built-in display only confirmed Start, 8-point gaps on all sides and between windows, Stop, crash recovery and restart, the three-crash limit, manual restart, and Quit.
- A 16 October 2026 hardware run of the PR #9 engine used an external 2560 x 1440 monitor above the built-in display.
  Sam confirmed horizontal growth and the South move, North focus, and South focus shortcuts.
  The recorder saw Fixture 0 move between displays and grow from 500 to 756 points, which matches two 128-point steps.
  Sam paused the run before the East and West check, which PR #27 later completed.
  Evidence is in `.build/artifacts/pr9-hardware-evidence/`.
  Fixture test helpers remain in `.build/artifacts/pr9-hardware-runtime/` and are reusable for native checks.
- PR #27 also fixes default upgrades, exact configuration backups, and Stop ownership for usable and rejected engine bindings.
  Its description records the full verification, and the append-only decision trail is `.audit/pr27-full-stop-20261017.tsv`.
  Sam physically confirmed width spacing, stacked-height growth, stack jump returns, ordinary Stop, Stop after a rejected reload, and the mistyped-key check.
  Sam physically confirmed all four horizontal and all four vertical display actions at engine `6e572ea`, whose tree matches `3455e37`.
  The horizontal check had the laptop left of the external monitor with top edges aligned.
  The vertical check had the external monitor above the laptop with left edges aligned.
  Both physical checks used fixture animation speed `1000`, and separate native replays passed at speed `14` with Fixture 0 and TextEdit.
  The confirmations are `.audit/pr27-hardware/horizontal-6e572ea-confirmation.json` and `.audit/pr27-hardware/vertical-6e572ea-confirmation.json`.
- PR #29 pins engine `a15682f`, the merge of samanyudas/paneru#12, which fixes #28.
  The engine now builds a native frame from its rounded origin and size, so odd widths and heights stay exact.
  A native gap check on 18 October 2026 used four fixture windows with 4-point window and edge padding, then resized the leftmost window to 629 points.
  Engine `3455e37` recorded width 636, and the native gap to its neighbour was 7 points.
  Engine `a15682f` recorded native X=8 and width 629 as x=4 and width 637, and every native gap stayed 8 points.

- `feat/shortcut-settings` adds the Shortcuts settings page.
  It records a chord through an event tap at the head of the HID event stream, so it also sees chords the engine binds.
  Each action lists several chords, and each chord has its own remove button.
  The page rejects a chord that another Miri action, Stop, or an unlisted engine command already uses, and the file stays unchanged.
  It warns before it takes a shortcut that macOS uses.
  That list is the live System Settings shortcuts merged over built-in defaults, plus standard app shortcuts.
  Reset to Defaults backs up the file, replaces `[bindings]` with the default set, and restores ⌃⌥Q for Stop.
  Stop is customizable in `[miri].stop_shortcut`.
  When the keyboard layout changes, Miri registers Stop again and restarts a running engine, because the engine reads the layout only when it starts.
  A default-binding upgrade never takes a chord that presses the same key as a Stop chord or a user binding under the active layout.
  Key names resolve through the active layout in the engine's order, so AZERTY, QWERTZ, and Dvorak record the key the engine binds.
  Unit tests pin key names and round trips on the US, French, German, and Dvorak layouts.
  On 18 October 2026 a built app ran with management stopped and a temporary home folder.
  Synthetic HID key events showed the rejection messages, the macOS conflict alert, adding a Stop chord, and the unusable-key message.
  They also showed that Escape and switching apps cancel recording, and that reset writes a backup.
  A second run on 18 October 2026 used the same temporary home folder with the engine running.
  While recording, the page caught ⌃⌥T and showed "⌃⌥T is already used by Float or unfloat focused window.", and the engine did not act.
  A recorded Stop chord, ⌃⌥⇧P, stopped management when pressed.
  With French, German, and Dvorak each selected, the recorder wrote `ctrl+alt+shift-a`, `-q`, and `-'` for the key at the US Q position.
  A freshly started engine ran each recorded binding.
  With the engine running, switching to French and back to Australian restarted the engine each time, with process IDs 5840, 6259, and 6268.
  On AZERTY the default digit shortcuts, such as ⌃⌥1, reached the keypad digits, because the top row types symbols without Shift.
  [#31](https://github.com/samanyudas/miri/issues/31) later moved them to the top row.
  GPT-6.1 Sol reviewed the branch in four rounds and approved it after the layout restart and the upgrade fixes.
- `feat/gesture-controls` is phase 3a, the strip gesture controls without pointer-versus-focus targeting.
  Settings has a Gestures tab with Off, Three fingers, and Four fingers (recommended), and Reverse swipe direction.
  `[miri].strip_gesture` defaults to Off, and `[miri].reverse_swipe` sets `[swipe.gesture].direction`.
  `GestureState.evaluate` turns the swipe on only for a confirmed user test that matches the finger count, direction, macOS version, engine revision, and readable macOS gesture settings.
  A confirmed macOS conflict always keeps it off, and automatic detection never turns it on.
  Miri writes `[swipe.gesture].fingers_count` only while the swipe is on or a test runs, sets `vertical = false`, and removes the legacy `[options]` swipe keys.
  The gesture test polls `miri-engine query state --json`, needs the strip to slide both ways, fails on a Space switch, and saves a result only after the user confirms it.
  The result lives in user defaults, and Report a macOS Gesture Change deletes it.
  Unit tests cover the state table, the file keys, the result's JSON, and the movement detector.
  Changing the finger count, direction, macOS version, engine revision, or a readable macOS gesture setting deletes the saved result, even while the swipe is Off, so changing back needs a new test.
  The four-finger setup check no longer reports a conflict when macOS keeps the four-finger value at 2 while full-screen swiping uses three fingers, as on Sam's Mac on 18 October 2026.
  On 18 October 2026 the built app showed the Gestures tab on screen with the swipe Off by default and both test buttons disabled, and its config had `direction = "Natural"`, `vertical = false`, and no `fingers_count`.
  No live trackpad check has run.
  GPT-6.1 Sol reviewed the branch in three rounds and approved it.
  [#33](https://github.com/samanyudas/miri/issues/33) tracks the engine helper outliving a dead app, which would keep a test swipe active until the next launch.

- PR #37 records the strip settling design, and PR #41 pins engine `491508e`, which implements it.
  A swipe settles on the column nearest the center where the flick would stop, and focus reveals only the hidden part of a column.
  The engine also keeps a column's anchor during preset width cycling (#39), and Quit and Stop return windows to their frames from before Miri started.
  A live check on Sam's Mac started and quit the engine with nine windows open, and all nine returned to their starting frames.
  No real trackpad check of settling has run.
- PR #45 records the stack rules Sam accepted on 19 October 2026 in [release scope](decisions/release-scope.md#stacks).
  PR #46 pins engine `579bc0b`, which gives stacked windows equal heights and stops a window with a minimum height from overlapping the next one (#40).
- PR #47 makes CI tolerate the `open -W` race in both selftests and retries `hdiutil` in DMG packaging.
- PR #50 pins engine `4b4705a`, which asks a slow app for focus again before it floats the window (#48).
- On 20 October 2026 a status audit compared `main` at `e516edd` with the v1 documentation.
  Sam settled the open #42, #43, and #44 questions on 20 October 2026, and the branch `docs/drag-and-overflow-decisions` records them in [release scope](decisions/release-scope.md#dragging-windows).
  Dragging to reorder columns and dragging between displays moved into v1.
  The branch `docs/reconcile-audit-20261020` corrects the stale status claims, adds the [acceptance ledger](docs/acceptance-ledger.md), and updates #42, #43, and #44.
- PRs #51 and #52 changed only documents, but each listed `Refs #42`, `Refs #43`, and `Refs #44`, so the issue lifecycle labelled all three `fixed (pending release)`.
  The labels were removed on 20 October 2026, and one wrong bot comment remains on each issue.
  `fix/refs-vs-part-of` adds `Part of #N` for decisions, docs, and partial work, which never labels an issue, and stops `Related to #N` from labelling one.
  A harness test reproduced the `Related to` labelling before the change and passes after it.
- `feat/stack-overflow` pins engine `db5bba3`, the merge of samanyudas/paneru#21, which implements stack overflow (#42).
  When a stack's minimum heights exceed its column, each lower window overlaps the window above it only below that window's top bar.
  The engine measures each top bar through Accessibility when a stack first overlaps, and again when the window loses focus or resizes.
  A window with no measurable top bar gets 52 points.
  When any Accessibility read fails, the engine keeps the last measured height, or 52 points if it has none, and tries again after a growing wait.
  The focused window comes to the front, and it returns to its place when focus leaves it.
  The engine also lays out a stack with more windows than fit at the 200-point minimum, which it used to leave out of the layout.
  Engine unit and harness tests cover the overlap, the fallback, the refresh and retry, the spill past the bottom, the window order, and the dropped column.
  A read-only Accessibility probe measured a 96-point top bar on Helium, the only app with a standard window open.
  No real desktop or hardware check has run, so acceptance check S-5 stays pending.
- `feat/stack-limit` delivers the stack limit (#44) with samanyudas/paneru#20, which adds the engine option `[options].stack_limit`.
  It holds a whole number from 1 or `"fit"`, defaults to `5`, and is capped at what fits in the column at 200 points on the active display.
  A Stack command into a full column moves the window out of its own stack into a new column between the two.
  A window that is already its own column stays put.
  Lowering the limit leaves existing stacks unchanged, and the engine reads the limit on every Stack command, so a hot reload applies to the next one.
  The engine rejects `0`, negative numbers, and other values with a parse error, and so does Miri, which reports `options.stack_limit`.
  `effective_stack_limit(config, column_height)` in the engine's `src/ecs/layout.rs` holds the cap, for reuse by drag insertion (#43).
  Settings has a Windows per stack picker on the Layout page, with Fit the display and the numbers from 1 to what fits on the main display.
  PR #54 pinned engine `9065569`, the merge of samanyudas/paneru#20 into `miri/v0.5.2`.
  On 20 October 2026, `make native` passed on `feat/stack-limit` with 141 Swift tests, 40 engine library tests, and 427 engine binary tests.
  Its permission selftest reported `observed-granted. Attribution unresolved.`, and its recovery selftest recovered the fixture window.
  Before the engine merge, `make lint` passed except `make compat`, which rejected the unpublished pin.
  Settings was not opened during that run.
  No hardware check has run, and the acceptance check is S-7 in the [acceptance ledger](docs/acceptance-ledger.md).
- PR #54 merged into `main` as `6a85fcf` on 21 October 2026 after Greptile scored its final head `87178e9` at 5/5 and CI passed.
  Independent verification passed 142 Swift tests, strict Swift lint, and `make lint`, including 19 harness tests and compatibility.
  A native fixture rendered the production Layout settings view with an isolated model and configuration file.
  The previous commit kept a stale capacity of 6 after a simulated display notification, while the merged view immediately showed 3 and preserved the configured count of 5.
  This did not change physical displays or run the engine.
  This branch merges that result and keeps engine `db5bba3`, which contains both stack limit and stack overflow.


- `feat/drag-insert-integration` starts from `main` at `49661a5` and pins engine merge `ffff464` from [samanyudas/paneru#29](https://github.com/samanyudas/paneru/pull/29), merged into `miri/v0.5.2` on 23 October 2026.
  This brings in the landed drag insertion and feedback changes from engine PRs #22, #23, and #28, together with part C from #29.
  Part C adds cross-display drops, outer-edge hold scrolling, and restoration after macOS tiles a managed window (#43).
  Native membership uses fresh window frames and preserves held drags, pending engine placement, and native tab groups.
  The engine also replays a held tab group's skipped layout when a press ends without a drop.
  The regression failed before the fix for lost release, pointer movement, and resize cancellation, and passes after the fix.
  The app also recognizes the engine's `showmenu` and `hidemenu` binding keys and rejects extra words, matching the updated engine parser.
  The compatibility guard still requires the engine pin to be published on `miri/v0.5.2`.
  The verified merge satisfies that ancestry requirement.
  Mock engine tests cover the drag behavior, including a neighboring display with a native fullscreen Space.
  Standalone engine `ee94515` passes all thirteen final native fixture lanes on two physical displays on 23 October 2026.
  These include both keyboard-resize lanes, Window menu Half, Quarter, and Fill, same-display gestures, and nine consecutive cross-display runs.
  Immediate Grow produces width 1920 after an app resize to 1600, replacing the previous wrong 1280.
  Cross-display runs preserve width ratios, equal 643-point stack shares, insertion feedback, refusal, and complete return geometry.
  All fourteen unrelated window frames stay unchanged in every lane, and strict foreground checks pass.
  Every owned process exits and the original frontmost app returns.
  Sam disabled Vorssaint's Focus Follows Mouse setting before these final runs.
  The final runs use the existing engine focus behavior.
  These checks use three owned AppKit windows and Sam-authorized synthetic CGEvent input, with Helium hidden and its session preserved.
  Successful drops now retire earlier native resize snapshots for every native-tab member.
  A fixture-driven native Half-sized resize followed by a drag now keeps its accepted destination.
  Its frame stays at (0,30), 1280 by 705, instead of returning to the earlier slot.
  Sol approved the full engine change after two rounds, with the stale snapshot finding resolved.
  Physical diagonal-edge behavior has source and mock coverage only.
  The integration pins verified merge `ffff464`, whose tree exactly matches the reviewed and natively tested `ee94515`.
  Acceptance check S-6 stays pending.
- `feat/setup-tiling-conflicts` adds the macOS tiling check that Sam decided for drag insertion (#43).
  The setup checker now reports **Drag windows to screen edges to tile**, **Drag windows to menu bar to fill screen**, and **Hold Option key while dragging windows to tile** when they are on.
  macOS stores these values only after a change, so an absent value counts as on, the macOS default.
  The check never blocks window management.
  On 23 October 2026 the built app showed Passed with all three off, and named the two options turned on with `defaults` after Check Again.
  With macOS tiling on, a dragged window that macOS filled or tiled returned to its column origin and width within 0.4 seconds, but kept the macOS height of 1410 points instead of 1394.

## Next

Triage #122, #123, and #124 from the limitations audit.

Each phase lands as its own PR or PRs.
Record every acceptance result in the [acceptance ledger](docs/acceptance-ledger.md).

1. Finish the remaining v1 features.
   - Add pointer-default and focused-strip gesture targeting to the engine, the configuration, and Settings.
   - Complete drag and restoration acceptance for #43.
     The #58 height defect is fixed and closed.
   - Complete stack overflow acceptance (S-5) and repeat the verified stack-limit behavior on the frozen release candidate (S-7).
   - Verify every Strip gestures checklist item and the settling behavior on a real trackpad.
2. Build the public release path, in parallel with phase 1.
   Integrate Sparkle updates, then production signing, notarization, the release DMG, and the Homebrew cask.
   Verify install, upgrade, and Accessibility attribution on the released bundle.
3. Freeze one release candidate, then run the complete app and multi-monitor acceptance checklists on that bundle with Accessibility granted.
4. Define the engine memory-stability rule, complete the endurance period, and have Sam decide Q6 at the final check before publishing v1.
5. Move to Rust 1.99 when the product is ready.
   [Engine PR #3](https://github.com/samanyudas/paneru/pull/3) fixed Rust 1.99's `assert_is_empty` Clippy errors on 14 October, and the engine pin includes it.
   Later engine code adds new `assert!(x.is_empty())` calls, so run Clippy on 1.99 again before the move.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

The app implementation at `540cc57`, with engine `48df35a`, passed strict Swift and engine lint, the signed app and helper build, and 142 Swift tests.
Its engine passed 41 library and 707 binary tests without default features, and 52 library and 794 binary tests with defaults.
The first native target failed recovery while the desktop was locked.
After Sam unlocked the desktop, `make e2e` passed both permission observations and fixture recovery.
Permission attribution remains unresolved.
Those app checks do not verify the newer standalone engine repairs.

On 23 October 2026, standalone engine `ee94515` passes 52 library and 841 binary tests with defaults.
The no-default run passes 41 library and 751 binary tests.
Formatting and strict Clippy pass in both feature configurations.
Sol approves the full engine change in round two, with source and mock evidence kept separate from native results.
All thirteen final native fixture lanes pass under the environment conditions above.
Greptile scored engine `ee94515` and integration `d4102fe` at 5/5.
Engine #29 merged after Sol approved, both bot checks passed, and all review threads were resolved.
Sol approved the merge-commit repin in integration round two, with no findings.

The integration repin to published merge `ffff464` passes `make check` on 23 October 2026.
This includes docs, 19 harness tests, ShellCheck, actionlint, compatibility, strict Swift and engine lint, the signed build, 142 Swift tests, and 41 library plus 751 binary engine tests.
Its native selftests report `observed-granted. Attribution unresolved.` and successful fixture recovery.
DMG creation, verification, mounting, signatures, and the embedded engine revision check also pass.
The parser hashes and publication guard remain unchanged.
The integration remains draft until fresh CI and bot review finish for the repin.

On 24 October 2026, the issue-closure implementation passes `make docs harness-tests actions shell` and `make lint` with engine pin `f831216` unchanged.
The baseline harness passes all 19 tests, and the remaining nine tests pass after removing the retired automation's ten tests.
The tracked-instruction search leaves legacy lifecycle guidance only in historical evidence and the new policy's legacy-label explanation.
`make native` was intentionally skipped for this workflow and documentation change.
Its skipped targets are `make doctor`, `make swift-lint`, `make engine-lint`, `make build`, `make test`, `make e2e`, and `make package`.
`make check` was not run because it includes those native targets.
No native app or desktop operation ran, and no live issue or label changed.
The integrated branch also passes `make lint` and `git diff --check`.
Independent source review approved `743802f` against `b2e6d12` with no findings.
The comment pass found no deletion candidates or refactor flags.
