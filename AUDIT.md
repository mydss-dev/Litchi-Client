# Litchi Client 项目审计报告

**审计日期：** 2026-06-11  
**审计范围：** 全量代码 · ~7,000 行 Dart · 72 个文件  
**项目类型：** Flutter Windows VPN/代理客户端（机场定制客户端）

---

## 一、整体评价

**当前状态：可继续开发但尚不能上线**

判断依据：

1. 账户页「登录记录」展示的是 `MockData.loginRecords` 假数据，真实用户看到的是虚假安全信息——P0 级别功能缺陷
2. 商城和账户页价格/余额货币符号 `¥` 全部硬编码，不走已有的 `getCommCurrencySymbol()` 接口
3. 没有忘记密码流程，生产环境缺少这个入口无法接受
4. 节点收藏仅存内存，页面重建即丢失
5. 没有任何 CI/CD 或构建流程，版本仍是 `1.0.0+1`

架构质量：高于平均水平。分层清晰（`AppController` → `CoreController`/`PanelApi`/`DataLoader`），model 三层分离（DTO → Mapper → ViewModel），自定义设计系统完整。核心问题是功能对接的完整性，不是架构腐烂。

---

## 二、核心问题清单

| 状态 | 优先级 | 问题类型 | 问题描述 | 影响 | 建议处理方式 |
|------|--------|---------|---------|------|------------|
| ✅ 已完成 | P0 | 功能缺陷 | `api_client.dart` 网络错误直接抛 DioException 原始信息 | 用户看到英文错误堆栈 | 封装 `_friendlyMessage()` 转中文 |
| ✅ 已完成 | P0 | 功能缺陷 | `data_loader.dart` 所有 `catch(_){}` 静默失败 | 用户数据加载失败无感知 | 增加 `criticalError` 传播 + ErrorBanner |
| ✅ 已完成 | P0 | 功能缺陷 | `dashboard_page.dart` 1002 行单文件无法维护 | 任何修改都高风险 | 拆分为 6 个 Widget 文件 |
| ✅ 已完成 | P0 | 功能缺陷 | 登录错误提示不完整，无法区分密码错误/账号不存在 | 用户不知道如何处理 | 透传后端 message 字段 |
| ✅ 已完成 | P0 | 功能缺陷 | 注册未限制邮箱后缀（面板开启白名单时） | 用户用无效邮箱注册报错 | 接 `email_whitelist_suffix` + 后缀下拉 |
| ✅ 已完成 | P1 | 工程化 | API base URL 硬编码，无法多环境部署 | 换域名需重新编译 | 改为 `--dart-define` 注入 |
| ✅ 已完成 | P1 | 体验 | 流量图表 tooltip 在 30天/90天 模式下被裁切 | 数据无法完整显示 | `fitInsideHorizontally/Vertically: true` |
| ✅ 已完成 | P0 | 功能缺陷 | `account_page.dart:358` 登录记录展示 `MockData.loginRecords` 假数据 | 用户看到虚假安全信息 | 接入 `/user/login/log` 真实 API |
| ✅ 已完成 | P0 | 功能缺失 | 没有忘记密码入口 | 忘记密码的用户无法自助恢复 | 新增 `forgot_password_page.dart`，两步流程（发码+重置） |
| ✅ 已完成 | P0 | 功能缺失 | 节点收藏不持久化（`_favorites = {}` 内存状态） | 每次重启收藏丢失 | `SettingsService.saveFavorites` + `SharedPreferences` |
| ✅ 已完成 | P1 | 数据错误 | 商城/账户余额货币符号 `¥` 全部硬编码 | 不支持非人民币面板 | `AppController.currencySymbol` 动态获取并透传 |
| ✅ 已完成 | P1 | 数据错误 | 商城「省 10%/省 20%」折扣是硬编码，不是根据实际价格计算 | 价格不准确 | `_computeSavings()` 按实际月/季/年价格计算 |
| ✅ 已完成 | P1 | 性能问题 | `AppController.notifyListeners()` 每秒被流量监控触发，全部 Widget 树重建 | 帧率抖动，CPU 浪费 | 流量数据改为独立 `ValueNotifier`，`ConnectionStatsRow` 改用 `ValueListenableBuilder` |
| ✅ 已完成 | P1 | 魔法字符串 | `'全局模式'/'直连模式'` 中文字符串用作模式逻辑判断 | 重构或国际化时极易断裂 | 改为 `enum ProxyMode`，覆盖 6 个文件 |
| ✅ 已完成 | P1 | 稳定性 | 初始化时 Token 失效静默清空，无任何提示 | 用户无感知被踢出 | `_startupMessage` 传递到 `LoginPage` 显示 toast |
| ✅ 已完成 | P1 | 工程化 | 无 CI/CD、无构建脚本、无版本管理 | 发布流程全靠手工，容易出错 | `.github/workflows/ci.yml`（analyze + build-windows），版本升至 `1.1.0+2` |
| ✅ 已完成 | P2 | 功能缺失 | 没有公告/通知系统（`/user/notice/fetch`） | 机场无法通知用户维护/公告 | `NoticeBanner` + `NoticeDetailDialog`，持久化已读状态，登录后加载 |
| ✅ 已完成 | P2 | 功能缺失 | 没有工单/客服入口 | 用户报障无途径 | 完整 `TicketsPage`：列表 + 创建 + 查看消息 + 回复 + 关闭，侧边栏新增入口 |
| ✅ 已完成 | P2 | 体验问题 | TUN 模式 UI 已有但 sing-box 配置层未验证是否真正启用 | 用户切换 TUN 可能无效 | 修复视觉状态 bug（选中后会反选）；保留 toast 说明不可用 |

