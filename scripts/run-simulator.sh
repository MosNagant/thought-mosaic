#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build
xcrun simctl list devices available -j > build/devices.json
MOSAIC_SIMULATOR_ID="${MOSAIC_SIMULATOR_ID:-$(python3 - <<'PY'
import json
data = json.load(open('build/devices.json'))
phones = [d for r, devices in data['devices'].items() if 'iOS' in r for d in devices if d.get('isAvailable') and d['name'].startswith('iPhone')]
if not phones:
    raise SystemExit('Install an iOS simulator runtime in Xcode Settings > Components first.')
phones.sort(key=lambda d: (d['state'] != 'Booted', 'Pro' in d['name'], d['name']))
print(phones[0]['udid'])
PY
)}"
xcodebuild -project ThoughtMosaic.xcodeproj -scheme ThoughtMosaic \
  -destination "platform=iOS Simulator,id=$MOSAIC_SIMULATOR_ID" \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
MOSAIC_BOOT_STATE="$(xcrun simctl list devices booted -j)"
if ! [[ "$MOSAIC_BOOT_STATE" == *"$MOSAIC_SIMULATOR_ID"* ]]; then
  xcrun simctl boot "$MOSAIC_SIMULATOR_ID"
fi
xcrun simctl bootstatus "$MOSAIC_SIMULATOR_ID" -b
xcrun simctl install "$MOSAIC_SIMULATOR_ID" build/DerivedData/Build/Products/Debug-iphonesimulator/ThoughtMosaic.app
xcrun simctl launch "$MOSAIC_SIMULATOR_ID" com.mosnagant.thoughtmosaic
