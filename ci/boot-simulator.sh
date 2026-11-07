#!/bin/bash
# Finds the one simulator named by SIMULATOR_DESTINATION (name and OS), boots it and waits until it has
# completely booted; its UDID goes to SIMULATOR_UDID for the next steps. It runs after the build, in its
# own step, so each one is measured alone: in run 38645463404, with both at once, the build was much
# slower (the cause is not proven). The tests run on this one device, by its UDID.
set -euo pipefail
mkdir -p build/diagnostics
xcrun simctl list runtimes --json > build/diagnostics/runtimes.json
xcrun simctl list devices available --json > build/diagnostics/devices.json
# The device named by SIMULATOR_DESTINATION (name and OS); exactly one must exist.
python3 - <<'PY'
import json, os, sys
fields = dict(part.split("=", 1) for part in os.environ["SIMULATOR_DESTINATION"].split(","))
name, version = fields["name"], fields["OS"]
with open("build/diagnostics/runtimes.json") as f:
    runtimes = [
        runtime for runtime in json.load(f)["runtimes"]
        if runtime.get("isAvailable") and runtime.get("version") == version
        and (runtime.get("platform") == "iOS" or runtime.get("name", "").startswith("iOS "))
    ]
with open("build/diagnostics/devices.json") as f:
    devices = json.load(f)["devices"]
matches = [
    (runtime, device)
    for runtime in runtimes
    for device in devices.get(runtime["identifier"], [])
    if device.get("name") == name
]
if len(matches) != 1:
    print(f"::error::Expected exactly one available {name} with iOS {version}, found {len(matches)}.")
    for runtime, device in matches:
        print(f"  {device.get('udid')} {runtime.get('identifier')}")
    sys.exit(1)
runtime, device = matches[0]
simulator = {
    "name": device["name"],
    "udid": device["udid"],
    "state": device.get("state"),
    "runtime": {key: runtime.get(key) for key in ("identifier", "name", "version", "buildversion")},
}
with open("build/diagnostics/simulator.json", "w") as f:
    json.dump(simulator, f, indent=2)
print(json.dumps(simulator, indent=2))
PY
udid="$(python3 -c 'import json; print(json.load(open("build/diagnostics/simulator.json"))["udid"])')"
echo "SIMULATOR_UDID=$udid" >> "$GITHUB_ENV"
# Only the boot is timed: from here until the simulator has completely booted.
source ci/record-step.sh simulator_boot || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl list devices booted | tee build/diagnostics/booted-devices.txt
