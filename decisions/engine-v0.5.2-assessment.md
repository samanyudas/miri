# Paneru v0.5.2 source assessment

Status: source inspection, not runtime validation.
Reviewed: 14 October 2026.
Selected tag: `v0.5.2`.
Revision: `b1b6abbd3f1a4be138152b6f0389c9ff1b27a269`.
The tag API and a temporary checkout agreed on this revision.
No engine was built, installed, or run.
This assessment supplements the [earlier inspection](engine-assessment.md) without treating its different revision as the release dependency.

## Configuration fields

The width preset field is `[options].preset_column_widths`, stored as floating-point ratios.
Paneru has no `gap_inner` or `gap_outer` fields.
Outer padding uses `[padding].top`, `right`, `bottom`, and `left`, each stored as an unsigned 16-bit integer.
Per-window `horizontal_padding` and `vertical_padding` are signed integers, clamped to 0 through 50 when applied.
Adjacent windows contribute padding from both sides.
The accepted eight-point Miri gaps therefore need a deliberate mapping and coordinate verification.

Sources: [configuration types](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/config.rs#L1180), [outer padding](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/config/padding.rs#L3), and [applied window padding](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/ecs/triggers.rs#L1189).

## Gesture schema and target

The preferred gesture fields are `[swipe.gesture].fingers_count`, `direction`, and `vertical`.
Direction accepts `Natural` or `Reversed`.
The legacy top-level gesture options are deprecated, and `swipe_natural` is absent.
Gesture interception requires an exact finger-count match with a configured count of at least three.
Omission or counts below three disable interception.
Five fingers pass those source conditions, but successful hardware operation remains unverified.

The swipe system operates on the active workspace rather than selecting a strip from pointer coordinates.
Miri's pointer-target and focused-target setting therefore needs integration work.
Vertical interception defaults to enabled.
Miri must assess its configuration alongside horizontal-only strip behavior, disabled virtual workspaces, and retained macOS gestures.

Sources: [gesture fields](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/config/swipe.rs#L5), [interception condition](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/platform/input.rs#L630), [swipe target](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/ecs/scroll.rs#L94), and [vertical default](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/config.rs#L524).

## Sizing behavior

Configured width rules also run during startup window discovery.
A blanket width rule therefore does not establish Miri's new-window-only 50% default while preserving existing widths.
Grow and shrink commands choose adjacent presets.
Their `0.05` comparison is a selection tolerance, not a fixed five-percentage-point resize step.
Miri's accepted incremental commands require integration work.

Sources: [width application](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/ecs/triggers.rs#L1173) and [preset selection](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/commands.rs#L770).

## Configuration isolation

An existing path in `PANERU_CONFIG` selects a TOML file.
A missing path falls back to standalone Paneru locations.
In Lua-enabled builds, Lua discovery runs first and can suppress the selected TOML file.
An environment variable alone therefore does not establish Miri's required isolation.

The configuration type has no field for `[miri]` and does not reject unknown fields explicitly.
Ignoring that app-only section is an inference from its deserialization structure, not a tested Miri configuration.
Miri must verify coexistence and prevent all standalone configuration discovery.

Source: [configuration discovery and structure](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/config.rs#L51).

## Clean exit and Q12 recovery

Paneru's normal application-exit handler centers tracked windows on connected displays and shrinks oversized windows.
It can also move windows that were already visible.
Abrupt termination cannot rely on this handler running.
This source path does not prove actual macOS accessibility after an engine crash.

Miri must satisfy the [window recovery requirement](release-scope.md#app-controls-and-window-recovery) even when the engine cannot execute cleanup.

Source: [exit cleanup](https://github.com/karinushka/paneru/blob/b1b6abbd3f1a4be138152b6f0389c9ff1b27a269/src/ecs/systems.rs#L1156).

## Remaining verification

The helper permission-attribution prototype remains the first native implementation prerequisite in [ADR 0009](../docs/adr/0009-run-the-engine-as-a-helper-process.md).
Horizontal displays, gesture coexistence, display migration, fullscreen return, and failure recovery need real hardware checks.
These findings refine engineering work without weakening the [accepted release scope](release-scope.md).
