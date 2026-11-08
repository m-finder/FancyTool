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

FancyTool brings colorful text, clipboard history, system monitoring, and screenshots to your menu bar, along with animated icons and a status dog. Enable the modules you need for a lightweight, practical Mac utility with a little personality.

## Screenshots

These screenshots show the development version running on macOS. Images retain their original Retina **2× resolution** and are saved as PNGs. Click an image to view it at full size; only its display size is reduced here.

<table>
  <tr><th>Colorful text · Texter</th><th>System monitor · Monitor</th></tr>
  <tr>
    <td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png" width="350" alt="Texter panel with text input, shimmer switches, and a color palette"></a></td>
    <td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png" width="270" alt="Monitor panel with CPU, memory, storage, battery, and network measurements and charts"></a></td>
  </tr>
</table>

Texter uses sample text, while Monitor shows live measurements with the local network address hidden. The clipboard panel contains demonstration text and images. Appearance varies with the macOS version and system theme; features in a published build are described in its release notes.

### Menu bar monitoring

The **Colored icons** setting changes only the monitoring icons in the menu bar. Values and the monitor panel retain their existing colors. These images preview the native menu bar content.

<table>
  <tr><th>Colored icons</th><th>Default colors</th></tr>
  <tr>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor-menubar-color@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor-menubar-color@2x.png" width="297" alt="Colored CPU, memory, storage, battery, and network icons"></a></td>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor-menubar-default@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor-menubar-default@2x.png" width="297" alt="Monitoring icons using the default color"></a></td>
  </tr>
</table>

### Clipboard and screenshot tools

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png" width="960" alt="Clipboard panel with search, pinned items, text and image cards, and keyboard shortcuts"></a></p>

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png" width="680" alt="Screenshot editor with rectangle, arrow, and numbered annotations and a separate toolbar"></a></p>

### Settings

<table>
  <tr><th>General</th><th>Animated icons · Runner</th></tr>
  <tr>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png" width="420" alt="General settings for appearance, launch at login, and quitting"></a></td>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png" width="420" alt="Runner settings with GIF selection, custom icons, and the status dog"></a></td>
  </tr>
</table>

<details>
<summary>Show settings for other modules</summary>

<table>
  <tr><th>Colorful text</th><th>Clipboard</th></tr>
  <tr>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png" width="420" alt="Texter settings for font, size, shimmer, and rainbow shimmer"></a></td>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png" width="420" alt="Clipboard settings for history limits, shortcuts, and automatic paste"></a></td>
  </tr>
  <tr><th>System monitor</th><th>Screenshots</th></tr>
  <tr>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png" width="420" alt="Monitor settings with metric switches and colored icons"></a></td>
    <td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png" width="420" alt="Screenshot settings and shortcut"></a></td>
  </tr>
  <tr><th colspan="2">Rounded screen corners</th></tr>
  <tr><td colspan="2" align="center"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png" width="420" alt="Screen corner radius setting"></a></td></tr>
</table>

</details>

The screenshots were captured on macOS 27. Hidder is unavailable on that version and is therefore not shown.

## Features

| Module | Features |
| --- | --- |
| **Texter** | Edit menu bar text, choose gradient colors, and enable shimmer or rainbow shimmer. Select an installed font and font size in Settings. |
| **Paster** | Keep text and image clipboard history, pin items, set a history limit, search by content or source application, and optionally paste automatically. |
| **Monitor** | Show CPU, memory, storage, battery, and network metrics with optional colored menu bar icons. The panel includes five-minute CPU, memory, and network charts, storage and battery capacity charts, and charging status. |
| **Shotter** | Capture a region, window, or screen with pixel dimensions shown during selection. Add shapes, arrows, freehand strokes, highlights, text, numbers, and opaque redactions. Adjust colors, line widths, and font sizes; move or delete annotations; undo, redo, pin, copy, or save a full-resolution PNG. |
| **Runner** | Drop in custom GIFs and adjust playback speed with CPU usage. Enable the status dog to react to system load, charging, and inactivity, with smooth changes in animation speed. |
| **Rounder** | Add adjustable rounded corners to the screen. |
| **Hidder** | Collapse or expand menu bar icons using a dot marker. Available on macOS versions earlier than 27. |

The interface supports Simplified Chinese, English, Japanese, Korean, German, and French.

## Quick start

1. Download FancyTool from [Releases](https://github.com/m-finder/FancyTool/releases), move it to **Applications**, and launch it.
2. Open the FancyTool menu in the menu bar and enable the modules you need.
3. Open **Settings** to configure text fonts and sizes, monitoring metrics, clipboard history limits, shortcuts, animated icons, and the status dog.

### Common actions

| Action | How |
| --- | --- |
| Open the clipboard panel | `⇧⌘C`; configurable in Settings |
| Take a screenshot | `⇧⌘S`; configurable in Settings |
| Focus clipboard search | `⌘F`; separate search terms with spaces |
| Change clipboard page | `Tab` / `⇧Tab` |
| Select a clipboard item on the current page | `⌘1`–`⌘5` |
| Confirm text and close Texter | Press `Return` in the input field |
| Close Texter or Monitor | Click its menu bar item again, click outside the panel, or press `Esc` |
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

Manage these permissions in **System Settings → Privacy & Security**.

## System support

| macOS version | Details |
| --- | --- |
| **14.6 or later** | Minimum supported version |
| **26 or later** | Texter, Monitor, and Paster use native glass materials; earlier versions use a compatible appearance |
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
