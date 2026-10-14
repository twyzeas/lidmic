# LidMic — build and validation

## Build

On a development Mac with Apple Command Line Tools and Python 3:

```sh
./source/build.sh
python3 source/test.py
python3 source/test_watcher.py
python3 source/test_shortcut.py
shortcuts sign --mode anyone --input 'LidMic.unsigned.shortcut' --output 'LidMic — Auto Switch Mic.shortcut'
```

Signing a shortcut in `anyone` mode sends it to Apple for validation. It is not the same as notarizing its embedded executable. Recipients need neither Python nor developer tools. The shortcut contains a gzip/base64 universal Mach-O payload, verifies its SHA-256 and code signature, executes it from a private temporary directory, and removes the temporary copy.

The build defaults to an ad-hoc signature. For a production release, use an appropriate Developer ID identity, a secure timestamp, hardened runtime, and Apple's supported notarization workflow before packaging the final helper. Do not remove quarantine attributes or disable Gatekeeper. This environment has no Developer ID identity; this preview does not claim notarization. The `SIGNING_IDENTITY` environment variable selects a build signing identity; successful signing alone does not notarize a release.

## Local data

Enable writes to `~/Library/Application Support/Lid Microphone/` and registers `~/Library/LaunchAgents/local.lid-microphone.plist`. It uses the actual user's GUI session, never a fixed numeric user ID. Only ambiguous choices save device UIDs locally. No device names or UIDs are embedded in the downloadable shortcut. A zero-byte lifecycle lock remains in Application Support after uninstall to keep concurrent operations safe.

The internal folder, executable, lock, and launch label retain their legacy names for upgrade compatibility with the earlier local utility; the product is named LidMic and the shortcut is named LidMic — Auto Switch Mic. Running Enable upgrades it; this build's testing did not replace that existing installation. Uninstall removes that installation directory, including older helper files and logs if present.

## Validation performed

- 15 production selection-logic cases: open/closed/unknown lid, Bluetooth and Bluetooth LE precedence, multiple headsets, missing devices, wired/wireless/legacy Continuity transports, USB exclusion, ambiguous choices, and persisted UID choices.
- 11 isolated lifecycle operations, including repeated Enable, Disable, Uninstall, re-enable, and Status. Tests use real temporary files, executable signature checks, and a simulated launchctl service to avoid modifying the working installation.
- AppleScript compilation, universal binary architecture checks, payload round-trip/SHA-256 checks, and personal-path/name/UID checks. The exact embedded extraction/status/cleanup command also passed.
- Apple `shortcuts sign --mode anyone` successfully produced the shareable shortcut.
- Both Apple silicon and Intel (under Rosetta) payloads successfully ran read-only status against real devices and selected the available Continuity microphone. These checks did not change microphone selection.

No automated test imports or executes the interactive shortcut, presents device-choice dialogs, changes the live default microphone, or tests login restart. Manual clean-machine validation is still required: import, enable, close/open lid, attach/detach Bluetooth, log out/in, disable, and uninstall. Test macOS 13 and a physical Intel Mac before claiming those configurations verified. The compiler warns that its compatibility-packs static archive lacks an Intel slice; both final slices link, but deployment testing remains necessary.

## Release status

Repository: [twyzeas/lidmic](https://github.com/twyzeas/lidmic). Released under the [MIT license](LICENSE). This initial preview retains the testing and signing limitations documented above.

## Event-based switching

The helper listens for IOPMrootDomain clamshell notifications and CoreAudio device-list, default-input, device-liveness and input-stream changes. All work runs on one serial queue. It evaluates immediately on startup and notifications, and every 10 seconds as a fallback (with 0.5-second timer tolerance). If a device is not ready, a notification triggers at most three retries at 0.25, 0.75 and 1.5 seconds; newer events cancel stale retries. Device subscriptions are reconciled after audio events and fallback checks; unchanged subscriptions are retained and queued audio notifications are coalesced. Failed listener registrations leave the fallback active.

`source/build/lid-microphone --measure` runs the same listeners in read-only mode and compares lid detection with a two-second reference polling timer. It prints local device names, evaluation time, and the event's lead over that timer. It does not change the default input or record audio. Stop with Control-C. The reference polling timer exists only in measurement mode. This measures scheduling and selection, not the time until an application receives usable audio, nor the physical lid-to-notification latency. Lid transitions must be separated by at least five seconds for comparison.

`test_watcher.py` validates immediate evaluation, bounded retries, cancellation after a newer event, and absence of a retry loop from the fallback. The existing selection, isolated lifecycle and package validations also pass for this update. Physical microphone readiness and sleep/wake need manual validation.

### Local timing result — 2026-10-14

Four real lid transitions on the development Mac were detected 208.4, 1702.6, 1417.4 and 1663.8 ms before a two-second reference timer (average 1248.1 ms). Read-only target evaluation took 1.17–1.80 ms. All four transitions arrived through the lid listener, with one audio notification evaluation per subsequent input change. The fallback ran every ten seconds. These small-sample results depend on timer phase; they are not a guarantee of end-to-end audio startup latency. The existing installed helper remained responsible for actual switching. The v0.2.0 shortcut contains the event-based helper.

## Shortcut menu repair

The shortcut and its dialogs are named **LidMic — Auto Switch Mic**. The menu says “Choose an action.” Enable, Disable and Uninstall use short confirmations such as “Microphone switching enabled.” Status shows the enabled state and current microphone. Errors retain only the problem and a next step. Its AppleScript uses an explicitly local `chosenAction` variable instead of `selection`, avoiding a host property name conflict. `test_shortcut.py` runs Status, Enable, Disable, Uninstall and Cancel with simulated dialogs and helper execution under the Shortcuts scripting terminology. These checks validate menu branching without changing the installed helper; interactive import and lifecycle checks on clean machines remain separate manual checks.

## Download filename and title

Distribute `lidmic-0.2.0.zip` containing only `LidMic — Auto Switch Mic.shortcut` at the archive root. The shortcut's filename, embedded workflow name and dialog titles use the same product title. macOS uses the filename in the import preview, so the version belongs on the outer ZIP. Users unzip the download and open the shortcut; no manual renaming is needed. The archive is checked for its single expected filename and byte-for-byte equality with the signed shortcut.

The v0.2.0 ZIP contains the event-based helper and revised dialogs. GitHub's automatically generated source archives are separate from the user download.

Disabling or uninstalling leaves the current default microphone selected. The confirmation points to System Settings → Sound when a different input is needed. Uninstall also tells the user they can delete the shortcut.
