# Moonplay

一个用于睡前播放音乐的 macOS 原生应用，使用 SwiftUI 构建。

## 打开方式

在安装了完整 Xcode 的机器上，直接打开：

- `Moonplay.xcodeproj`

然后选择 `Moonplay` target，点击 Run 即可。

## 打包（Release，本地用）

在项目根目录执行（会打 **Release**，并生成 **DMG + zip** 到 `dist/`，不含公证）：

```bash
./scripts/package.sh        # 默认版本号段为 v1
./scripts/package.sh 1.0.1  # 可传入版本号，文件名会带 v1.0.1-时间戳
```

产物示例：

- `dist/Moonplay-v1-20260321-xxxx.dmg` — 内含 `Moonplay.app` 与 **Applications** 快捷方式，拖入即可安装
- `dist/Moonplay-v1-20260321-xxxx.zip` — 解压后得到 `Moonplay.app`

Xcode 直接编译产物路径：

- `build/DerivedData/Build/Products/Release/Moonplay.app`

说明：适合本机使用；若首次打开被拦截，可在 **系统设置 → 隐私与安全性** 里点「仍要打开」，或在 app 上右键 **打开**。

## 代码位置

- `MoonplayApp.swift`
- `ContentView.swift`
- `Info.plist`

## 网页版 Dock 快捷启动

安装一个可以放进 Dock 的网页版启动器：

```bash
./scripts/install-dock-launcher.sh
```

脚本会创建 `~/Applications/Moonplay Web.app` 并自动打开它。将这个 App 拖到 Dock 后，之后点击 Dock 图标即可启动网页版。
