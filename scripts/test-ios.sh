#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_root="$(mktemp -d "${TMPDIR:-/tmp}/flow-tests.XXXXXX")"
derived_data="${FLOW_DERIVED_DATA:-$test_root/DerivedData}"
result_bundle="${FLOW_RESULT_BUNDLE:-$test_root/TestResults.xcresult}"
simulator_id="${FLOW_SIMULATOR_ID:-$(xcrun simctl list devices available --json | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in data if "iOS-" in r), key=lambda r: tuple(int(p) for p in r.split("iOS-")[1].split("-")), reverse=True)
for runtime in runtimes:
    devices = [d for d in data[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if devices:
        print(next((d for d in devices if d["state"] == "Booted"), devices[0])["udid"])
        break
else:
    sys.exit("No available iPhone simulator")
')}"

xcodebuild -project Flow.xcodeproj -scheme Flow -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Flow.xcodeproj -scheme Flow -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$simulator_id" -b
xcodebuild -project Flow.xcodeproj -scheme Flow -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -parallel-testing-enabled NO \
  -derivedDataPath "$derived_data" -resultBundlePath "$result_bundle" \
  CODE_SIGNING_ALLOWED=NO test
printf 'Test results: %s\n' "$result_bundle"
