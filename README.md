# LidMic

[![Downloads](https://img.shields.io/github/downloads/twyzeas/lidmic/total)](https://github.com/twyzeas/lidmic/releases)
[![Latest release](https://img.shields.io/github/v/release/twyzeas/lidmic)](https://github.com/twyzeas/lidmic/releases/latest)
[![License](https://img.shields.io/github/license/twyzeas/lidmic)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue)

A macOS automation that switches the default microphone to your iPhone’s Continuity Camera while the MacBook’s lid is closed.

<a href="https://github.com/twyzeas/lidmic/releases/latest"><img src="assets/download-shortcut.svg" alt="Download Shortcut for macOS" width="186" height="60"></a>

## Features

- Switches the default microphone to your iPhone’s Continuity Camera when the MacBook is in clamshell mode.
- Restores the MacBook’s built-in microphone when the lid is reopened.
- AirPods and other Bluetooth headsets take priority when connected.

## Install

1. Download and unzip `lidmic-0.2.0.zip`, then open **LidMic — Auto Switch Mic.shortcut** to import it.
2. In **Shortcuts → Settings → Advanced**, enable **Allow Running Scripts**.
3. Run **LidMic — Auto Switch Mic** and choose **Enable**.
4. Set your calling apps to use the **system-default microphone**.

Run it again for **Status**, **Disable**, or **Uninstall**. To remove it, choose **Uninstall** before deleting the shortcut. Disabling or uninstalling leaves your current microphone selected.

Preview: the shortcut is signed for sharing; its helper is not notarized. [Build and testing details](BUILDING.md).

## Compatibility

- MacBook with macOS 13+; Apple silicon and Intel builds included.
- iPhone available through [Continuity Camera](https://support.apple.com/en-us/102546).
- Bluetooth and Bluetooth LE headsets, including AirPods.
- USB-dongle headsets do not get Bluetooth priority.
- Older macOS versions, physical Intel Macs, and first-run import still need testing.
