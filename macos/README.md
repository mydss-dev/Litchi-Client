# macOS

macOS 通过进程内 sing-box 通用动态库运行。

- 系统代理模式使用 `networksetup`。
- TUN 模式需要应用具备对应网络权限。
- 客户端只有在控制 API 可用且检测到新 `utun` 接口后才显示已连接。
- 发布脚本会把 Intel/Apple Silicon 核心合并为通用动态库。

正式发布前需在 Intel 与 Apple Silicon 真机验证 TUN 权限、睡眠唤醒、
切网和异常退出清理。
