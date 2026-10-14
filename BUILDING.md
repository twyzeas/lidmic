# Build LidMic

Requires a Mac with Apple Command Line Tools and Python 3. Run these commands from the repository root.

## Build and test

```sh
bash source/build.sh
python3 source/test.py
python3 source/test_shortcut.py
python3 source/test_watcher.py
```

The build creates a universal Apple silicon/Intel helper and embeds it in `LidMic.unsigned.shortcut`. Tests cover microphone selection, isolated installation/removal, menu actions, event handling, and package integrity. They do not change your installed helper or microphone.

## Sign and package

```sh
shortcuts sign --mode anyone \
  --input 'LidMic.unsigned.shortcut' \
  --output 'LidMic — Auto Switch Mic.shortcut'
python3 - <<'PYTHON'
from zipfile import ZipFile, ZIP_DEFLATED
with ZipFile('lidmic-0.2.0.zip', 'w', compression=ZIP_DEFLATED) as archive:
    archive.write('LidMic — Auto Switch Mic.shortcut')
PYTHON
shasum -a 256 lidmic-0.2.0.zip > SHA256SUMS
```

Update the version in the ZIP filename for each release. Publish the ZIP as the user download; keep the shortcut's readable filename inside it because macOS uses that name during import. Release history lives in [GitHub Releases](https://github.com/twyzeas/lidmic/releases).

Shortcut signing sends the file to Apple for sharing validation. It does **not** notarize the helper. The helper is ad-hoc signed by default; `SIGNING_IDENTITY` selects a Developer ID identity when building. Developer ID signing and notarization require a separate release workflow.

## Compatibility checks

The deployment target is macOS 13. Apple silicon and Intel under Rosetta have been checked; older macOS versions and physical Intel Macs still need testing. An Intel compatibility-library linker warning remains a deployment-testing concern.

Before releasing, manually check import, Enable, lid switching, Bluetooth priority, sleep/wake, login startup, Disable, and Uninstall. Automated checks do not replace these device tests.

## Installation paths

- Helper and preferences: `~/Library/Application Support/Lid Microphone/`
- Startup entry: `~/Library/LaunchAgents/local.lid-microphone.plist`

Keep these legacy identifiers stable so newer shortcuts can upgrade or uninstall earlier helpers. Disable removes the startup entry; Uninstall also removes the installation folder. Both leave the current microphone selected. A zero-byte `.lid-microphone.lock` file remains in Application Support to serialize setup operations.

## Repository checks

Pull requests run the build and tests on macOS, plus CodeQL scans for Swift, Python, and GitHub Actions. CodeQL also runs weekly; Dependabot checks workflow action updates weekly. Actions are pinned to commit hashes. CI uses an ad-hoc helper signature and does not sign shortcuts for distribution or access release signing credentials.
