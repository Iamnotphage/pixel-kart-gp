# Building and releasing Pixel Kart GP

## Toolchain

The game and export templates use **Godot 4.6.3 stable, official build**. The Linux installer downloads from Godot's official download service and verifies the editor and template archives against SHA-512 digests pinned in `tools/release_install_godot.sh`. Those digests come from the [official release checksum manifest](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt).

Linux x86_64 requirements: Bash, curl, unzip, zip, Python 3, GNU coreutils, and Godot's ordinary shared-library dependencies. GitHub's `ubuntu-24.04` image provides the command-line prerequisites. The installer extracts only the Windows release and macOS templates needed here.

```sh
bash tools/release_install_godot.sh --templates
export PATH="$HOME/.local/bin:$PATH"
bash tools/release_build.sh
```

The build rejects a different editor version. `GODOT=/path/to/godot` can select an installed official 4.6.3 editor. If your home directory is read-only, provide writable `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` to both installation and build; `GODOT_BIN_DIR` and `GODOT_DOWNLOAD_CACHE` can also override installer paths.

## What gets checked

1. Headless project import, rejecting Godot error messages even if the process exits zero.
2. `tests/smoke_test.gd`: game-state and gameplay checks.
3. `tests/race_simulation.gd`: a complete automated race.
4. Main-scene headless boot for 180 frames.
5. Release export for Windows x86_64 and macOS universal.
6. ZIP integrity; Windows AMD64 PE architecture; macOS Intel/Apple Silicon Mach-O slices, executable permissions, and signature resource presence.
7. SHA-256 checksums of the finished ZIPs.

These checks do not replace playing the release on actual Windows and macOS machines. The pipeline does not claim native gameplay testing or cryptographic validation by Apple's `codesign` utility. Downloads and action versions are pinned for a repeatable build process; ZIP timestamps and generated metadata mean outputs are not promised to be bit-for-bit identical between runs.

## Output

- `dist/PixelKartGP-Windows-x86_64.zip`
- `dist/PixelKartGP-macOS-universal.zip`
- `dist/SHA256SUMS.txt`
- `dist/RELEASE_NOTES.md`

Each game ZIP includes the README, project license, and third-party notices. To verify the downloads, place both ZIPs and `SHA256SUMS.txt` in the same directory, then run `sha256sum --check SHA256SUMS.txt` on Linux or `shasum -a 256 -c SHA256SUMS.txt` on macOS. On Windows, use `Get-FileHash -Algorithm SHA256 <filename>` and compare each printed hash with the manifest.

## GitHub Actions

The workflow `.github/workflows/release.yml` runs on:

- A pushed version tag such as `v1.0.0`.
- Manual **Run workflow**. By default, this builds downloadable Actions artifacts without publishing a release. For publication, select an existing version tag and set `publish` to true.

There is intentionally no `release: published` trigger, avoiding duplicate builds when a tag is created from the release UI.

The workflow must already exist on the repository's default branch before manual dispatch is offered. Publication requires a tag matching `vMAJOR.MINOR.PATCH` (an optional prerelease suffix is accepted). A tag push trigger begins with `v` and then checks the complete version format. A branch selection with `publish: true` intentionally fails instead of creating an unintended tag.

Before a new release, update `config/version` in `project.godot` and both macOS version fields in `export_presets.cfg`, review the release notes, and commit the source. Create the corresponding version tag on that commit, then push it. A new tag created through the GitHub Release UI also triggers the tag push workflow. Keep version tags fixed after publication.

The build job has read-only repository permission. Only the publication job gets `contents: write`. Official GitHub actions are pinned to verified release commits (checkout 7.0.1, upload-artifact 7.0.2, download-artifact 8.0.2), checkout does not persist credentials, and no Apple or Windows signing secrets are needed. Before publishing, the job confirms that the tag still points to the commit it built.

Publication can be retried: it creates a draft release if missing, replaces only the two named game ZIPs and checksum asset, updates the generated release notes, then publishes. Other uploaded assets remain untouched. Builds for the same ref run serially. When a tag is created by another workflow using `GITHUB_TOKEN`, GitHub may suppress follow-on workflow triggers; use manual dispatch on the tag or an ordinary user-created tag/release in that case.

If GitHub Actions is disabled or the account lacks available runner minutes, enable the workflow or build locally and upload the three release assets to the intended existing version tag. Never describe a source-only release as containing playable downloads.

## Platform signing caveats

The Windows executable is **not Authenticode signed**. Windows may display SmartScreen warnings.

The macOS application is a **Universal 2** bundle containing x86_64 and arm64, with Godot's built-in **ad-hoc** signature. It is **not Apple Developer ID signed or notarized**. Gatekeeper may block a downloaded application. See [Godot's macOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html) and [running exported Godot apps on macOS](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html). Do not disable Gatekeeper or system-wide security controls. This project does not collect or store signing credentials.

For a polished public distribution, arrange Developer ID signing/notarization and native QA separately. The current workflow makes no claim that those steps have occurred.
