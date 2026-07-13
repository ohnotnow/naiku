# Naiku

Naiku is a tiny native macOS cat that inhabits the edges of your desktop. It sits and strolls along window tops, occasionally jumps between them, and can chat using either Anthropic or OpenAI.

The cat is perfectly happy without an API key. Chat is optional and uses your own provider account. Keys live in macOS Keychain, the current conversation stays in memory, and there are no analytics or backend services tucked away somewhere.

![screenshot](scrrenshot.png)

## What it does

- Rests, stretches, takes short strolls and sometimes settles in for a longer nap along exposed window tops.
- Wanders and changes windows independently, while occasionally showing a little interest in the pointer.
- Jumps between safe surfaces and falls back to a screen edge when no suitable title bar is available.
- Lets ordinary clicks pass through the roaming cat. Move the pointer onto a stationary Naiku and pause until the paw-wave cue if you intend to click the cat and open chat.
- Sits still while the chat panel is open, then carries on as before when you close it.
- Chats through Anthropic's Messages API or OpenAI's Responses API.
- Keeps the two provider keys separate and lets you edit each model ID.
- Has pause, settings and quit controls in the menu bar.
- Stays put when macOS Reduce Motion is enabled.
- Blinks, breathes and settles into a patient waiting loop between decisions.

Naiku's orange cat uses a complete, data-driven sprite atlas with separate rightward, leftward and vertical running cycles. A second cat is still an idea for later.

## Requirements

- macOS 14 or later
- Xcode with Swift 6 support
- An Anthropic or OpenAI API key if you want to use chat

The source has been tested with Xcode 26.1.1. The checked-in Xcode project was generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44.1. You only need XcodeGen if you change `project.yml` or the project structure.

## Getting started

Clone the repository and open `Naiku.xcodeproj` in Xcode. Select the `Naiku` scheme, choose "My Mac", and run it.

To build from Terminal:

```sh
xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Naiku is a menu-bar app, so you will not see it in the Dock. The first launch opens a non-modal settings window with the optional chat setup. Close it and the cat will start roaming. To chat, briefly hover over a stationary Naiku until the cat waves, then click; **Chat with Naiku…** in the cat menu is always available too.

If you edit `project.yml`, regenerate the project before building:

```sh
xcodegen generate
```

## Chat setup

Open the cat menu in the macOS menu bar and choose **Settings…**.

1. Choose Anthropic or OpenAI.
2. Create a key in the [Anthropic Console](https://console.anthropic.com/settings/keys) or on the [OpenAI API key page](https://platform.openai.com/api-keys).
3. Paste the key into the matching secure field and save it.
4. Keep the suggested model ID, or replace it with another model available to your account.

The initial model IDs are `claude-haiku-4-5` and `gpt-5.6-luna`. API access may incur charges on your provider account. If you switch provider, Naiku starts a fresh in-memory conversation.

## Privacy and security

Each API key is stored as a separate generic-password item in macOS Keychain. Keys are never written to `UserDefaults`, source files, test fixtures or logs. The only preferences kept in `UserDefaults` are your provider choice, model IDs and whether the welcome screen has been shown.

Keychain items are available only while the Mac is unlocked. If you paste a key but close Settings without saving it, Naiku discards that draft.

Conversation messages remain in memory for the current app session. Naiku sends them to the active provider only when you submit them, and does not save them. Your provider may retain or process requests under its own terms and account settings.

The app runs in the macOS App Sandbox with outbound network access. Its current feature set does not need Accessibility, Screen Recording or Automation permission.

## macOS behaviour and limitations

Naiku asks macOS to appear on every ordinary Space and alongside full-screen apps. macOS still controls window ordering, so an exclusive full-screen app or an unusual window-management setup can temporarily hide the cat or chat panel.

It copes with displays that have negative coordinates or sit above or below the primary display. Disconnect or rearrange a display and Naiku recovers onto an available surface. Window bounds come from required Core Graphics geometry; Naiku does not read window titles or request Screen Recording or Accessibility permission.

Naiku uses exposed horizontal window tops rather than semantic title-bar controls. Fully maximised windows do not leave enough safe room above their content, so Naiku uses a screen-edge fallback instead. Climbing window sides and understanding particular applications are ideas for later.

Chat is deliberately non-streaming in v0.1. There is no saved transcript, tool use, voice mode, launch-at-login option, automatic updater or packaged binary release yet.

## Running tests

The test suite uses local URL protocol fixtures and temporary Keychain items. It never makes live provider requests.

```sh
xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -configuration Debug \
  -destination 'platform=macOS' \
  test \
  CODE_SIGNING_ALLOWED=NO
```

Live Anthropic and OpenAI checks are manual and opt-in. They use the developer's own credentials and may incur API charges.

With either `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` set in your shell, run the real adapter smoke check with:

```sh
Tools/run-live-provider-smoke.sh
```

The helper compiles the same adapter sources used by the app, sends one short request to each configured provider, and removes its temporary binary afterwards. It prints provider status and response length, never the key or response text.

To also verify live authentication and invalid-model error mapping:

```sh
Tools/run-live-provider-smoke.sh --negative
```

The checked-in GitHub Actions workflow runs the fixture-backed test suite on pushes and pull requests. It does not need provider credentials.

## Creating a local archive

An unsigned source archive can be produced locally with:

```sh
xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/Naiku.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO
```

This is useful for checking the Release build, but an unsigned app is not suitable for distribution to other Macs. A public binary needs an Apple Developer ID Application certificate, hardened-runtime signing, notarisation and ticket stapling. The first public release is intended to be buildable source, rather than a notarised download.

## Contributing and support

Small, focused changes are very welcome. Fork or clone the repository, regenerate the Xcode project if you change its structure, and run the full test command before opening a pull request. Please do not commit API keys, provider responses, personal conversations or Xcode user data.

Once the public repository is available, please open a GitHub issue for bugs and feature suggestions. Leave credentials and private conversation content out of security-sensitive reports.

## Licence

Naiku is available under the MIT Licence. The bundled orange-cat atlas was generated specifically for this project with OpenAI's Image API, starting from the project's original orange-cat SVG design, and is distributed with the project under the same licence.