---

## 三、功能对接完整性

### 已完整对接 ✅

| 功能 | 实现文件 | 备注 |
|------|---------|------|
| 登录 | `login_page.dart` → `panel_api.dart` | 含错误提示、记住密码 |
| 注册 | `register_page.dart` → `panel_api.dart` | 含邮箱后缀限制 |
| 修改密码 | `change_password_page.dart` | 完整 |
| Token 持久化 | `token_storage.dart` + DPAPI | Windows 加密存储 |
| 用户信息 | `data_loader.dart` + `account_page.dart` | 双路获取 |
| 订阅/节点拉取 | `subscription_parser.dart` | V2B + Base64 URI + YAML |
| 延迟测速 | `latency_tester.dart` + Clash API | 双模式（连接中/未连接） |
| 套餐列表 | `shop_page.dart` | 三分类 + 周期切换 |
| 下单流程 | `order_confirm_dialog.dart` | 含优惠券验证 |
| 支付流程 | `payment_dialog.dart` | QR + 跳转 + 余额扣款 |
| 订单列表/取消 | `orders_page.dart` | 完整含状态机 |
| 邀请/佣金信息 | `invite_page.dart` | 已接真实 API |
| 流量统计图表 | `traffic_page.dart` | 30/90/7天模式 |
| 连接状态/流量监控 | `core_controller.dart` | Clash API stream |
| Windows 系统代理 | `proxy_setter.dart` | 注册表读写 |
| 自启动 | `auto_start.dart` | 注册表 |
| 日志导出 | `core_controller.exportLogs()` | 写入 LOCALAPPDATA |
| 数据加载错误提示 | `error_banner.dart` + `data_loader.criticalError` | 含重试按钮 |

### 假数据 / Mock 状态 ⚠️（需修复才能上线）

| 功能 | 问题位置 | 问题描述 | 对应真实 API |
|------|---------|---------|------------|
| **登录记录** | `account_page.dart:358` | `MockData.loginRecords` 展示给真实用户 | `GET /user/login/log` |
| **节点收藏** | `nodes_page.dart:29` | 内存状态，重建即丢失 | 无 API，应本地持久化 |
| **货币符号** | `shop_page.dart`、`account_page.dart` | 硬编码 `¥`，已有接口未用 | `/user/comm/config` 的 `currency_symbol` |
| **套餐折扣提示** | `shop_page.dart:103` | `'省 10%'/'省 20%'` 硬编码 | 应按实际价格计算 |

