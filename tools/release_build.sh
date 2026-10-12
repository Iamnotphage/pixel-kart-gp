#!/usr/bin/env bash
# Rebuild both release archives with the pinned editor and official export templates.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
version="$($GODOT --version)"
[[ "$version" == 4.6.3.stable.official.* ]] || { echo "Expected official Godot 4.6.3; got $version" >&2; exit 1; }
rm -rf build/windows
mkdir -p build/windows dist
run_godot() {
  local log
  log="$(mktemp)"
  if ! timeout 180 "$GODOT" --headless --path . "$@" 2>&1 | tee "$log"; then
    rm -f "$log"; return 1
  fi
  # Some script/import failures do not make the Godot process exit nonzero.
  if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log"; then
    echo "Godot reported errors; refusing release." >&2
    rm -f "$log"; return 1
  fi
  rm -f "$log"
}
run_godot --editor --import
run_godot --script tests/smoke_test.gd
run_godot --script tests/race_simulation.gd
run_godot --quit-after 180
run_godot --export-release "Windows Desktop" build/windows/PixelKartGP.exe
rm -f dist/PixelKartGP-macOS-universal.zip
run_godot --export-release "macOS" dist/PixelKartGP-macOS-universal.zip
for file in README.md LICENSE THIRD_PARTY_NOTICES.md; do
  if [[ -f "$file" ]]; then
    cp "$file" build/windows/
    zip -q dist/PixelKartGP-macOS-universal.zip "$file"
  fi
done
# Keep README screenshots and release-guide links working in downloaded packages.
mkdir -p build/windows/docs
for file in docs/menu.png docs/gameplay.png docs/RELEASING.md; do
  if [[ -f "$file" ]]; then
    cp "$file" build/windows/docs/
    zip -q dist/PixelKartGP-macOS-universal.zip "$file"
  fi
done
# Fresh archive, never accidentally retain old files from a previous build.
rm -f dist/PixelKartGP-Windows-x86_64.zip
(cd build/windows && zip -q -r ../../dist/PixelKartGP-Windows-x86_64.zip .)
unzip -tq dist/PixelKartGP-Windows-x86_64.zip
unzip -tq dist/PixelKartGP-macOS-universal.zip
python3 tools/release_verify_archives.py
(cd dist && sha256sum PixelKartGP-Windows-x86_64.zip PixelKartGP-macOS-universal.zip > SHA256SUMS.txt)
cat > dist/RELEASE_NOTES.md <<'NOTES'
# Pixel Kart GP

Original pixel-art, pseudo-3D kart circuit racer, built with official Godot 4.6.3.

- **Windows x86_64:** extract the ZIP, then run `PixelKartGP.exe`.
- **macOS universal:** extract the ZIP and move `Pixel Kart GP.app` to Applications. Includes Intel and Apple Silicon binaries. Ad-hoc signed, **not Apple Developer ID signed or notarized**; Gatekeeper may block it. Follow the README and official Godot macOS guidance. No system-wide security changes are required or recommended.
- `SHA256SUMS.txt` lets you verify the two downloaded ZIPs.

Automated validation: Linux headless project import, scripted gameplay smoke checks, a complete automated race, main-scene boot, export success, ZIP integrity, and target executable architecture checks. Native Windows/macOS gameplay is not tested by this pipeline.

See the included README for controls, gameplay, and platform caveats.
NOTES
printf '\nRelease files:\n'
ls -lh dist/
