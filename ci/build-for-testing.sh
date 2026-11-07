#!/bin/bash
# Builds the app and every test target for the simulator of SIMULATOR_DESTINATION (Debug, no signing).
# Every macOS job of the CI builds this way, so the machines test the same build settings.
set -euo pipefail
source ci/record-step.sh build_for_testing || true
xcodebuild build-for-testing \
  -project IronFlow.xcodeproj \
  -scheme IronFlow \
  -configuration Debug \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -showBuildTimingSummary \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build/build.log
