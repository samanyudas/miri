# Paneru engine assessment

Status: source inspection, not runtime validation.
Reviewed: 13 October 2026.
Revision: `8a213313538a352537b26e25131cfe75f1e00724`.
Sam selected a bundled, pinned Paneru-based engine after this assessment.
The revision inspected here is not yet a selected release dependency.
The selected `v0.5.2` release has a separate [source assessment](engine-v0.5.2-assessment.md) dated 14 October 2026.

## App integration

Paneru implements CLI commands, JSON state queries, and JSON event subscriptions.
These provide integration points for a separate app interface.
Commands do not acknowledge completed execution, and subscriptions end when the daemon exits.
Slow subscribers can lose events, so an interface needs state reconciliation after reconnection.
Sources: [CLI client](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/client.rs) and [state queries](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/commands/query.rs).

## Configuration and identity

The IPC service name can be overridden, but the launchd identity and embedded bundle ID remain fixed to Paneru's identity.
An existing Lua configuration can override a selected TOML configuration.
Bundling Paneru therefore requires a deliberate decision about process identity and configuration isolation.
Sources: [service identity](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/platform/service.rs) and [configuration discovery](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/config.rs).

## Undocumented APIs

Paneru uses Accessibility attributes for window movement and resizing.
It also links SkyLight and uses undocumented APIs for several operations, including native Spaces and focus.
An existing macOS 14 workaround skips synthesized key-window events because the source documents a crash.
These dependencies need individual review against Miri's accepted permission and compatibility boundaries.
Sources: [SkyLight declarations](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/manager/skylight.rs) and [window operations](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/manager/windows.rs).

## Display and workspace model

Each layout strip belongs to a physical display and stores a native macOS Space ID and a virtual workspace index.
Paneru's virtual workspace rows are separate horizontal strips within one native Space.
Switching virtual rows uses the active display's current native Space ID.
This differs from a single set of virtual rows per physical monitor regardless of native Space.
Sources: [layout strips](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/ecs/layout.rs#L373) and [workspace switching](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/src/ecs/workspace.rs#L935).

Paneru documents virtual workspaces as experimental.
Its README recommends arranging physical displays above or below one another to avoid unwanted off-screen window relocation.
That physical arrangement is separate from virtual workspace rows.
Side-by-side physical display support therefore needs runtime validation rather than an assumption based on workspace terminology.
Source: [pinned README](https://github.com/karinushka/paneru/blob/8a213313538a352537b26e25131cfe75f1e00724/README.md).

## Validation limits

The inspection did not install, build, or run Paneru.
Accessibility permission behavior, SIP-enabled operation, gestures, and compatibility with Miri's target macOS versions remain unverified.
