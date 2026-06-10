# 工程化修复记录

本文档记录本轮根据 `Claude.md` 审计方案实际执行的修改，以及每项修改解决的问题。

## 一、测试体系修复

### 修改内容

- 修改 `test/widget_test.dart`
- 增加 `TestWidgetsFlutterBinding.ensureInitialized()`
- 增加 `SharedPreferences.setMockInitialValues({})`

### 解决的问题

之前执行 `flutter test` 会失败，原因是 `AppController.logout()` 和主题切换逻辑会间接调用 `SharedPreferences`，但测试环境没有初始化 Flutter binding，也没有 mock 本地存储。

修复后，测试不会再访问真实平台通道，控制器基础行为可以稳定测试。

### 收益

- `flutter test` 可以正常通过
- 后续重构有基础回归保护
- 降低状态管理和持久化逻辑调整时的风险

## 二、静态分析清理

### 修改内容

- 修改 `lib/shared/models/model_mappers.dart`
- 为 `_regionFor` 中的单行 `if return` 增加大括号

### 解决的问题

之前 `flutter analyze` 有 3 个 info 级别提示：

```text
curly_braces_in_flow_control_structures
```

### 收益

- `flutter analyze` 当前无问题
- 代码风格更统一
- 后续 CI 可以把 analyze 作为硬性检查

## 三、README 补充

### 修改内容

- 重写 `README.md`
- 补充项目用途、技术栈、目录结构、本地运行、测试、构建、sing-box 放置位置、配置方式和质量检查命令

### 解决的问题

原 README 仍是 Flutter 模板内容，无法说明当前项目如何运行、如何构建、核心依赖是什么。

### 收益

- 新开发者或 AI 接手项目时能快速理解项目
- 明确 `flutter analyze`、`flutter test` 等基础检查命令
- 明确 sing-box.exe 的查找位置

## 四、订单支付模块初步拆分

### 修改内容

- 将原 `lib/features/shop/order_confirm_dialog.dart` 迁移到：

```text
lib/features/shop/order/order_confirm_dialog.dart
```

- 在旧路径保留兼容导出：

```text
lib/features/shop/order_confirm_dialog.dart
```

- 新增订单周期映射文件：

```text
lib/features/shop/order/order_period_mapper.dart
```

- 新增订单价格计算文件：

```text
lib/features/shop/order/order_price_calculator.dart
```

### 解决的问题

原 `order_confirm_dialog.dart` 文件过大，包含订单确认、周期映射、优惠计算、支付方式加载、二维码支付、支付轮询和大量 UI 代码。

本轮先拆出风险最低的纯逻辑：

- 周期 key 映射
- 周期文案
- 优惠金额计算
- 最终价格计算

### 收益

- 大文件开始具备可拆分边界
- 纯逻辑可以后续单独补测试
- 旧 import 不受影响，降低迁移风险

## 五、订阅解析模块拆分

### 修改内容

- 新增：

```text
lib/shared/services/subscription/subscription_parser.dart
```

- 修改：

```text
lib/shared/services/panel_api.dart
```

- 将以下逻辑从 `PanelApi` 中移出：
  - Base64 订阅解析
  - Clash YAML 解析
  - URI 列表解析
  - `vmess://`
  - `vless://`
  - `trojan://`
  - `hysteria://`
  - `hysteria2://`
  - `ss://`

### 解决的问题

原 `PanelApi` 同时负责 API 请求和订阅内容解析，职责混杂。订阅解析逻辑复杂且未来容易继续扩展，如果继续放在 API 类里，会导致服务层越来越难维护。

### 收益

- `PanelApi.fetchSubscription` 只负责下载订阅和读取响应 header
- `SubscriptionParser` 专门负责解析订阅内容
- 后续支持更多协议或修复解析 bug 时影响范围更小

## 六、订阅解析测试补充

### 修改内容

- 新增：

```text
test/subscription_parser_test.dart
```

- 覆盖两类基础场景：
  - Base64 编码的 `vmess://` 订阅
  - Clash YAML `proxies` 订阅

### 解决的问题

订阅解析属于核心能力，但之前没有自动化测试保护。拆分后如果没有测试，后续继续重构解析逻辑容易引入回归。

### 收益

- 订阅解析具备基础回归保护
- 后续拆 `singbox_config.dart` 或继续扩展协议解析时更安全

## 七、订单状态查询修复

### 修改内容

- 修改 `lib/shared/services/panel_api.dart`
- 将订单状态查询从手动拼接 URL：

```dart
'/user/order/check?trade_no=$tradeNo'
```

改为使用 `queryParameters`：

```dart
_client.get('/user/order/check', params: {'trade_no': tradeNo})
```

### 解决的问题

手动拼接 URL 时，如果 `tradeNo` 包含特殊字符，可能导致请求参数编码错误。

### 收益

- 参数编码交给 Dio 处理
- 请求更稳定
- 避免 URL 拼接类问题

## 八、API Base 配置优化

### 修改内容

- 修改 `lib/shared/config/app_config.dart`
- `AppConfig.apiBase` 支持通过 `--dart-define` 覆盖：

```powershell
--dart-define=LITCHI_API_BASE=https://example.com
```

- 同步更新 `README.md`

### 解决的问题

原 API base URL 完全写死在代码中，切换测试环境、预发布环境或私有部署地址不方便。

### 收益

- 默认行为保持不变
- 本地运行和构建时可以指定不同后端地址
- 为后续环境配置规范化打基础

## 九、验证结果

本轮修改后已执行：

```powershell
flutter analyze
flutter test
```

结果：

```text
flutter analyze: No issues found
flutter test: 5 tests passed
```

## 十、后续建议

下一阶段建议继续按低风险顺序推进：

1. 继续拆分订单支付模块中的 `_PaymentDialog`
2. 为订单价格计算补单元测试
3. 拆分 `AppController`，优先从 `SettingsController` 开始
4. 引入统一的 loading / empty / error 状态模型
5. 加强 sing-box Clash API secret 和系统代理失败处理
