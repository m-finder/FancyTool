<p align="center">
  <img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/icon.png" width="112" height="112" alt="FancyTool icon">
</p>

<h1 align="center">FancyTool</h1>

<p align="center">Make your macOS menu bar more useful—and more fun.</p>

<p align="center"><a href="README.md">简体中文</a> · English</p>

<p align="center">
  <a href="https://github.com/m-finder/FancyTool/releases">Download FancyTool</a> ·
  <a href="#quick-start">Get started</a> ·
  <a href="https://github.com/m-finder/FancyTool/issues">Report an issue</a>
</p>

<p align="center">macOS 14.6+ · Swift / SwiftUI / AppKit · Free and open source</p>

FancyTool brings colorful text, clipboard history, system monitoring, quick controls, and screenshots to your menu bar, along with animated icons and a status dog. Enable the modules you need for a lightweight, practical Mac utility with a little personality.

## Screenshots

Current development build. Click an image to view it at full size.

<table>
  <tr><th>Texter</th><th>Monitor</th><th>Duo</th></tr>
  <tr><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png" width="300" alt="Texter signature and color controls"></a></td><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png" width="270" alt="Live system monitoring panel"></a></td><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/duo@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/duo@2x.png" width="292" alt="Duo controls for Wi-Fi, Bluetooth, sound, display, and input source"></a></td></tr>
</table>

### Clipboard and screenshot tools

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png" width="960" alt="Clipboard history with search and pinned items"></a></p>

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png" width="680" alt="Screenshot editor with annotation tools"></a></p>

### Settings

<table>
  <tr><th>General</th><th>Runner</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png" width="420" alt="General preferences"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png" width="420" alt="Animated icon and status dog settings"></a></td></tr>
</table>

<details>
<summary>Show more settings screenshots</summary>

<table>
  <tr><th>Texter</th><th>Monitor</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png" width="420" alt="Signature appearance settings"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png" width="420" alt="Monitor metric settings"></a></td></tr>
  <tr><th>Duo</th><th>Paster</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-duo@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-duo@2x.png" width="420" alt="Duo menu bar settings"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png" width="420" alt="Clipboard settings"></a></td></tr>
  <tr><th>Shotter</th><th>Rounder</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png" width="420" alt="Screenshot shortcut settings"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png" width="420" alt="Screen corner radius setting"></a></td></tr>
</table>

</details>

The interface varies with your macOS version and appearance settings. Hidder is unavailable on macOS 27 and is not shown.

## Features

| Module | Features |
| --- | --- |
| **Texter** | Edit menu bar text, choose fonts and gradient colors, and add shimmer, a signature or rainbow border with a choice of direction, and a gradient background. |
| **Paster** | Keep text and image clipboard history, pin items, limit both item count and total size to 256 MB, search by content or source application, and optionally paste automatically. |
| **Monitor** | Show CPU, memory, storage, battery, and network speed as needed, with a compact menu bar layout and a panel of live values and charts. |
| **Duo** | See battery, Wi-Fi, and sound status in one menu bar item. Control Bluetooth, volume, and display appearance; choose Wi-Fi networks, paired devices, and input sources. |
| **Shotter** | Capture a region, window, or screen with pixel dimensions shown during selection. Add shapes, arrows, freehand strokes, highlights, text, numbers, and opaque redactions. Adjust colors, line widths, and font sizes; move or delete annotations; undo, redo, pin, copy, or save a full-resolution PNG. |
| **Runner** | Choose built-in animations or drop in custom GIFs, resized for display on import with file size and frame count limits, and adjust playback speed with CPU usage. The status dog reacts to system load, charging, inactivity, screenshot copies, and signature changes. |
| **Rounder** | Add adjustable rounded corners to the screen. |
| **Hidder** | Collapse or expand menu bar icons using a dot marker. Available on macOS versions earlier than 27. |

The interface supports Simplified Chinese, English, Japanese, Korean, German, and French. FancyTool checks for updates once a day, supports manual checks, and shows a menu bar notice when a new version is available.

## Quick start

1. Download FancyTool from [Releases](https://github.com/m-finder/FancyTool/releases), move it to **Applications**, and launch it.
2. Open the FancyTool menu in the menu bar and enable the modules you need.
3. Open **Settings** to configure signatures, monitoring, clipboard history, screenshot shortcuts, and animated icons.

### Common actions

| Action | How |
| --- | --- |
| Open the clipboard panel | `⇧⌘C`; configurable in Settings |
| Take a screenshot | `⇧⌘S`; configurable in Settings |
| Focus clipboard search | `⌘F`; separate search terms with spaces |
| Change clipboard page | `Tab` / `⇧Tab` |
| Select a clipboard item on the current page | `⌘1`–`⌘5` |
| Confirm text and close Texter | Press `Return` in the input field |
| Close Texter, Monitor, or Duo | Click its menu bar item again, click outside the panel, or press `Esc` |
| Undo / redo screenshot annotations | `⌘Z` / `⇧⌘Z` |
| Adjust a screenshot selection | Hold `Shift` to select a square or `Space` to move the selection while dragging; press `Return` to capture the screen under the pointer |
| Edit screenshot annotations | Press `V` to select or move an annotation, `Delete` to remove it, or arrow keys to nudge it |
| Copy / save a screenshot | Press `⌘C` or `Return` to copy, or `⌘S` to save a PNG; while entering text, `Return` confirms the text |
| Interact with the status dog | Left-click to spin; right-click to open the menu |

The screenshot toolbar provides colors, line widths, and font sizes. Select an existing annotation to change its style. Click the active drawing tool again to return to selection mode, or double-click text to edit it. Copying or saving flattens annotations and opaque redactions into the image.

### Permissions

| Feature | Required permission |
| --- | --- |
| Screenshots | Screen Recording |
| Clipboard automatic paste | Accessibility; without it, you can still copy a history item and paste manually |
| Nearby Wi-Fi networks in Duo | Location Services, requested when you open the network list |
| Paired Bluetooth devices in Duo | Bluetooth, requested when you open the device list |

Manage these permissions in **System Settings → Privacy & Security**.

## System support

| macOS version | Details |
| --- | --- |
| **14.6 or later** | Minimum supported version |
| **26 or later** | Texter, Monitor, Duo, and Paster use native glass materials; earlier versions use a compatible appearance |
| **27 or later** | Hidder is automatically hidden and disabled |

## Build from source

Use Xcode with the **macOS 26 SDK or later**. The project uses Swift 6 and resolves dependencies through Swift Package Manager.

```sh
git clone https://github.com/m-finder/FancyTool.git
cd FancyTool
open FancyTool.xcodeproj
```

Select the `FancyTool` scheme, configure signing for your environment, and run. To check compilation without signing:

```sh
xcodebuild -project FancyTool.xcodeproj \
  -scheme FancyTool \
  -configuration Debug \
  -sdk macosx \
  build CODE_SIGNING_ALLOWED=NO
```

## Support the project

FancyTool is free and open source. Feedback is welcome. You can also [buy the author a coffee ☕️](https://www.ifdian.net/a/m-finder).

<details>
<summary>Thank you to our supporters</summary>

| Name | Amount | Date | Message |
| --- | --- | --- | --- |
| *龙 | ¥10.00 | 2025-08-27 15:00:00 | ☕️ |
| *豪 | ¥50.00 | 2025-09-02 23:12:00 | — |
| *强 | ¥5.00 | 2025-11-01 11:55:00 | Pretty good |

</details>

## License

FancyTool is open-source software licensed under the MIT license.
