<p align="center">
  <img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/icon.png" width="112" height="112" alt="FancyTool 图标">
</p>

<h1 align="center">FancyTool</h1>

<p align="center">让 macOS 菜单栏更顺手，也更有趣。</p>

<p align="center">简体中文 · <a href="README.en.md">English</a></p>

<p align="center">
  <a href="https://github.com/m-finder/FancyTool/releases">下载 FancyTool</a> ·
  <a href="#快速开始">开始使用</a> ·
  <a href="https://github.com/m-finder/FancyTool/issues">反馈问题</a>
</p>

<p align="center">macOS 14.6+ · Swift / SwiftUI / AppKit · 免费开源</p>

FancyTool 把炫彩签名、剪贴板历史、系统监控、聚合控制和截图等常用工具放进菜单栏，也提供动态图标和状态小狗。各模块可按需启用，目标是做一个轻量、实用、有趣的 Mac 小工具。

## 实际效果

以下为当前开发版本的实际界面。点击图片可查看原图。

<table>
  <tr><th>炫彩签名 · Texter</th><th>系统监控 · Monitor</th><th>聚合控制 · Duo</th></tr>
  <tr><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/texter@2x.png" width="300" alt="炫彩签名弹窗与配色设置"></a></td><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/monitor@2x.png" width="270" alt="系统监控实时面板"></a></td><td align="center" valign="top"><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/duo@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/duo@2x.png" width="292" alt="聚合控制中的 Wi-Fi、蓝牙、声音、显示器和输入法"></a></td></tr>
</table>

### 剪贴面板与截图工具

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/paster@2x.png" width="960" alt="支持搜索和置顶的剪贴记录"></a></p>

<p><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/shotter@2x.png" width="680" alt="带标注工具栏的截图编辑器"></a></p>

### 设置界面

<table>
  <tr><th>通用</th><th>动态图标</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-universal@2x.png" width="420" alt="通用设置"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-runner@2x.png" width="420" alt="动态图标与状态小狗设置"></a></td></tr>
</table>

<details>
<summary>展开其他设置截图</summary>

<table>
  <tr><th>炫彩签名</th><th>系统监控</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-texter@2x.png" width="420" alt="炫彩签名外观设置"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-monitor@2x.png" width="420" alt="监控项目设置"></a></td></tr>
  <tr><th>聚合控制</th><th>剪贴面板</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-duo@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-duo@2x.png" width="420" alt="聚合控制菜单栏设置"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-paster@2x.png" width="420" alt="剪贴面板设置"></a></td></tr>
  <tr><th>截图工具</th><th>屏幕圆角</th></tr>
  <tr><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-shotter@2x.png" width="420" alt="截图快捷键设置"></a></td><td><a href="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png"><img src="https://raw.githubusercontent.com/m-finder/FancyToolApp/main/doc/screenshots/settings-rounder@2x.png" width="420" alt="屏幕圆角设置"></a></td></tr>
</table>

</details>

界面会随 macOS 版本和系统外观变化。macOS 27 不提供菜单栏折叠模块，因此未展示 Hidder 截图。

## 功能概览

| 模块 | 功能 |
| --- | --- |
| **炫彩签名 · Texter** | 编辑菜单栏签名，选择字体与渐变配色；可设置流光、圆角或彩虹外框、自定义外框颜色与渐变背景。 |
| **剪贴面板 · Paster** | 保存文字与图片历史，支持置顶、条数与 256 MB 总量限制、按内容或来源应用搜索，以及可选的自动粘贴。 |
| **系统监控 · Monitor** | 按需显示 CPU、内存、存储、电池和网速，支持紧凑布局；弹窗提供实时数值与趋势图。 |
| **聚合控制 · Duo** | 在一个菜单栏入口查看电池、Wi-Fi 和声音状态，调节蓝牙、音量与显示外观，并选择 Wi-Fi 网络、已配对设备及输入法。 |
| **截图工具 · Shotter** | 截取区域、窗口或整屏，显示选区像素尺寸；支持形状、箭头、画笔、荧光笔、文字、序号及实心遮挡，可调整颜色、线宽和字号，移动或删除标注，撤销、重做、置顶、复制和保存原始分辨率 PNG。 |
| **动态图标 · Runner** | 拖入自定义 GIF，导入时按显示尺寸处理并限制文件大小与帧数，可按 CPU 使用率调整播放速度；状态小狗会随忙碌、充电和空闲状态切换动作，也会在截图复制或签名修改后短暂回应。 |
| **屏幕圆角 · Rounder** | 为屏幕边缘添加可调节的圆角。 |
| **菜单栏折叠 · Hidder** | 通过圆点标记收起或展开菜单栏图标，仅在 macOS 27 以下提供。 |

