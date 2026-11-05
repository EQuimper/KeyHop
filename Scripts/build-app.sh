#!/bin/bash
set -euo pipefail
team=KJ9VT8V982
identity="Developer ID Application: Emanuel Quimper ($team)"
output=dist/KeyHop.app
bundle_id=dev.equimper.KeyHop
if [[ "${1:-}" == "--local" ]]; then
    identity=-
    output=dist/local/KeyHop.app
    bundle_id=dev.equimper.KeyHop.local
elif ! security find-identity -v -p codesigning | grep -F "\"$identity\"" >/dev/null; then
    echo "Use make dev for a local build. The maintainer build requires $identity." >&2
    exit 1
fi
swift build -c release
bin=$(swift build -c release --show-bin-path)
mkdir -p "$(dirname "$output")"
stage=$(mktemp -d dist/.keyhop.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/KeyHop.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$app/Contents/Info.plist"
cp "$bin/KeyHop" "$app/Contents/MacOS/"
codesign --force --sign "$identity" --options runtime --timestamp=none "$app"
if [[ "$identity" == "-" ]]; then
    codesign --verify --strict "$app"
else
    codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$team\" and identifier \"$bundle_id\"" "$app"
fi
# Publish only after the signed replacement is ready.
ditto "$app" "$output"
codesign --verify --strict "$output"
