// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get settingsSubtitle => '配置客户端偏好和网络选项';

  @override
  String get systemSettings => '系统设置';

  @override
  String get launchAtStartup => '开机启动';

  @override
  String get automaticUpdates => '自动更新';

  @override
  String get appearance => '外观模式';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get connectionSettings => '连接设置';

  @override
  String get proxyMode => '代理模式';

  @override
  String get connectionMethod => '连接方式';

  @override
  String get systemProxy => '系统代理';

  @override
  String get tunMode => 'TUN 模式';

  @override
  String get systemProxyDescription => '使用系统代理接管网络请求';

  @override
  String get tunDescription => '通过虚拟网卡接管全部流量';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get connectionProtection => '连接中断保护';

  @override
  String get systemProtectionDescription => '系统代理核心异常退出时阻止网络直连';

  @override
  String get tunProtectionDescription => 'TUN 核心异常退出时阻止非隧道流量';

  @override
  String get macTunProtectionUnavailable => 'macOS TUN 暂不支持连接中断保护';

  @override
  String get repairNetworkSettings => '修复网络设置';

  @override
  String get repairNetworkDescription => '断开后无法上网时，清理或重新应用系统代理';

  @override
  String get repair => '修复';

  @override
  String get networkSettingsRepaired => '网络设置已修复';

  @override
  String get diagnostics => '诊断信息';

  @override
  String get diagnosticsDescription => '查看并复制信息，发送给管理员或客服';

  @override
  String get view => '查看';

  @override
  String get about => '关于应用';

  @override
  String get appVersion => '应用版本';

  @override
  String get coreVersion => '核心版本';

  @override
  String get loading => '获取中…';

  @override
  String get networkSettings => '网络设置';

  @override
  String get administratorRequired => '需要管理员权限';

  @override
  String get tunAdminHintWindows =>
      'TUN 虚拟网卡模式需要管理员权限才能创建虚拟网络接口。\n\n请右键点击客户端图标，选择「以管理员身份运行」后重新启动，再切换至此模式。';

  @override
  String get tunPermissionHintMac => '创建系统路由需要 macOS 系统权限；权限不足时连接会安全失败。';

  @override
  String get gotIt => '知道了';

  @override
  String get networkModeReconnect => '网络模式已切换，重新连接后生效';

  @override
  String get switchingConnectionMethod => '正在切换连接方式';

  @override
  String get home => '首页';

  @override
  String get plans => '套餐';

  @override
  String get invite => '邀请';

  @override
  String get account => '我的';

  @override
  String get nodes => '节点';

  @override
  String get wallet => '我的钱包';

  @override
  String get walletSubtitle => '余额、佣金与账户充值';

  @override
  String get orders => '订单记录';

  @override
  String get ordersSubtitle => '查看购买记录与支付状态';

  @override
  String get usage => '用量统计';

  @override
  String get usageSubtitle => '查看流量与近期记录';

  @override
  String get support => '工单支持';

  @override
  String get supportSubtitle => '联系在线客服';

  @override
  String get settingsNavSubtitle => '网络、代理与外观';

  @override
  String get loginTitle => '登录账户';

  @override
  String get loginSubtitle => '请输入您的凭据继续';

  @override
  String get registerTitle => '创建账户';

  @override
  String get registerSubtitle => '开始连接全世界';

  @override
  String get changePasswordTitle => '修改密码';

  @override
  String get changePasswordSubtitle => '更新登录密码，保护账户安全';

  @override
  String get forgotPasswordTitle => '忘记密码';

  @override
  String get forgotPasswordSubtitle => '我们将向您的邮箱发送验证码';

  @override
  String get email => '邮箱';

  @override
  String get emailOrUsernameHint => '请输入邮箱或用户名';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get rememberCredentials => '记住账号密码';

  @override
  String get forgotPasswordAction => '忘记密码？';

  @override
  String get login => '登录';

  @override
  String get noAccount => '还没有账号？';

  @override
  String get registerAccount => '注册账号';

  @override
  String get requiredCredentials => '请填写邮箱和密码';

  @override
  String get loginSuccess => '登录成功，欢迎回来！';

  @override
  String get or => '或';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get settings => '設定';

  @override
  String get settingsSubtitle => '設定用戶端偏好與網路選項';

  @override
  String get systemSettings => '系統設定';

  @override
  String get launchAtStartup => '開機啟動';

  @override
  String get automaticUpdates => '自動更新';

  @override
  String get appearance => '外觀模式';

  @override
  String get language => '語言';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => 'English';

  @override
  String get connectionSettings => '連線設定';

  @override
  String get proxyMode => '代理模式';

  @override
  String get connectionMethod => '連線方式';

  @override
  String get systemProxy => '系統代理';

  @override
  String get tunMode => 'TUN 模式';

  @override
  String get systemProxyDescription => '使用系統代理接管網路請求';

  @override
  String get tunDescription => '透過虛擬網卡接管全部流量';

  @override
  String get advancedSettings => '進階設定';

  @override
  String get connectionProtection => '連線中斷保護';

  @override
  String get systemProtectionDescription => '系統代理核心異常退出時阻止網路直連';

  @override
  String get tunProtectionDescription => 'TUN 核心異常退出時阻止非隧道流量';

  @override
  String get macTunProtectionUnavailable => 'macOS TUN 暫不支援連線中斷保護';

  @override
  String get repairNetworkSettings => '修復網路設定';

  @override
  String get repairNetworkDescription => '中斷後無法上網時，清理或重新套用系統代理';

  @override
  String get repair => '修復';

  @override
  String get networkSettingsRepaired => '網路設定已修復';

  @override
  String get diagnostics => '診斷資訊';

  @override
  String get diagnosticsDescription => '檢視並複製資訊，傳送給管理員或客服';

  @override
  String get view => '檢視';

  @override
  String get about => '關於應用程式';

  @override
  String get appVersion => '應用程式版本';

  @override
  String get coreVersion => '核心版本';

  @override
  String get loading => '取得中…';

  @override
  String get networkSettings => '網路設定';

  @override
  String get administratorRequired => '需要管理員權限';

  @override
  String get tunAdminHintWindows =>
      'TUN 虛擬網卡模式需要管理員權限才能建立虛擬網路介面。\n\n請以管理員身分重新啟動用戶端後再啟用。';

  @override
  String get tunPermissionHintMac => '建立系統路由需要 macOS 系統權限；權限不足時連線會安全失敗。';

  @override
  String get gotIt => '知道了';

  @override
  String get networkModeReconnect => '網路模式已切換，重新連線後生效';

  @override
  String get switchingConnectionMethod => '正在切換連線方式';

  @override
  String get home => '首頁';

  @override
  String get plans => '方案';

  @override
  String get invite => '邀請';

  @override
  String get account => '我的';

  @override
  String get nodes => '節點';

  @override
  String get wallet => '我的錢包';

  @override
  String get walletSubtitle => '餘額、佣金與帳戶儲值';

  @override
  String get orders => '訂單記錄';

  @override
  String get ordersSubtitle => '檢視購買記錄與付款狀態';

  @override
  String get usage => '用量統計';

  @override
  String get usageSubtitle => '檢視流量與近期記錄';

  @override
  String get support => '工單支援';

  @override
  String get supportSubtitle => '聯絡線上客服';

  @override
  String get settingsNavSubtitle => '網路、代理與外觀';

  @override
  String get loginTitle => '登入帳戶';

  @override
  String get loginSubtitle => '請輸入您的憑證以繼續';

  @override
  String get registerTitle => '建立帳戶';

  @override
  String get registerSubtitle => '開始連接全世界';

  @override
  String get changePasswordTitle => '修改密碼';

  @override
  String get changePasswordSubtitle => '更新登入密碼，保護帳戶安全';

  @override
  String get forgotPasswordTitle => '忘記密碼';

  @override
  String get forgotPasswordSubtitle => '我們將向您的信箱傳送驗證碼';

  @override
  String get email => '信箱';

  @override
  String get emailOrUsernameHint => '請輸入信箱或使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get passwordHint => '請輸入密碼';

  @override
  String get rememberCredentials => '記住帳號密碼';

  @override
  String get forgotPasswordAction => '忘記密碼？';

  @override
  String get login => '登入';

  @override
  String get noAccount => '還沒有帳戶？';

  @override
  String get registerAccount => '註冊帳戶';

  @override
  String get requiredCredentials => '請填寫信箱和密碼';

  @override
  String get loginSuccess => '登入成功，歡迎回來！';

  @override
  String get or => '或';
}
