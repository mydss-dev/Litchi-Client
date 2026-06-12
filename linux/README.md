# Linux

Linux 原生平台目录。

这里用于放置 Linux 专用工程文件，例如：

- CMake 配置
- GTK Runner
- Linux 桌面集成
- 系统代理 / TUN / 权限处理
- 打包配置

桌面端 Flutter UI 继续复用：

```text
lib/app/app_shell.dart
```

当前阶段先提交目录标记，后续 Linux 支持单独推进。