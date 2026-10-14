# LidMic — build and validation

## Build

On a development Mac with Apple Command Line Tools and Python 3:

```sh
./source/build.sh
python3 source/test.py
shortcuts sign --mode anyone --input 'LidMic.unsigned.shortcut' --output 'LidMic.shortcut'
```

Signing a shortcut in `anyone` mode sends it to Apple for validation. It is not the same as notarizing its embedded executable. Recipients need neither Python nor developer tools. The shortcut contains a gzip/base64 universal Mach-O payload, verifies its SHA-256 and code signature, executes it from a private temporary directory, and removes the temporary copy.

The build defaults to an ad-hoc signature. For a production release, use an appropriate Developer ID identity, a secure timestamp, hardened runtime, and Apple's supported notarization workflow before packaging the final helper. Do not remove quarantine attributes or disable Gatekeeper. This environment has no Developer ID identity; this preview does not claim notarization. The `SIGNING_IDENTITY` environment variable selects a build signing identity; successful signing alone does not notarize a release.

## Local data

Enable writes to `~/Library/Application Support/Lid Microphone/` and registers `~/Library/LaunchAgents/local.lid-microphone.plist`. It uses the actual user's GUI session, never a fixed numeric user ID. Only ambiguous choices save device UIDs locally. No device names or UIDs are embedded in the downloadable shortcut. A zero-byte lifecycle lock remains in Application Support after uninstall to keep concurrent operations safe.

The internal folder, executable, lock, and launch label retain their legacy names for upgrade compatibility with the earlier local utility; the product and shortcut are named LidMic. Running Enable upgrades it; this build's testing did not replace that existing installation. Uninstall removes that installation directory, including older helper files and logs if present.

## Validation performed

- 15 production selection-logic cases: open/closed/unknown lid, Bluetooth and Bluetooth LE precedence, multiple headsets, missing devices, wired/wireless/legacy Continuity transports, USB exclusion, ambiguous choices, and persisted UID choices.
- 11 isolated lifecycle operations, including repeated Enable, Disable, Uninstall, re-enable, and Status. Tests use real temporary files, executable signature checks, and a simulated launchctl service to avoid modifying the working installation.
- AppleScript compilation, universal binary architecture checks, payload round-trip/SHA-256 checks, and personal-path/name/UID checks. The exact embedded extraction/status/cleanup command also passed.
- Apple `shortcuts sign --mode anyone` successfully produced the shareable shortcut.
- Both Apple silicon and Intel (under Rosetta) payloads successfully ran read-only status against real devices and selected the available Continuity microphone. These checks did not change microphone selection.

No automated test imports or executes the interactive shortcut, presents device-choice dialogs, changes the live default microphone, or tests login restart. Manual clean-machine validation is still required: import, enable, close/open lid, attach/detach Bluetooth, log out/in, disable, and uninstall. Test macOS 13 and a physical Intel Mac before claiming those configurations verified. The compiler warns that its compatibility-packs static archive lacks an Intel slice; both final slices link, but deployment testing remains necessary.

## Release status

Repository: [twyzeas/lidmic](https://github.com/twyzeas/lidmic). Released under the [MIT license](LICENSE). This initial preview retains the testing and signing limitations documented above.
