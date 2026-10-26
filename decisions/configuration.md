# Configuration

Status: Miri settings decisions and proposals.
The [release scope](release-scope.md) and [ADR 0007](../docs/adr/0007-isolate-miri-configuration.md) define the accepted configuration contract.
Implementation and test status lives in [PROGRESS.md](../PROGRESS.md), not in this document.

Expose settings through controls in a native window.
Apply valid changes immediately, without a Save button or restart.
Ordinary setup must not require file editing.
Advanced users can edit `~/Library/Application Support/Miri/config.toml`.

Miri reuses Paneru's TOML key names and stores app-only settings in a `[miri]` section.
Miri passes the configuration path explicitly and leaves standalone Paneru's files untouched.
The app watches the file for external edits.
If the file is invalid or cannot be written, the engine keeps the last valid settings.
Miri shows the error in Settings and the menu bar.
Miri never overwrites a file it could not read correctly.
This is Miri's required isolation contract, not a verified capability of unmodified Paneru.
The [pinned-engine assessment](engine-v0.5.2-assessment.md) identifies standalone configuration fallback and Lua discovery that Miri must prevent.

## Configuration upgrades

Configuration upgrades follow the accepted migration rule in [Release scope](release-scope.md#configuration).
General schema migrations remain engineering work.
Default shortcut upgrades save the original file in `config.toml.backups/` beside `config.toml` before recording a new default version.
Each backup has a unique filename, and a backup failure leaves the configuration file untouched.
The initial default installation also backs up the file before adding its version marker.

## Accepted layout defaults

| Product setting | Miri default | Engine mapping |
| --- | --- | --- |
| Width presets | `[0.25, 0.33, 0.5, 0.66, 0.75]` | `[options].preset_column_widths`, cycled by Control-Option-R. |
| Inner gap | `8` points | `[miri].inner_gap`. Miri writes half of it as per-window padding in `[windows.miri-gaps]`. |
| Outer gap | `8` points | `[miri].outer_gap`. Miri writes it minus the per-window padding to each `[padding]` side. |
| Stack limit | `5` windows | `[options].stack_limit`, a number from 1 or `"fit"`. The engine caps it at what fits on each display. |
| Maximized stacked window opens | Right of its stack | `[options].maximized_window_side`, `"left"` or `"right"`. |

Paneru v0.5.2 has no `gap_inner` or `gap_outer` configuration keys.
Its outer padding has separate top, right, bottom, and left fields.
Its per-window padding contributes on both sides of adjacent windows.
The accepted eight-point gap behavior remains unchanged.
The app implements this mapping, but no one has checked the resulting coordinates on screen.
The app provisionally accepts gaps from 0 to 32 points.
The final Miri validation range is not yet selected.

The preset list is editable.
The fourth width preset is `0.66`.
[Release scope](release-scope.md#default-shortcuts-and-layout) defines the accepted new-window width and resize increment.
Paneru's width rules also apply to existing windows discovered at startup.
The new-window-only width behavior therefore requires integration beyond a blanket width rule.
Paneru's grow and shrink commands select presets instead of applying a fixed increment.
Miri must implement the accepted incremental behavior through its integration.

## Layout behavior and remaining controls

Focus reveal and Dock reservation follow [V1 interactions](release-scope.md#v1-interactions).
The stack limit is an engine option, `[options].stack_limit`, which holds a number from 1 or `"fit"` and defaults to `5`.
Settings writes it, and the engine caps it at what fits on each display.
The side where a maximized stacked window opens is an engine option, `[options].maximized_window_side`, which holds `"left"` or `"right"` and defaults to `"right"`.
Settings writes it as **Maximized stacked window opens**, and [Maximizing a window](release-scope.md#maximizing-a-window) records the behavior.
Alternative centering modes, `never` and `always`, remain proposals rather than accepted v1 controls.
The allowed gap range remains unresolved.
Fixed-pixel width presets are deferred to v2.
Confirm each additional key against the pinned engine before adding it to Miri's schema.

## Focus and pointer controls

The engine defaults `[options].focus_follows_mouse` and `[options].mouse_follows_focus` to `false`.
A configuration without these keys therefore keeps pointer-driven focus and pointer movement off after a restart or an upgrade.
`focus_follows_mouse = true` is a hidden key that turns pointer-driven focus back on.
Settings does not show it, and Miri preserves it when Settings writes the file.
The engine also accepts `mouse_follows_focus = true`, which restores its pointer movement after focus changes and display commands.
Miri does not offer that key as a setting.

Focus borders and pointer-following controls are deferred to v2.
The following option names and defaults remain proposals for that future work, pending verification against the pinned engine.

| Proposed option | Proposed default | Behavior |
| --- | --- | --- |
| `focus_border` | `false` | Draw an overlay around the focused window. |
| `focus_border_width` | Unresolved | Border width. |
| `focus_border_color` | Unresolved | Color in `#RRGGBB` or `#RRGGBBAA` format. |
| `focus_border_radius` | Unresolved | Border corner radius. |
| `dim_inactive` | `false` | Dim the area behind the focused window. |
| `dim_inactive_opacity` | Unresolved | Dimming strength. |

Keep pointer movement opt-in.

A focus border is excluded from v1.
Its width, color, and corner radius need defaults and validation rules before implementation.
Inactive-window dimming is deferred to v2.
Its opacity remains unresolved.

## Miri dock

V2 includes a custom Miri dock with an enable or disable control.
The Miri dock is enabled by default.
When inactive-window dimming is enabled, the Miri dock dims too.
The dock's configuration key remains unresolved.
The [Miri dock plan](v2-roadmap.md#miri-dock) defines stack representation and the handling of several windows from the same app.

## Gesture controls

Supported finger counts, defaults, direction, conflict handling, and retesting follow [Strip gestures](release-scope.md#strip-gestures).

The fields below are source-backed Paneru v0.5.2 configuration fields.
They do not by themselves encode Miri's verification status or conflict policy.

| Engine field | Accepted Miri behavior | Source behavior |
| --- | --- | --- |
| `[swipe.gesture].direction` | Follow finger movement by default, with a persistent reversal setting. | Source values are `"Natural"` and `"Reversed"`. |
| `[swipe.gesture].fingers_count` | Three fingers, four fingers, or Off, subject to the accepted enablement policy. | Exact-count interception starts at three fingers. Omission or zero disables it. |
| `[swipe.gesture].vertical` | Strip swipes are horizontal only. | Vertical interception defaults to enabled. |

`swipe_natural` is absent from this release.
Legacy `[options].swipe_gesture_fingers` and `[options].swipe_gesture_direction` are deprecated.
Source acceptance of a five-finger count does not add five-finger support to Miri v1.

Miri stores the choice in `[miri].strip_gesture` as `"off"`, `"three"`, or `"four"`, and the reversal in `[miri].reverse_swipe`.
It always writes `[swipe.gesture].direction` from the reversal and sets `[swipe.gesture].vertical` to `false`.
It writes `[swipe.gesture].fingers_count` only while the selected swipe is enabled or a gesture test is running, and removes it otherwise.
It removes the legacy `[options]` swipe keys, because the engine falls back to them and would keep a swipe on that Miri turned off.
The gesture test result is app state outside the file, so a file edit cannot mark a swipe as tested.
The effect of `vertical = false` on Mission Control and App Exposé swipes still needs hardware verification.

The accepted strip target for trackpad scrolling and keyboard commands is in [Multiple monitors](release-scope.md#multiple-monitors).
Paneru's trackpad behavior needs verification and may require an engine patch.
The inspected swipe path selects the active workspace rather than a strip from pointer coordinates.
Miri's accepted pointer-target and focused-target behavior remains required integration work.

The setup experience is recorded in [Setup](setup.md).

## Animation controls

Strip motion should follow the display refresh rate.
Configurable spring duration and damping are deferred to v2.
V1 follows the Reduce Motion and disable-animation behavior in [V1 interactions](release-scope.md#v1-interactions).
The file key and engine mechanism for this behavior require verification.
The following option names, values, and behavior require validation in Miri before adoption.

| Proposed option | Proposed default | Behavior |
| --- | --- | --- |
| `animation_duration_ms` | `500` | Perceived spring duration in milliseconds. `0` disables animation. |
| `animation_damping` | `0.9` | `1.0` settles without overshoot. Lower values produce bounce. |

## Window rules and displays

Advanced window rules are deferred to v2.
Proposed rules match a bundle ID, a title regular expression, or both.
An app picker could create rules for floating a window or assigning a strip position.
Rule precedence and the file schema remain unresolved.

Automatic floating for fixed-size windows and Miri's settings follows [V1 interactions](release-scope.md#v1-interactions).
This default does not add advanced per-app rules to v1.
The file field for a fixed strip slot remains unresolved.

Excluding individual displays from management is deferred to v2.
The proposed file key is `ignored_displays`.
The proposed **Configuration > Displays** control lets users turn management off for individual displays.
The display identifier format remains unresolved.
Windows on excluded displays would retain manual positioning.

Each managed display and native Space retains its own strip.
macOS System Settings controls display arrangement, scaling, resolution, and Spaces.
Display changes follow the accepted behavior in [Release scope](release-scope.md).
Display-edge snapping and hiding a window after it slides halfway off remain candidate mechanisms.
Their relationship and suitability for Miri require verification, as recorded in [Setup](setup.md#arrange-and-select-displays).

## Shortcut configuration

Use the settings recorder for ordinary edits.
Allow several bindings per action and preserve user bindings across upgrades.
Conflict handling during recording follows [Binding customization](keybinding%20reference.md#binding-customization).
The selected defaults are in [Keybinding reference](keybinding%20reference.md).
Actions not covered there use Paneru's defaults, changed only where they clash with macOS.

Miri writes the default set to `[bindings]`, with the engine's command names as keys and its chord syntax as values.
The engine reads each key as command words split on `_`, so `window_focus_3` means `window focus 3`.
An unknown command name makes the engine reject the whole file, so Miri writes only names the pinned engine parses.
A binding whose key name the engine does not know does nothing, and a bad modifier or an extra dash makes the engine reject the whole file.
Miri reports each of these as a configuration error in Settings and the menu bar, and changes nothing in the file until the user fixes it.
A short excerpt of the written table follows.

```toml
[bindings]
window_focus_west = ["ctrl+alt-leftarrow", "ctrl+alt-h"]
window_focus_3 = "ctrl+alt-3"
window_step_grow = "ctrl+alt-equal"
window_stack_west = "ctrl+alt-leftbracket"
window_manage = "ctrl+alt-t"
```

`Sources/MiriCore/Bindings.swift` holds the full table, and [Engine mapping](keybinding%20reference.md#engine-mapping) lists the differences.
`[miri].default_bindings_version` records which defaults Miri has offered.
Miri adds a default only when the action has no binding and every chord it adds is free, and it never changes a user binding.
Miri offers each default once, so a binding the user deletes stays deleted.
The proposed `window_tabbed`, `window_wider`, `window_narrower`, `window_taller`, and `window_shorter` names are not engine commands.

## App settings and lifecycle

Store app-only settings, including launch at login and updates, in `[miri]`.
Launch at login is enabled by default.
An explicit stopped state persists across launches.
Window recovery after management ends follows [App controls and window recovery](release-scope.md#app-controls-and-window-recovery).

Miri checks for updates daily and asks before installing.
If users enable automatic updates, Miri installs updates silently in the background at startup.

The engine restores its layout after a start or crash restart.
The minimap, tabbed columns, dimming, and advanced rules remain v2 work.

## Open configuration decisions

Define validation ranges and error behavior for each additional setting before exposing it.
Confirm proposed defaults against Miri's engine and hardware checks.
Document app-only file keys when their schema is selected.
