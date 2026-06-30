# macOS

macOS 支持系统代理与 TUN 两种连接方式。

- 系统代理模式以当前用户身份运行 mihomo。
- TUN 模式通过 macOS 系统授权启动一次性的管理员进程。
- 管理员进程运行在隔离的临时目录，不会在用户数据目录留下 root 文件。
- root 看门狗同时监听客户端 PID 和停止文件；正常断开无需再次输入密码，
  客户端强退后也会自动结束 mihomo。
- 客户端只有在控制 API 可用且检测到新 `utun` 接口后才显示已连接。

当前方案面向官网 DMG 分发，不依赖 App Sandbox、Network Extension entitlement
或常驻特权 Helper。正式发布前仍需在 Intel 与 Apple Silicon 真机验证系统授权、
睡眠唤醒、切网和强退清理。