界面支持简体中文、英语、日语、韩语、德语和法语。应用每天自动检测一次更新，也可从菜单手动检测；发现新版本时会在菜单栏提示。

## 快速开始

1. 从 [Releases](https://github.com/m-finder/FancyTool/releases) 下载应用，将 FancyTool 放入「应用程序」后启动。
2. 在菜单栏打开 FancyTool 菜单，启用需要的模块。
3. 打开「设置」，按需调整签名、监控、剪贴板、截图快捷键和动态图标。

### 常用操作

| 场景 | 操作 |
| --- | --- |
| 打开剪贴面板 | `⇧⌘C`，可在设置中修改 |
| 开始截图 | `⇧⌘S`，可在设置中修改 |
| 聚焦剪贴面板搜索 | `⌘F`；多个关键词用空格分隔 |
| 剪贴面板翻页 | `Tab` / `⇧Tab` |
| 选择当前页的剪贴记录 | `⌘1`–`⌘5` |
| 确认签名并关闭弹窗 | 在 Texter 输入框中按 `Return` |
| 关闭签名、监控或聚合控制弹窗 | 再次点击入口、点击弹窗外部或按 `Esc` |
| 截图标注撤销 / 重做 | `⌘Z` / `⇧⌘Z` |
| 截图选区辅助 | 拖动时按住 `Shift` 框选正方形，按住 `Space` 移动选区；选区界面按 `Return` 截取鼠标所在屏幕 |
| 编辑截图标注 | `V` 选择或移动标注；选中后按 `Delete` 删除，方向键微调位置 |
| 复制 / 保存截图 | 编辑界面按 `⌘C` 或 `Return` 复制，按 `⌘S` 保存 PNG；输入文字时 `Return` 用于确认文字 |
| 与状态小狗互动 | 左键转圈，右键打开菜单 |

截图编辑时，工具栏提供配色、线宽和字号；选中已有标注后也可修改样式。再次点击当前绘图工具可返回选择模式，双击文字可继续编辑。复制或保存时，标注与实心遮挡会一起合成为图片。

### 按需授权

| 功能 | 所需权限 |
| --- | --- |
| 截图 | 「屏幕录制」权限 |
| 剪贴面板的「自动粘贴」 | 「辅助功能」权限；未启用时仍可复制记录，再手动粘贴 |
| Duo 附近的 Wi-Fi 网络列表 | 「定位服务」权限，打开网络列表时申请 |
| Duo 已配对蓝牙设备 | 「蓝牙」权限，打开设备列表时申请 |

可在 macOS「系统设置 → 隐私与安全性」中管理权限。

## 系统支持

| 系统版本 | 说明 |
| --- | --- |
| **macOS 14.6 及以上** | 应用最低运行要求 |
| **macOS 26 及以上** | Texter、系统监控、聚合控制和剪贴面板使用系统原生玻璃材质；较早版本使用兼容外观 |
| **macOS 27 及以上** | 菜单栏折叠模块自动隐藏并停用 |

## 从源码构建

使用包含 **macOS 26 SDK 或更新 SDK** 的 Xcode。项目使用 Swift 6，依赖由 Swift Package Manager 解析。

```sh
git clone https://github.com/m-finder/FancyTool.git
cd FancyTool
open FancyTool.xcodeproj
```

在 Xcode 中选择 `FancyTool` scheme，按本机环境配置 Signing 后运行。仅检查编译时，也可以执行：

```sh
xcodebuild -project FancyTool.xcodeproj \
  -scheme FancyTool \
  -configuration Debug \
  -sdk macosx \
  build CODE_SIGNING_ALLOWED=NO
```

## 支持项目

FancyTool 免费开源。如果它对你有帮助，欢迎反馈建议，或[请作者喝杯咖啡 ☕️](https://www.ifdian.net/a/m-finder)。

<details>
<summary>感谢支持者</summary>

| 姓名 | 金额 | 时间 | 留言 |
| --- | --- | --- | --- |
| *龙 | ¥ 10.00 | 2025-08-27 15:00:00 | ☕️ |
| *豪 | ¥ 50.00 | 2025-09-02 23:12:00 | — |
| *强 | ¥ 5.00 | 2025-11-01 11:55:00 | 还不错 |

</details>

## License

FancyTool is open-source software licensed under the MIT license.
