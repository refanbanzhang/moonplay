# sleep

一个最小可读的 macOS 原生 Hello World 示例，使用 SwiftUI 构建。

## 打开方式

在安装了完整 Xcode 的机器上，直接打开：

- `sleep.xcodeproj`

然后选择 `sleep` target，点击 Run 即可。

## 打包（Release）

在项目根目录执行：

```bash
xcodebuild -scheme sleep -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO
```

成功后可直接使用的应用位于：

- `build/DerivedData/Build/Products/Release/sleep.app`

也可将 `sleep.app` 复制到任意目录或压缩为 zip 分发。当前仓库已生成一份便于拷贝的产物：

- `dist/sleep.app` — 可直接双击运行（本机构建）
- `dist/sleep.zip` — 便于分享

说明：上述命令关闭了代码签名，适合本机或内网使用。若需对外分发并减少「已损坏」提示，请在 Xcode 中配置 **Signing & Capabilities**（Apple Developer 账号），再用 Archive 导出已签名的 app。

## 代码位置

- `SleepApp.swift`
- `ContentView.swift`
- `Info.plist`
