#!/usr/bin/env bash
# Linux x86_64. Official downloads, version and SHA-512 digests pinned together.
# Digests: https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt
set -euo pipefail
version=4.6.3
base="https://downloads.godotengine.org"
cache="${GODOT_DOWNLOAD_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/pixel-kart-gp}"
bin="${GODOT_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$cache" "$bin"
fetch() {
  local name="$1" digest="$2"
  if ! (cd "$cache" && printf '%s  %s\n' "$digest" "$name" | sha512sum --check --status); then
    local slug="${name#Godot_v${version}-stable_}"
    curl --fail --location --retry 4 --retry-delay 3 \
      "$base/?version=$version&flavor=stable&slug=$slug" -o "$cache/$name.part"
    (cd "$cache" && printf '%s  %s.part\n' "$digest" "$name" | sha512sum --check)
    mv "$cache/$name.part" "$cache/$name"
  fi
}
fetch "Godot_v${version}-stable_linux.x86_64.zip" a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c
unzip -oq "$cache/Godot_v${version}-stable_linux.x86_64.zip" -d "$bin"
chmod +x "$bin/Godot_v${version}-stable_linux.x86_64"
ln -sf "Godot_v${version}-stable_linux.x86_64" "$bin/godot"
if [[ "${1:-}" == "--templates" ]]; then
  fetch "Godot_v${version}-stable_export_templates.tpz" da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
  target="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
  mkdir -p "$target"
  # Only the release templates needed by these two presets; avoid extracting mobile SDKs.
  unzip -oj "$cache/Godot_v${version}-stable_export_templates.tpz" \
    templates/version.txt templates/windows_release_x86_64.exe templates/macos.zip -d "$target"
fi
[[ -z "${GITHUB_PATH:-}" ]] || printf '%s\n' "$bin" >> "$GITHUB_PATH"
"$bin/godot" --version
