#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build artifacts
xcrun simctl list devices available -j > build/devices.json
MOSAIC_SIMULATOR_ID="${MOSAIC_SIMULATOR_ID:-$(python3 - <<'PY'
import json
data = json.load(open('build/devices.json'))
phones = [device for runtime, devices in data['devices'].items() if 'iOS' in runtime for device in devices if device.get('isAvailable') and device['name'].startswith('iPhone')]
if not phones:
    raise SystemExit('No iPhone simulator. Install an iOS runtime in Xcode Settings > Components.')
phones.sort(key=lambda d: (d['state'] != 'Booted', 'Pro' in d['name'], d['name']))
print(phones[0]['udid'])
PY
)}"
xcodebuild -project ThoughtMosaic.xcodeproj -scheme ThoughtMosaic \
  -destination "platform=iOS Simulator,id=$MOSAIC_SIMULATOR_ID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "build/UITests-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
