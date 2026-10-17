# DockPin publishing copy

These are prepared drafts for channels that require their own publishing account. Their presence here does not mean they have been posted. Directory submissions and their status are tracked in [OUTREACH.md](OUTREACH.md).

## Project links

- English website: https://kangaroo-demo.github.io/DockPin/
- Chinese website: https://kangaroo-demo.github.io/DockPin/zh/
- Source and stars: https://github.com/kangaroo-demo/DockPin
- Download: https://github.com/kangaroo-demo/DockPin/releases/latest/download/DockPin.zip
- Demo: https://raw.githubusercontent.com/kangaroo-demo/DockPin/main/docs/images/dockpin-demo.gif
- Share image: https://kangaroo-demo.github.io/DockPin/images/social-card.png

## V2EX / 中文介绍

标题：Mac 外接屏的 Dock 总跑错位置，做了个免费开源工具 DockPin

我的显示器是上下排列：外接屏在上，MacBook 在下。Dock 经常跑回下方的内置屏，用起来很打断思路，所以做了 DockPin。

它是一个原生 Swift 菜单栏小工具，可以选择目标显示器和 Dock 边缘。重新接上外接屏或唤醒 Mac 后，会重新应用保存的目标设置。退出 App 时会恢复系统默认行为。

免费、MIT 开源，支持 macOS 13+，有中英文界面。App 在本机运行，不需要账号，也不收集分析数据。

需要辅助功能权限。原理是观察和短暂调整边缘附近的鼠标移动；如果目标边缘被另一块屏幕完全覆盖，macOS 的公开能力可能无法可靠指定 Dock 位置。

介绍与演示：https://kangaroo-demo.github.io/DockPin/zh/

源码与下载：https://github.com/kangaroo-demo/DockPin

如果你也遇到这个困扰，欢迎试用和反馈显示器布局。觉得有用的话，欢迎点个 Star。

## r/macapps / English introduction

Title: I built DockPin, a free, open-source app to keep the macOS Dock on the display you choose

I use an external monitor above a MacBook, and the Dock kept ending up on the lower screen. DockPin is a small native Swift menu bar app that helps keep it on a selected display edge.

You choose a target monitor and a bottom, left, or right edge. It remembers the selection while the monitor is unplugged and reapplies it after reconnect or wake. Quitting restores the system's default behavior.

It is free, MIT-licensed, supports macOS 13+, and runs locally without an account or analytics. It needs Accessibility permission to observe and briefly adjust pointer movement near the display edge. There is a practical limitation: if another screen covers the entire selected edge, macOS may not allow reliable placement.

Demo and setup: https://kangaroo-demo.github.io/DockPin/

Source and downloads: https://github.com/kangaroo-demo/DockPin

I would appreciate feedback from other multi-monitor users, especially on stacked layouts. If it helps your setup, a GitHub star is welcome.

## Show HN

Title: Show HN: DockPin — keep the macOS Dock on a chosen display

URL: https://kangaroo-demo.github.io/DockPin/

Introduction: DockPin grew out of a stacked-monitor setup where the Dock kept moving to the lower MacBook screen. It is a native Swift menu bar app that uses public pointer-event APIs to help macOS use a selected display edge. It also reapplies the selection after monitor reconnect or wake. It is free and MIT-licensed, requires macOS 13+ and Accessibility permission, and makes no network requests from the app. Fully covered display edges remain a limitation. Source: https://github.com/kangaroo-demo/DockPin

## Short post / 短介绍

Mac 外接屏在上、笔记本在下，Dock 却总跑错屏？DockPin 是一个免费开源的小工具，帮助 Dock 留在选定显示器上。原生 Swift、中英文界面，支持重接屏和唤醒后自动恢复。演示与下载：https://kangaroo-demo.github.io/DockPin/zh/

Dock on the wrong monitor? DockPin helps keep it on the display you choose. Free, open-source, native Swift, with automatic reapplication after reconnect or wake. Demo and download: https://kangaroo-demo.github.io/DockPin/
