# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Naiku is a sandboxed, menu-bar-only macOS desktop cat (Swift 6, AppKit,
macOS 26+) with optional Anthropic/OpenAI chat. `TECHNICAL_OVERVIEW.md` has
the architecture walkthrough; `README.md` covers usage and the privacy
posture; `CUSTOM_CATS.md` documents the sprite-atlas format.

## Commands

```sh
# Regenerate the Xcode project — required after editing project.yml or
# adding/moving files. Both project.yml and the .xcodeproj are committed.
xcodegen generate

# Build (Debug app lands in build/Build/Products/Debug/Naiku.app)
xcodebuild -project Naiku.xcodeproj -scheme Naiku -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build

# Full test suite (offline, no signing needed)
xcodebuild -project Naiku.xcodeproj -scheme Naiku -configuration Debug \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO

# One test class or case
xcodebuild ... test CODE_SIGNING_ALLOWED=NO \
  -only-testing:NaikuTests/PeripheralBehaviorEngineTests
  # or -only-testing:NaikuTests/<Class>/<testMethod>

# Live provider smoke check — opt-in, uses real API keys from the shell,
# never part of the suite or CI
Tools/run-live-provider-smoke.sh [--negative]
```

CI (`.github/workflows/test.yml`) runs the fixture-backed suite only.

## Architecture in one breath

Three subsystems composed in `AppDelegate`: **Terrain** turns
`CGWindowListCopyWindowInfo` geometry into walkable surfaces (`.windowTop` /
`.screenEdge` fallback); the **behaviour engine** (`Motion/`) is a pure value
type stepped with injected random decision values that returns the cat's next
position and render state; **`PetWindowController`** owns all timers, the
click-through borderless panel, pause/Reduce Motion/full-screen suppression.
Chat is a separate stack (SwiftUI panel → `ChatSessionModel` → stateless
provider structs) that only pauses the cat while open.

## Constraints that aren't obvious from any single file

- **Keep the engine pure.** All behaviour rules live in
  `PeripheralBehaviorEngine.step()` as deterministic value-type code; time,
  randomness and AppKit stay in `PetWindowController`. New behaviour should
  follow this split — it is what keeps the behaviour unit-testable.
- **The permission-light posture is a design constraint, not an accident.**
  No window titles, no Accessibility, no Screen Recording, no Input
  Monitoring. Prefer geometry from CGWindowList and sandbox-safe services
  (e.g. Carbon hot-keys via KeyboardShortcuts) over anything that prompts.
- **Tests never touch the live desktop or network.** Anything reading live
  system state must be guarded by `AppRuntime.isRunningUnitTests` or
  injectable (see `PetWindowController.init` and `WindowTerrainProviding`).
  Providers are tested through `URLProtocol` fixtures; Keychain tests use
  temporary items.
- **The sprite atlas must stay decoded-once.** `PetAnimationLibrary.bundled()`
  renders the PNG into an app-owned bitmap at load; drawing a
  PNG-provider-backed `NSImage` re-decodes the full atlas every frame (this
  was a real 10%-CPU bug — see TECHNICAL_OVERVIEW.md).
- **The README's `UserDefaults`/Keychain inventory is a promise.** If a
  change stores a new preference (including libraries writing their own
  defaults), update the README's Privacy section to match.
- Strict concurrency is `complete`; most UI-adjacent types are `@MainActor`.
  For pre-Swift-6 packages prefer a narrow `@MainActor` isolation of your own
  declarations over `@preconcurrency import`.
- When profiling, call `/usr/bin/sample` by full path — Homebrew can shadow
  `sample` with an unrelated tool.
