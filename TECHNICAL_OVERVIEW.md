# Technical Overview

Last updated: 2026-07-22

## What This Is

Naiku is a tiny native macOS cat that lives along the tops of your windows —
resting, strolling and jumping between them — with an optional chat panel
backed by Anthropic or OpenAI. This document orients contributors and people
basing their own desktop-companion project on the code; the README covers
usage and privacy posture.

## Stack

- Swift 6 (`SWIFT_STRICT_CONCURRENCY: complete`), AppKit, macOS 26+
- XcodeGen 2.44.1 — `project.yml` is the source of truth; the `.xcodeproj` is
  checked in, regenerate after structural changes
- One SPM package: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 1.10+ (global chat hotkey + recorder UI)
- App Sandbox + hardened runtime; sole entitlement beyond sandbox is
  `network.client`. Menu-bar only (`LSUIElement: true`), no Dock icon
- XCTest; fixture-backed, no live network in the suite

## Directory Structure

```
Naiku/
  App/        AppDelegate (composition root), StatusMenuController (menu bar),
              GlobalShortcuts, AppRuntime (is-running-unit-tests guard)
  Pet/        PetWindowController (timers, window, suppression),
              PetSpriteView (atlas rendering, click hit-testing),
              PetAnimationManifest (atlas + JSON manifest loading),
              DirectChatIntentTracker (hover-to-click arming), PetRenderState
  Motion/     PeripheralBehaviorEngine (pure behaviour state machine),
              DesktopGeometry (multi-display maths)
  Terrain/    WindowTerrain (surface model + builder),
              CoreGraphicsWindowTerrainProvider (CGWindowList snapshots),
              FullScreenSpaceDetector
  Chat/       ChatSessionModel (state), ChatPanelController/View (SwiftUI in
              a borderless NSPanel), ConversationHistory, ChatError mapping
  Providers/  AnthropicChatProvider (Messages API),
              OpenAIChatProvider (Responses API) — both behind ChatProviding
  Settings/   SettingsModel/View/WindowController, AppPreferences
              (UserDefaults), KeychainAPIKeyStore
  Resources/  NaikuSpritesheet.png (1536×1872 atlas), NaikuAnimations.json
Tests/NaikuTests/   one test file per subsystem, plus Support/ fixtures
Tools/              opt-in live-API smoke check (never run by the suite)
```

## Architecture

Three loosely coupled subsystems, composed in `AppDelegate`:

```
CGWindowList ──> TerrainProvider ──> TerrainSnapshot
                                          │ (every 2 s)
        pointer, elapsed, random decision │
                                          ▼
              PeripheralBehaviorEngine.step()   ← pure, deterministic
                                          │
                     origin + PetRenderState
                                          ▼
   PetWindowController ──> PetPanel ──> PetSpriteView (sprite atlas)
        │ click / hotkey / menu
        ▼
   ChatPanelController ──> ChatSessionModel ──> ChatProviding impl ──> API
```

- **The engine is a pure value type.** `PeripheralBehaviorEngine.step()` takes
  origin, pointer, elapsed time, a `TerrainSnapshot` and injected random
  `PeripheralDecisionValues`, and returns the next origin/render state. All
  behaviour rules (rest/nap/stroll/jump bands, pointer curiosity, the
  screen-edge dwell that sends the cat back up to window tops) live here and
  are unit-tested deterministically.
- **Terrain is geometry only.** `WindowTerrainBuilder` turns
  `CGWindowListCopyWindowInfo` records into walkable `TerrainSurface`s
  (`.windowTop` or `.screenEdge` fallback), subtracting occlusions. No window
  titles are read; no Accessibility/Screen Recording permission is used.
- **The controller owns time and the window.** `PetWindowController` runs the
  motion timer (15 Hz moving, 2 Hz stationary), refreshes terrain every 2 s,
  and handles pause, Reduce Motion (stops timers entirely), full-screen
  suppression, display changes and click-through.

### Behavioural details worth knowing

- Click-through: the pet panel has `ignoresMouseEvents = true` until
  `DirectChatIntentTracker` arms — pointer moves onto a *stationary* cat and
  dwells 0.5 s — which also triggers the waving cue. Clicking then opens chat.
- Full-screen avoidance is active self-suppression (`orderOut` + 1 s recheck
  timer): `.canJoinAllSpaces` panels gatecrash full-screen Spaces regardless
  of `.fullScreenAuxiliary`, so the cat must notice covering windows itself.
- The sprite atlas is decoded **once** into an app-owned bitmap at load
  (`PetAnimationLibrary.bundled()`); drawing a PNG-provider-backed image
  re-decodes every frame and was a real 10%-CPU bug. Atlas layout and frame
  timings come from `NaikuAnimations.json` — see `CUSTOM_CATS.md`.

## Chat

`ChatSessionModel` keeps an in-memory `ConversationHistory` capped at 12
messages. `ChatRequest` carries model ID, history, a fixed cat-persona system
prompt and a 256-token output cap (`ChatDefaults`). Providers are stateless
structs mapping to/from each API's wire format, sharing `ChatErrorMapper` for
readable auth/model/rate-limit errors. Non-streaming by design. Switching
provider starts a fresh conversation.

## Persistence

| Data | Where |
|------|-------|
| API keys (one per provider) | Keychain generic passwords, service `dev.naiku.api-keys` |
| Provider choice, model IDs, full-screen toggle, welcome-seen flag | `UserDefaults` |
| Recorded chat hotkey | `UserDefaults` (written by KeyboardShortcuts) |
| Conversation | Memory only, gone at quit |

## Testing

- XCTest, one file per subsystem; 87 tests, all offline.
- Engine tests inject fixed `PeripheralDecisionValues` — behaviour is fully
  deterministic. Provider tests use `URLProtocol` fixtures; Keychain tests use
  temporary items.
- `AppRuntime.isRunningUnitTests` guards app bootstrap and live system reads
  (CGWindowList, screens) so the test host spawns no UI and ignores whatever
  is on the developer's desktop.
- Run: `xcodebuild -project Naiku.xcodeproj -scheme Naiku -configuration
  Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
- Live provider smoke check (opt-in, uses real keys from the shell):
  `Tools/run-live-provider-smoke.sh [--negative]`

## Local Development

```sh
xcodegen generate      # only after changing project.yml / file structure
xcodebuild -project Naiku.xcodeproj -scheme Naiku -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/Naiku.app
```

Ad-hoc signed rebuilds look like a new app to Keychain — the first chat after
a rebuild re-prompts; choose **Always Allow**. When profiling, use
`/usr/bin/sample` by full path (Homebrew can shadow `sample`).
