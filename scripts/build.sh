#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v xcodegen >/dev/null; then
  echo "xcodegen is required: brew install xcodegen" >&2
  exit 1
fi

entitlements="$root/ZApiInfo/ZApiInfo.entitlements"
backup="$(mktemp)"
cp "$entitlements" "$backup"
xcodegen generate
cp "$backup" "$entitlements"
rm -f "$backup"

xcodebuild \
  -project ZApiInfo.xcodeproj \
  -scheme ZApiInfo \
  -configuration Release \
  -derivedDataPath "$root/build/DerivedData" \
  -destination 'platform=macOS,arch=arm64' \
  build

app="$root/build/DerivedData/Build/Products/Release/ZApiInfo.app"
mkdir -p "$root/dist"
rm -rf "$root/dist/ZApiInfo.app"
cp -R "$app" "$root/dist/ZApiInfo.app"

echo "Built $root/dist/ZApiInfo.app"
echo "Install: drag it to /Applications, or run open dist/ZApiInfo.app"
