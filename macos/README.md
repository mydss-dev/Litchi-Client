# macOS

macOS 原生平台目录。

这里用于放置 macOS 专用工程文件，例如：

- Xcode Runner 工程
- Info.plist
- Swift / Objective-C 原生代码
- Network Extension
- Packet Tunnel Provider
- App Sandbox / 权限配置
- DMG / 签名 / 公证配置

桌面端 Flutter UI 继续复用：

```text
lib/app/app_shell.dart
```

当前阶段先提交目录标记，后续 macOS MVP 单独分支继续推进。