### 完全缺失的功能 ❌

| 功能 | 重要程度 | V2Board API | 说明 |
|------|---------|------------|------|
| **忘记密码** | 极高 | `POST /passport/comm/sendEmailVerify` + `POST /passport/auth/forget` | 生产必备 |
| **邮件验证码注册** | 高 | `POST /passport/comm/sendEmailVerify` | 后端开启时需要 |
| **公告/通知** | 高 | `GET /user/notice/fetch` | 机场运营必需 |
| **工单/客服** | 中 | `GET/POST /user/ticket/*` | 建议至少外链 |
| **充值钱包** | 中 | 余额套餐下单 | ✅ 已完成（`_RechargeDialog` + `submitRechargeOrder`） |
| **设备管理** | 低 | 已拿到 `aliveIp`/`deviceLimit` 数据 | ✅ 已完成（展示在 `traffic_page.dart` 统计卡片） |

---

## 四、命名规范问题

| 当前命名 | 问题 | 推荐命名 | 状态 |
|---------|------|---------|------|
| `'全局模式'/'直连模式'/'规则模式'` | 中文字符串做逻辑判断 | `enum ProxyMode { global, rule, direct }` | ✅ 已完成 |
| `DataSnapshot` | 与 Firebase 同名，易混淆 | `AppDataSnapshot` | ⬜ 待完成 |
| `page_status_cards.dart` | 存放多种通用组件，职责混乱 | 改名 `page_shared_widgets.dart` | ⬜ 待完成 |
| `mock_data.dart` 位置 | 在 `shared/models/` 下，Mock 不是 model | 移到 `shared/dev/mock_data.dart` | ⬜ 待完成 |

---

## 五、代码质量关键问题

### 1. 登录记录展示假数据（P0）

**位置：** `lib/features/account/account_page.dart:358`

```dart
// 当前（错误）
final records = MockData.loginRecords;
```

真实登录用户看到的是假的 IP / 设备 / 时间信息。用户以为账号没有异常，实际可能已被入侵。

**修复：** 调用 `/user/login/log`，没数据时显示「暂无记录」，接口报错时隐藏该卡片。

---

### 2. 全局状态每秒全量重建（P1）

**位置：** `lib/app/core_controller.dart:270`

```dart
_trafficSub = SingboxApiClient.trafficStream(...).listen((t) {
  _upBps = t.upBps;
  _downBps = t.downBps;
  notifyListeners(); // 每秒触发，全部 Widget 树重建
});
```

连接状态下每秒触发 `AppController.notifyListeners()`，包括商城、节点、设置等无关页面全部重建。

**修复：** `upBps`/`downBps` 提取为独立 `ValueNotifier<int>`，`ConnectionStatsRow` 直接监听。

---

### 3. ProxyMode 魔法字符串（P1）

**位置：** `lib/app/core_controller.dart:204`

```dart
static String _toClashMode(String mode) => switch (mode) {
  '全局模式' => 'global',
  '直连模式' => 'direct',
  _ => 'rule',
};
```

中文字符串在 5 个文件中流转，拼写错误静默走到 `'rule'` 分支，无编译检查。

**修复：** 定义 `enum ProxyMode { global, rule, direct }`，仅 UI 层转中文标签。

---

### 4. Token 失效静默登出（P1）

**位置：** `lib/app/app_controller.dart:181`

```dart
} catch (_) {
  await TokenStorage.clearAuthData(); // 无任何用户提示
  _apiClient.updateAuthData(null);
}
```

**修复：** 存一个 flag 到 SharedPreferences，App 启动后检测到 token 被清除则 toast 提示。

---

### 5. 节点收藏无持久化（P0）

**位置：** `lib/features/nodes/nodes_page.dart:29`

```dart
final Set<String> _favorites = {}; // State 内字段，重建即清空
```

