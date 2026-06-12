# Android MVP Plan

目标：先完成 Android 业务壳，不急着接 VPNService / sing-box 内核。

## 阶段 1：业务壳

验收标准：

- APK 可以构建。
- App 可以打开。
- OSS 远程配置可以加载并覆盖 API 域名。
- 登录 / 注册可用。
- token 可以保存。
- 有 token 时可以自动进入主界面。
- 服务器连接失败时可以进入本地缓存模式。
- 节点列表可以展示。
- 节点可以缓存。

## 阶段 2：Android UI 适配

- 去掉桌面窗口栏依赖。
- 适配手机宽度和安全区域。
- 侧边栏改为移动端导航。
- 首页、节点、套餐、账号页面适配竖屏。

## 阶段 3：连接能力

后续再做：

- Android VpnService 权限申请。
- Kotlin 原生 VPN 服务骨架。
- sing-box / libbox 接入。
- 启动 / 断开 / 切节点。
- 通知栏常驻。
- 后台保活。

## 分支策略

Android 相关改动全部在：

```text
feature/android-mvp
```

Windows 稳定版继续保留在 main。Android MVP 跑通后再开 PR 合并。

## 当前第一步

当前分支先做：

- 桌面窗口逻辑加平台保护。
- Android CI 自动生成 Android 平台文件并构建 debug APK。
- 保证 Flutter 业务代码可以参与 Android 编译。
