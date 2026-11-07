#!/bin/bash
# Selects the pinned Xcode (XCODE_PATH) and fails unless it is exactly XCODE_VERSION (XCODE_BUILD). Every
# macOS job of the CI runs this, so all of them build and test with the same Xcode.
set -euo pipefail
sudo xcode-select --switch "$XCODE_PATH"
version_output="$(xcodebuild -version)"
echo "$version_output"
actual_version="$(echo "$version_output" | sed -n '1p')"
actual_build="$(echo "$version_output" | sed -n '2p')"
if [ "$actual_version" != "Xcode $XCODE_VERSION" ] || [ "$actual_build" != "Build version $XCODE_BUILD" ]; then
  echo "::error::Expected Xcode $XCODE_VERSION ($XCODE_BUILD) but found: $version_output"
  exit 1
fi