**修复：** `SettingsService` 增加 `saveFavorites` / `loadFavorites` 方法，用 `setStringList` 持久化。

---

## 六、性能优化建议

### 高优先级

**流量监控每秒全量重建：**
- 受影响：整个 Widget 树所有页面
- 修复：`ValueNotifier<int>` 独立管理 `upBps`/`downBps`
- 收益：CPU 占用显著下降，动画更流畅

**延迟测速期间高频重建：**
- 10 个节点并发 → 短时间 10 次全局重建
- 修复：批量收集结果后单次 `notifyListeners()`

---

## 七、安全性风险

| 风险等级 | 风险点 | 影响 | 修复建议 | 状态 |
|---------|-------|------|---------|------|
| **高** | 登录记录展示假数据 | 误导用户安全判断 | 接真实 API 或隐藏 | ✅ 已完成 |
| **中** | `http://` API 地址无校验 | 明文传输 token/密码 | 配置时校验 HTTPS scheme | ✅ 已完成（`AppConfig.isSecureServer` + 设置页警告卡片） |
| **中** | token 失效和网络故障处理相同 | 用户无法区分原因 | 细化 catch 类型 | ✅ 已完成 |
| **低** | DPAPI 加密依赖 PowerShell | 企业电脑可能禁用 PowerShell | 增加 fallback 处理 | ✅ 已完成（`FB:` 前缀 XOR fallback，用机器名+用户名派生密钥） |
| **低** | 日志可能包含服务器地址 | 导出日志可能泄漏 URL | 导出前过滤 | ⬜ 待完成 |

---

## 八、与市场主流客户端对比

| 维度 | Litchi | Clash Verge Rev | V2RayN | Hiddify |
|-----|--------|----------------|--------|---------|
| **UI 设计质量** | ★★★★★ 自定义设计系统 | ★★★☆ 标准 Material | ★★ 老旧 | ★★★★ 现代 |
| **面板集成（购买/账户）** | ★★★★★ 完整内嵌 | ★ 无 | ★ 无 | ★★ SubStore |
| **节点选择体验** | ★★★★ 网格+自动+测速 | ★★★★★ 规则+分组+延迟 | ★★★ 列表 | ★★★★ 分组 |
| **协议支持** | ★★★★ Sing-box 全协议 | ★★★★★ Mihomo | ★★★★ Xray | ★★★★ Sing-box |
| **规则管理** | ★ 无规则编辑器 | ★★★★★ 完整 | ★★★ 订阅规则 | ★★★★ 内置 |
| **TUN 模式** | ★★ UI有未验证 | ★★★★★ 成熟 | ★★★ 支持 | ★★★★★ 优先 |
| **平台支持** | Windows 专属 | Win/Mac/Linux | Windows | 全平台 |
| **自动更新** | ★ 配置有实现无 | ★★★★★ | ★★★★ | ★★★★★ |
| **公告/通知** | ★ 无 | ★ 无 | ★ 无 | ★★ 有 |
| **调试/日志** | ★★ 仅导出 | ★★★★★ 实时查看 | ★★★★ | ★★★ |

### Litchi 核心差异化优势

1. **面板深度集成** — 商城、账户、订单、邀请全部内嵌，竞品均无此能力
2. **UI 品质** — 明显优于所有竞品，达到商业产品水准
3. **品牌定制性** — 可完全定制 Logo/颜色/名称

### 需要从竞品学习补强的地方

| 学习方向 | 参考对象 | 优先级 | 状态 |
|---------|---------|-------|------|
| TUN 模式稳定支持 | Hiddify | P1 | ✅ 已完成（`NetworkMode` enum + TUN inbound + admin 权限检测 + 系统代理跳过） |
| 自动更新机制实现 | Clash Verge Rev | P1 | ✅ 已完成（`UpdateService` + `UpdateBanner`；需配置 `UPDATE_CHECK_URL`） |
| 规则模式可视化 | Clash Verge Rev | P2 | ⬜ 待完成 |
| 连接日志 UI（实时连接查看） | Clash Verge Rev | P2 | ⬜ 待完成 |
| 速度测试（带宽，不只是延迟） | 大部分竞品 | P2 | ⬜ 待完成 |
| 多语言 | Hiddify | P3 | ⬜ 待完成 |

