#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$tool_dir/.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/naiku-live-smoke.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

xcrun swiftc \
  -parse-as-library \
  -swift-version 6 \
  "$project_dir/Naiku/Chat/ChatError.swift" \
  "$project_dir/Naiku/Chat/ChatMessage.swift" \
  "$project_dir/Naiku/Chat/ChatProviderID.swift" \
  "$project_dir/Naiku/Chat/ChatProviding.swift" \
  "$project_dir/Naiku/Chat/ChatRequest.swift" \
  "$project_dir/Naiku/Providers/Anthropic/AnthropicChatProvider.swift" \
  "$project_dir/Naiku/Providers/OpenAI/OpenAIChatProvider.swift" \
  "$tool_dir/LiveProviderSmoke.swift" \
  -o "$scratch/naiku-live-provider-smoke"

"$scratch/naiku-live-provider-smoke" "$@"
