# DockPin

DockPin 是一个免费开源的 macOS 菜单栏小工具。打开时它会帮助 Dock 停留在你选择的显示器上，退出时还原系统默认行为。

它主要解决多显示器场景里 Dock 跑错屏的问题，尤其是上下排列显示器时，比如外接屏在上方、MacBook 内置屏在下方。

[下载 DockPin.zip](https://github.com/kangaroo-demo/DockPin/releases/latest/download/DockPin.zip) · [所有版本](https://github.com/kangaroo-demo/DockPin/releases)

[English README](README.md)

## 它能做什么

- 作为轻量菜单栏 App 常驻运行。
- 可以选择目标显示器。
- 支持 Dock 的底部、左侧、右侧边缘。
- 在目标显示器的指定边缘做“软拦截”，帮助 macOS 把这条边当作 Dock 边缘，同时保留正常跨屏移动。
- 退出 DockPin 时会把 Dock 还原到系统默认的外侧显示器边缘。
- 可以调整边缘范围和穿透延迟。
- 支持开机自启动。
- 包含首次设置向导，用于说明 Gatekeeper 和辅助功能权限。
- 支持英文和简体中文界面。

## 它不能做什么

macOS 没有公开 API 可以直接把 Dock 指定到某个显示器。DockPin 不会修改 Dock、不改系统文件、不注入 Dock 进程，也不使用私有 API。

DockPin 的原理是使用 Quartz event tap 和辅助功能权限，在你选择的 Dock 边缘附近轻量限制鼠标移动，让 macOS 更容易把该显示器边缘视为 Dock 边缘。

## 安装

下载最新版 [`DockPin.zip`](https://github.com/kangaroo-demo/DockPin/releases/latest/download/DockPin.zip)，解压后把 `DockPin.app` 移到 `/Applications`。

第一次启动：

1. 打开 `DockPin.app`。
2. macOS 提示时授予辅助功能权限。
3. 如果菜单里显示“需要辅助功能权限”，打开 `系统设置 -> 隐私与安全性 -> 辅助功能`，启用 DockPin，然后退出并重新打开 DockPin。

### 如果 macOS 提示无法验证 DockPin

当前社区构建在维护者配置 Apple Developer ID 签名之前，可能是未签名或未公证的。macOS 如果提示“Apple 无法验证 DockPin”：

1. 点击“完成”，不要点“移到废纸篓”。
2. 打开 `系统设置 -> 隐私与安全性`。
3. 在“安全性”区域点击 DockPin 旁边的“仍要打开”。
4. 再次打开 DockPin，并选择“打开”。

你也可以从源码自行构建，这样可以避免下载包自带的 quarantine 标记。

## 使用

点击菜单栏里的 `DockPin`。

- `目标显示器`：选择 DockPin 运行时希望 Dock 优先停留的显示器。
- `Dock 边缘`：选择底部、左侧或右侧。
- 修改 `Dock 边缘` 也会同步修改 macOS 自己的 Dock 位置。
- `边缘范围`：选择 DockPin 观察目标边缘的范围。
- `穿透延迟`：选择鼠标继续滑动多久后放行到另一块屏幕。
- `开机自启动`：登录后自动启动 DockPin。
- 按住 `Option` 穿过目标边缘，可以立即放行。

打开 DockPin 后会自动生效。退出 DockPin 时会停止事件监听，并把 Dock 轻推回系统默认的外侧显示器边缘。

## 推荐设置

如果你的外接屏在上方、内置 Retina 屏在下方：

- 目标显示器：外接显示器
- Dock 边缘：底部
- 边缘范围：40%
- 穿透延迟：0.20 秒

## 从源码构建

要求：

- macOS 13 或更新版本
- Xcode Command Line Tools
- Swift 5.9 或更新版本

构建并打包：

```sh
git clone git@github.com:kangaroo-demo/DockPin.git
cd DockPin
./scripts/package_release.sh
open dist/DockPin.app
```

只列出显示器，不启动菜单栏 App：

```sh
swift run DockPin --list-displays
```

## 发布

推送版本 tag 后会自动创建 GitHub Release：

```sh
git tag -a v0.1.7 -m "DockPin 0.1.7"
git push origin v0.1.7
```

Release workflow 会在 macOS 上构建 `dist/DockPin.zip`，并上传到对应的 Release。如果配置了 Apple Developer secrets，也支持 Developer ID 签名和公证。见[签名与公证说明](docs/SIGNING_AND_NOTARIZATION.zh-CN.md)。

## 隐私

DockPin 不收集分析数据，不发起网络请求，也不存储个人数据。设置只通过 `UserDefaults` 保存在本机。

辅助功能权限只用于观察鼠标移动，并在目标边缘应用软拦截。

## 常见问题

### 菜单显示“需要辅助功能权限”

在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中启用 DockPin，然后退出并重新打开 DockPin。

### Dock 还是跑到错误的显示器

尝试调大“边缘范围”或“穿透延迟”。同时确认 `Dock 边缘` 和 macOS 系统设置里的 Dock 位置一致。

在上下排列的屏幕布局中，DockPin 会使用目标显示器边缘上没有被另一块屏幕覆盖的真实外边缘。如果另一块屏幕完全覆盖了所选边缘，macOS 公开能力下可能无法稳定强制这条边缘。

### 鼠标不容易移动到另一块屏幕

调低“边缘范围”、调低“穿透延迟”、从未观察的边缘区域穿过，或者按住 `Option` 穿过。

## 许可证

MIT
