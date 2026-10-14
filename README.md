# LidMic

[![Downloads](https://img.shields.io/github/downloads/twyzeas/lidmic/total)](https://github.com/twyzeas/lidmic/releases)
[![Latest release](https://img.shields.io/github/v/release/twyzeas/lidmic)](https://github.com/twyzeas/lidmic/releases/latest)
[![License](https://img.shields.io/github/license/twyzeas/lidmic)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Apple Shortcuts](https://img.shields.io/badge/Apple-Shortcuts-purple)
![Preview](https://img.shields.io/badge/status-preview-orange)

Automatically switch between your MacBook mic, iPhone Continuity mic, and Bluetooth headset.

[![Download Shortcut for macOS](assets/download-shortcut.svg)](https://github.com/twyzeas/lidmic/releases/latest)

## Features

- Bluetooth headset connected → use its mic.
- Otherwise, lid closed → use the iPhone mic through Continuity Camera.
- Otherwise, lid open → use the MacBook mic.
- Preferred mic unavailable? Keep the current mic and retry.
- Runs in the background and starts at login. No audio recording.

## Install

1. Download and double-click the `.shortcut` file to import it.
2. In **Shortcuts → Settings → Advanced**, enable **Allow Running Scripts**.
3. Run **LidMic** and choose **Enable**.
4. Set your calling apps to use the **system-default microphone**.

Run it again for **Status**, **Disable**, or **Uninstall**. To remove it, choose **Uninstall** before deleting the shortcut.

Preview: the shortcut is signed for sharing; its helper is not notarized. [Testing and release notes](BUILDING.md).

## Compatibility

- MacBook with macOS 13+; Apple silicon and Intel builds included.
- iPhone available through [Continuity Camera](https://support.apple.com/en-us/102546).
- Bluetooth and Bluetooth LE headsets, including AirPods.
- USB-dongle headsets do not get Bluetooth priority.
- Older macOS versions, physical Intel Macs, and first-run import still need testing.