---

## 九、重构优先级路线图

### 阶段 1：上线前必须完成

**目标：** 消除假数据，补充关键缺失功能，达到可上线状态

| 任务 | 涉及文件 | 状态 |
|------|---------|------|
| 修复登录记录：接 `/user/login/log` 真实 API | `account_page.dart` + `panel_api.dart` + `api_models.dart` | ✅ 已完成 |
| 实现忘记密码流程（发码+重置两步） | `forgot_password_page.dart`（新建）+ `auth_flow.dart` + `login_page.dart` | ✅ 已完成 |
| 持久化节点收藏 | `settings_service.dart` + `nodes_page.dart` | ✅ 已完成 |
| 货币符号动态化 | `app_controller.dart` + `shop_page.dart` + `account_page.dart` | ✅ 已完成 |
| 套餐折扣动态计算 | `shop_page.dart`（`_computeSavings` 方法） | ✅ 已完成 |
| Token 失效提示 | `app_controller.dart` + `login_page.dart` | ✅ 已完成 |

### 阶段 2：工程化补全

**目标：** 建立发布流程，修复性能问题

| 任务 | 涉及文件 | 状态 |
|------|---------|------|
| 流量速率提取为 ValueNotifier | `core_controller.dart` + `connection_stats_row.dart` | ✅ 已完成 |
| ProxyMode enum 替换中文魔法字符串 | 全局 5 个文件 | ✅ 已完成 |
| 实现自动更新（检查更新接口） | 新增 `update_service.dart` | ✅ 已完成 |
| GitHub Actions CI 构建流 | `.github/workflows/build.yml` | ✅ 已完成 |
| 版本号规范化 + CHANGELOG | `pubspec.yaml` + `CHANGELOG.md` | ✅ 已完成 |

### 阶段 3：功能扩展

**目标：** 补齐机场客户端核心功能

| 任务 | 涉及文件 | 状态 |
|------|---------|------|
| 公告/通知系统 | `notice_banner.dart` + `NoticeBanner` + 已读持久化 | ✅ 已完成 |
| 工单入口 | `tickets_page.dart` 完整实现（列表+创建+回复+关闭） | ✅ 已完成 |
| 邮件验证码注册 | `register_page.dart` 扩展 | ✅ 已完成 |
| TUN 模式验证与修复 | `network_settings_card.dart` + `singbox_config.dart` + `core_controller.dart` + `app_controller.dart`（全链路接入） | ✅ 已完成 |
| 连接日志 UI | 新增日志 Panel | ⬜ 待完成 |

### 阶段 4：体验与差异化（长期）

| 任务 | 状态 |
|------|------|
| 规则模式可视化（流量走向） | ⬜ 待完成 |
| 设备管理页 | ✅ 已完成（在线设备显示在 `traffic_page.dart` 统计卡片） |
| 速度测试功能 | ✅ 已完成（`SpeedTester` 服务 + `NetworkSettingsCard` 内测速按钮，已连接时显示，测 10MB Cloudflare） |
| Mac/Linux 支持 | ⬜ 待完成 |

---

## 十、下一步建议

**当前项目不适合继续堆新功能**，必须先完成阶段 1 的 6 个修复点。

**下一步 AI 可以直接执行的具体任务（按优先级）：**

1. 修复登录记录 Mock → 接 `/user/login/log` 真实 API
2. 实现忘记密码流程（发验证码 + 重置密码两步）
3. 持久化节点收藏（SharedPreferences）
4. ProxyMode enum 重构（消除中文魔法字符串）
5. 流量速率 ValueNotifier 拆分（消除每秒全量重建）

---

**结论：建议先完成阶段 1 的 6 项修复再做任何新功能，不建议一次性大规模改动。当前代码质量足够支撑上线，主要障碍是功能完整性而非架构质量。**
