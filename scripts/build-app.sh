#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
configuration="${1:-release}"
case "$configuration" in
  debug|release) ;;
  *) echo "Usage: scripts/build-app.sh [debug|release]" >&2; exit 2 ;;
esac

swift build --configuration "$configuration" --product WordCadence
binary_dir="$(swift build --configuration "$configuration" --show-bin-path)"
mkdir -p dist
temp_root="${TMPDIR:-/tmp}"
stage="$(mktemp -d "${temp_root%/}/word-cadence.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Word Cadence.app"
mkdir -p "$app/Contents/MacOS"
cp packaging/Info.plist "$app/Contents/Info.plist"
install -m 0755 "$binary_dir/WordCadence" "$app/Contents/MacOS/WordCadence"
# Sign outside the project folder to avoid metadata added by Finder or a sync provider.
xattr -cr "$app"
codesign --force --sign - --options runtime --entitlements packaging/Automation.entitlements "$app"
codesign --verify --strict "$app"

archive="dist/Word Cadence.zip"
/usr/bin/ditto -c -k --norsrc --keepParent "$app" "$stage/Word Cadence.zip"
mv -f "$stage/Word Cadence.zip" "$archive"
echo "$PWD/$archive"
