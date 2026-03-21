# sleep

一个最小可读的 macOS 原生 Hello World 示例，使用 SwiftUI 构建。

## 打开方式

在安装了完整 Xcode 的机器上，直接打开：

- `sleep.xcodeproj`

然后选择 `sleep` target，点击 Run 即可。

## 打包（Release，本地用）

在项目根目录执行（会打 **Release**，并生成 **DMG + zip** 到 `dist/`，不含公证）：

```bash
./scripts/package.sh        # 默认版本号段为 v1
./scripts/package.sh 1.0.1  # 可传入版本号，文件名会带 v1.0.1-时间戳
```

产物示例：

- `dist/sleep-v1-20260321-xxxx.dmg` — 内含 `sleep.app` 与 **Applications** 快捷方式，拖入即可安装
- `dist/sleep-v1-20260321-xxxx.zip` — 解压后得到 `sleep.app`

Xcode 直接编译产物路径：

- `build/DerivedData/Build/Products/Release/sleep.app`

说明：适合本机使用；若首次打开被拦截，可在 **系统设置 → 隐私与安全性** 里点「仍要打开」，或在 app 上右键 **打开**。

## 代码位置

- `SleepApp.swift`
- `ContentView.swift`
- `Info.plist`
