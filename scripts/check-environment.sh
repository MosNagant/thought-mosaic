#!/bin/bash
set -euo pipefail
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -version
xcrun swift --version
xcodebuild -showsdks
xcrun simctl list devices available
