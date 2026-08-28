#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ "${1:-}" == "--build" ]] || [[ ! -d "$root/dist/ZApiInfo.app" ]]; then
  "$root/scripts/build.sh"
fi

app="$root/dist/ZApiInfo.app"
if [[ ! -d "$app" ]]; then
  echo "Missing $app. Run ./scripts/build.sh first." >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
stamp="$(date +%Y%m%d)"
name="ZApiInfo-${version}-arm64"
zip="$root/dist/${name}.zip"
dmg="$root/dist/${name}.dmg"

rm -f "$zip" "$dmg"
ditto -c -k --keepParent "$app" "$zip"

stage="$root/build/dmg-stage"
rm -rf "$stage"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

hdiutil create \
  -volname "ZApiInfo ${version}" \
  -srcfolder "$stage" \
  -ov -format UDZO \
  -fs HFS+ \
  "$dmg" >/dev/null

echo
echo "Packages ready (${version} / ${stamp}):"
ls -lh "$app" "$zip" "$dmg"
echo
echo "Checksums:"
shasum -a 256 "$zip" "$dmg"
echo
echo "Install: open the dmg and drag ZApiInfo to Applications."
echo "If Gatekeeper blocks it: System Settings → Privacy & Security → Open Anyway."
