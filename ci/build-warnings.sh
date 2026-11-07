#!/bin/bash
# Adds to the run summary the warnings of this job's build and test logs. Warnings are reported, not
# treated as errors: they must be reviewed by hand.
set -euo pipefail
logs=()
for log in build/build.log build/unit-test.log build/ui-test.log build/build-release.log; do
  if [ -f "$log" ]; then logs+=("$log"); fi
done
if [ "${#logs[@]}" -eq 0 ]; then
  echo "No build log found." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi
# Compiler, build-system and build-tool diagnostics are printed as "warning: ...".
warnings="$(grep -hE '(^|[]:] )warning: ' "${logs[@]}" | sort -u || true)"
count="$(printf '%s' "$warnings" | grep -c . || true)"
{
  echo "## Build warnings: $count"
  if [ "$count" -gt 0 ]; then
    echo
    echo '```'
    echo "$warnings"
    echo '```'
  fi
} >> "$GITHUB_STEP_SUMMARY"
