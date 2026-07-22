#!/bin/bash

set -e

echo "Building Naiku... We have the technology."

xcodebuild \
  -project Naiku.xcodeproj \
  -scheme Naiku \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  build

echo "Naiku is hiding in 'build/Build/Products/Debug/Naiku.app'."

echo "To run Naiku, run (it will ask for permission to use KeyChain so it can securely store your API key if you use one):"
echo ""
echo "open build/Build/Products/Debug/Naiku.app"
