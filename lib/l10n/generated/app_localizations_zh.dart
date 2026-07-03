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
  String get silentStartup => '静默启动到托盘';

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

  @override
  String get fillEmailPrefix => '请先填写邮箱前缀';

  @override
  String get invalidEmail => '请先填写正确的邮箱地址';

  @override
  String get verificationCodeSent => '验证码已发送，请查收邮件';

  @override
  String get passwordsMismatch => '两次密码不一致';

  @override
  String get verificationCodeRequired => '请填写邮件验证码';

  @override
  String get acceptTermsRequired => '请先同意服务条款';

  @override
  String registrationSuccess(String appName) {
    return '注册成功，欢迎加入 $appName！';
  }

  @override
  String get verificationCode => '验证码';

  @override
  String get verificationCodeHint => '请输入邮件验证码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get confirmPasswordHint => '请再次输入密码';

  @override
  String get inviteCode => '邀请码';

  @override
  String get inviteCodeOptional => '邀请码（可选）';

  @override
  String get termsAgreementPrefix => '我已阅读并同意 ';

  @override
  String get termsOfService => '服务条款';

  @override
  String get alreadyHaveAccount => '已有账号？';

  @override
  String get sendVerificationCode => '发送验证码';

  @override
  String get sending => '发送中…';

  @override
  String resendIn(int seconds) {
    return '重新发送 (${seconds}s)';
  }

  @override
  String get resend => '重新发送';

  @override
  String get allFieldsRequired => '请填写所有字段';

  @override
  String get passwordResetSuccess => '密码重置成功，请重新登录';

  @override
  String get registeredEmailHint => '请输入注册邮箱';

  @override
  String get newPassword => '新密码';

  @override
  String get newPasswordHint => '请输入新密码';

  @override
  String get resetPassword => '重置密码';

  @override
  String get backToLogin => '返回登录';

  @override
  String get passwordFieldsRequired => '请填写所有密码字段';

  @override
  String get passwordChanged => '密码修改成功';

  @override
  String get currentPasswordHint => '请输入当前密码';

  @override
  String get passwordAdvice => '建议使用 8 位以上字母、数字组合';

  @override
  String get saveChanges => '保存修改';

  @override
  String get refreshed => '已刷新';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get dashboardSubtitle => '查看当前连接、节点与流量状态';

  @override
  String get all => '全部';

  @override
  String get favorites => '收藏';

  @override
  String get asia => '亚洲';

  @override
  String get europe => '欧洲';

  @override
  String get america => '美洲';

  @override
  String get oceania => '大洋洲';

  @override
  String get nodesSubtitle => '选择适合你的高速线路';

  @override
  String get selectLineAndLatency => '选择线路并查看延迟';

  @override
  String get noMatchingNodes => '没有匹配的节点';

  @override
  String get tryDifferentNodeFilter => '换个关键词或分区再试试';

  @override
  String get searchNodes => '搜索节点';

  @override
  String get autoSelect => '自动选择';

  @override
  String get manualSelect => '手动选择';

  @override
  String get autoSelectBestDescription => '根据延迟自动使用最优线路';

  @override
  String get autoSelectEnabled => '已开启自动选择，将使用最优节点';

  @override
  String switchedToNode(String node) {
    return '已切换至 $node';
  }

  @override
  String get noTestableNodes => '暂无可测速节点';

  @override
  String get latencyTestComplete => '测速完成';

  @override
  String get latencyTestFailed => '测速失败，请检查节点后重试';

  @override
  String get latencyTest => '测速';

  @override
  String get noNodes => '暂无节点';

  @override
  String get waitForSubscription => '如果刚登录，请稍等订阅数据加载完成';

  @override
  String get chooseNode => '选择节点';

  @override
  String nodeCountSummary(int count) {
    return '$count 个节点 · 筛选线路并查看延迟';
  }

  @override
  String get noNodesSubscription => '暂无节点 · 请检查订阅状态';

  @override
  String get close => '关闭';

  @override
  String get currentNode => '当前节点';

  @override
  String get nodeLoading => '节点加载中';

  @override
  String get nodeStatus => '节点状态';

  @override
  String get fetchingNodes => '正在获取节点...';

  @override
  String get noAvailableNodes => '暂无可用节点';

  @override
  String get syncingSubscription => '正在同步订阅数据...';

  @override
  String get subscriptionLoadsAfterLogin => '登录后会自动拉取订阅节点';

  @override
  String get encryptionProtectionEnabled => '加密保护已开启';

  @override
  String get establishingEncryptedChannel => '正在建立加密通道...';

  @override
  String get closingEncryptedChannel => '正在关闭加密通道...';

  @override
  String get networkNotProtected => '网络暂未受到加密保护';

  @override
  String nodeMode(String mode) {
    return '节点模式 · $mode';
  }

  @override
  String get switchNode => '切换节点';

  @override
  String get viewNodes => '查看节点';

  @override
  String get startConnection => '开始连接';

  @override
  String get connecting => '连接中…';

  @override
  String get disconnectConnection => '断开连接';

  @override
  String get disconnecting => '断开中…';

  @override
  String get reconnect => '重新连接';

  @override
  String get proxyModeDescriptionRule => '自动分流，国内直连、国外流量走代理';

  @override
  String get proxyModeDescriptionGlobal => '所有流量均通过代理节点转发';

  @override
  String get proxyModeDescriptionDirect => '不使用代理，直接连接目标网站';

  @override
  String switchedProxyMode(String mode) {
    return '已切换至 $mode';
  }

  @override
  String get proxyModeNextConnection => '代理模式将在下次连接后生效';

  @override
  String get ruleMode => '规则';

  @override
  String get globalMode => '全局';

  @override
  String get directMode => '直连';

  @override
  String get currentLatency => '当前延迟';

  @override
  String get downloadSpeed => '下载速度';

  @override
  String get uploadSpeed => '上传速度';

  @override
  String get subscriptionExpired => '订阅已过期，连接将无法使用';

  @override
  String get subscriptionExpiresToday => '订阅今日到期，请及时续费';

  @override
  String subscriptionExpiresInDays(int days) {
    return '订阅将在 $days 天后到期';
  }

  @override
  String get renewNow => '去续费 →';

  @override
  String get renewPlan => '续费';

  @override
  String get retry => '重试';

  @override
  String get businessEdition => '业务版';

  @override
  String get protected => '保护中';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get notConnected => '未连接';

  @override
  String get unavailable => '暂未开放';

  @override
  String get androidLimitedNotice => '当前 Android 版本先提供登录、购买和节点查看';

  @override
  String get syncingNodes => '正在同步节点...';

  @override
  String get selectNodePrompt => '请选择节点';

  @override
  String nodeModeLabel(String mode) {
    return '节点模式：$mode';
  }

  @override
  String get buyPlans => '购买套餐';

  @override
  String get buyPlansSubtitle => '选择适合你的套餐和流量包';

  @override
  String get planPurchase => '套餐购买';

  @override
  String get recurringPlan => '周期套餐';

  @override
  String get oneTime => '一次性';

  @override
  String get dataPack => '流量包';

  @override
  String get noPlans => '暂无套餐信息';

  @override
  String get refreshLater => '请稍后刷新重试';

  @override
  String get unlimitedTime => '/ 不限时';

  @override
  String get oneTimePlan => '一次性套餐';

  @override
  String devicesCount(int count) {
    return '$count 台设备';
  }

  @override
  String get unlimitedDevices => '不限设备';

  @override
  String get popular => '热门';

  @override
  String get recommended => '推荐';

  @override
  String get buyNow => '立即购买';

  @override
  String get unavailableForPurchase => '暂不可购买';

  @override
  String get monthly => '月付';

  @override
  String get quarterly => '季付';

  @override
  String get halfYear => '半年';

  @override
  String get yearly => '年付';

  @override
  String get perMonth => '/ 月';

  @override
  String get perQuarter => '/ 季';

  @override
  String get perHalfYear => '/ 半年';

  @override
  String get perYear => '/ 年';

  @override
  String get orderHistorySubtitle => '查看购买与支付记录';

  @override
  String get order => '订单';

  @override
  String get orderLoadFailed => '订单加载失败';

  @override
  String get noOrders => '暂无订单';

  @override
  String get ordersAppearAfterPurchase => '购买套餐后会显示在这里';

  @override
  String get orderCancelled => '订单已取消';

  @override
  String get accountTopUp => '账户充值';

  @override
  String orderNumber(String number) {
    return '订单号 $number';
  }

  @override
  String get type => '类型';

  @override
  String get date => '日期';

  @override
  String get amount => '金额';

  @override
  String get status => '状态';

  @override
  String get cancelOrder => '取消订单';

  @override
  String get continuePayment => '继续支付';

  @override
  String get processing => '处理中';

  @override
  String get cancelOrderConfirm => '确认取消该待支付订单？取消后需要重新下单。';

  @override
  String get thinkAgain => '再想想';

  @override
  String get confirmCancel => '确认取消';

  @override
  String get inviteFriends => '邀请好友';

  @override
  String get inviteSubtitle => '分享邀请链接并查看佣金记录';

  @override
  String get inviteCommission => '邀请返佣';

  @override
  String get inviteCodeCreated => '邀请码已创建';

  @override
  String get inviteLink => '邀请链接';

  @override
  String get copyLink => '复制链接';

  @override
  String get creating => '创建中';

  @override
  String get createInviteCode => '创建邀请码';

  @override
  String inviteCodeIndex(int index) {
    return '邀请码 $index';
  }

  @override
  String get inviteLinkUnavailable => '邀请链接未配置';

  @override
  String get registeredUsers => '已注册用户';

  @override
  String peopleCount(int count) {
    return '$count 人';
  }

  @override
  String get pendingCommission => '确认中佣金';

  @override
  String get totalCommission => '累计佣金';

  @override
  String get commissionRate => '佣金比例';

  @override
  String get commissionRecords => '佣金记录';

  @override
  String get noCommissionRecords => '暂无佣金记录';

  @override
  String get invitedUser => '邀请用户';

  @override
  String recordOrderAmount(String date, String amount) {
    return '$date · 订单 $amount';
  }

  @override
  String get copied => '已复制';

  @override
  String linkCopiedForApp(String app) {
    return '链接已复制，可粘贴到$app';
  }

  @override
  String get confirmOrder => '确认订单';

  @override
  String get selectBillingCycle => '选择周期';

  @override
  String get couponCode => '优惠码';

  @override
  String get couponHint => '输入优惠码（可选）';

  @override
  String get remove => '移除';

  @override
  String get verifying => '验证中…';

  @override
  String get verify => '验证';

  @override
  String get couponApplied => '优惠码已生效';

  @override
  String get invalidCoupon => '优惠码无效';

  @override
  String discountAmount(String amount) {
    return '已优惠 $amount';
  }

  @override
  String discountPercent(int percent) {
    return '已优惠 $percent%';
  }

  @override
  String get originalPrice => '套餐原价';

  @override
  String get discount => '优惠减免';

  @override
  String get totalDue => '应付总计';

  @override
  String get cancel => '取消';

  @override
  String get submitOrder => '提交订单';

  @override
  String operationFailed(String operation, String error) {
    return '$operation失败：$error';
  }

  @override
  String get selectPaymentMethod => '选择支付方式';

  @override
  String get browserPayment => '浏览器支付';

  @override
  String get scanToPay => '扫码支付';

  @override
  String get paymentSuccess => '支付成功';

  @override
  String get paymentTimedOut => '支付已超时';

  @override
  String get qrExpired => '二维码已过期';

  @override
  String get amountDue => '应付金额';

  @override
  String get balanceApplied => '余额已抵扣';

  @override
  String get subscriptionCredit => '旧订阅折抵';

  @override
  String get refundAmountLabel => '退款金额';

  @override
  String get paymentHandlingFee => '支付手续费';

  @override
  String paymentFeeDescription(String value) {
    return '手续费：$value';
  }

  @override
  String get balancePayment => '余额支付';

  @override
  String get activateWithBalance => '使用余额激活';

  @override
  String get choosePaymentMethod => '选择付款方式';

  @override
  String get noPaymentMethods => '暂无可用支付方式';

  @override
  String get payNow => '去支付';

  @override
  String get scanWithPhone => '使用手机扫码完成支付';

  @override
  String get openInBrowser => '或在浏览器打开';

  @override
  String remainingTime(String time) {
    return '剩余 $time';
  }

  @override
  String get paymentCompleted => '我已完成支付';

  @override
  String get paymentNotDetected => '暂未检测到支付，请稍后再试';

  @override
  String get paymentProcessing => '订单正在处理中，状态会自动更新';

  @override
  String get orderActivated => '订单已激活，请刷新页面查看';

  @override
  String get done => '完成';

  @override
  String get refreshQrCode => '刷新二维码';

  @override
  String get getPaymentMethods => '获取支付方式';

  @override
  String get startPayment => '发起支付';

  @override
  String get queryPayment => '查询';

  @override
  String get refreshPayment => '刷新';

  @override
  String get orderPending => '待支付';

  @override
  String get orderProcessing => '处理中';

  @override
  String get orderCancelledStatus => '已取消';

  @override
  String get orderCompleted => '已完成';

  @override
  String get orderFailed => '失败';

  @override
  String get twoYears => '两年';

  @override
  String get threeYears => '三年';

  @override
  String get perTwoYears => '/ 两年';

  @override
  String get perThreeYears => '/ 三年';

  @override
  String get orderDiscounted => '已折抵';

  @override
  String get soldOut => '已售罄';

  @override
  String lowStockRemaining(int count) {
    return '仅剩 $count 份';
  }

  @override
  String existingPlanSwitchWarning(String current, String target) {
    return '你当前正在使用“$current”。购买“$target”可能替换或折抵现有订阅，请确认后再继续。';
  }

  @override
  String get unknown => '未知';

  @override
  String get buyout => '买断';

  @override
  String get wechat => '微信';

  @override
  String get connectionInProgress => '连接处理中';

  @override
  String get connected => '已连接';

  @override
  String diagnosticPlatform(String platform) {
    return '平台：$platform';
  }

  @override
  String diagnosticConnectionStatus(String status) {
    return '连接状态：$status';
  }

  @override
  String diagnosticProxyPort(int port) {
    return '本地代理端口：$port';
  }

  @override
  String diagnosticRecordedAt(String time) {
    return '记录时间：$time';
  }

  @override
  String diagnosticRecentError(String error) {
    return '最近错误：$error';
  }

  @override
  String get noRuntimeLogs => '暂无运行日志，请先尝试连接后再查看。';

  @override
  String get systemDns => '系统 DNS';

  @override
  String get httpSecurityWarning =>
      '当前服务器使用 HTTP 连接，数据传输未加密，存在中间人攻击风险。建议联系服务商开启 HTTPS。';

  @override
  String get diagnosticCopyDescription => '复制后发送给管理员或客服，可帮助快速定位问题';

  @override
  String get diagnosticCopied => '诊断信息已复制，请发送给管理员或客服';

  @override
  String get copyDiagnostics => '一键复制';

  @override
  String get restartClientError => '连接失败，请重启客户端后重试';

  @override
  String get proxyPortUnavailableError => '本地代理端口启动失败，请关闭其他代理软件后重试';

  @override
  String get missingCoreError => '连接失败，请检查 mihomo 核心是否存在';

  @override
  String get permissionDeniedError => '权限不足，请以管理员身份运行客户端';

  @override
  String get tunInterfaceUnavailableError => 'TUN 虚拟网卡启动失败，请检查系统权限后重试';

  @override
  String get tunKillSwitchUnavailableError => 'TUN 中断保护启动失败，已停止连接以避免流量泄漏';

  @override
  String get androidStartFailedError => 'Android 核心启动失败';

  @override
  String get unexpectedCoreExitError => '核心异常退出，连接已断开，请重新连接';

  @override
  String get invalidNodeConfigError => '当前节点配置无效，请切换节点后重试';

  @override
  String get genericConnectionFailureError => '连接失败，请切换节点或稍后重试';

  @override
  String get configBuildFailedError => '生成配置失败，请选择其他节点后重试';

  @override
  String get cachedModeActive => '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。';

  @override
  String get serverUnavailableNoCache => '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';

  @override
  String get trafficStatistics => '流量统计';

  @override
  String get trafficStatisticsSubtitle => '查看流量、设备和套餐周期';

  @override
  String remainingTraffic(String value) {
    return '剩余 $value GB';
  }

  @override
  String get onlineDevices => '在线设备';

  @override
  String get currentOnlineDevices => '当前在线设备数';

  @override
  String get remainingDays => '剩余日期';

  @override
  String get permanent => '永久';

  @override
  String get daysUnit => '天';

  @override
  String get subscriptionLongTerm => '订阅长期有效';

  @override
  String expiresAt(String date) {
    return '到期 $date';
  }

  @override
  String get trafficResetTime => '流量重置时间';

  @override
  String get neverResets => '不重置';

  @override
  String daysCount(int count) {
    return '$count 天';
  }

  @override
  String get noTrafficReset => '当前套餐未配置重置周期';

  @override
  String get untilNextReset => '距下次重置';

  @override
  String get trafficTrend => '流量趋势图';

  @override
  String periodTrafficTotal(String period, String total) {
    return '$period 共 $total';
  }

  @override
  String recentDays(int count) {
    return '最近$count天';
  }

  @override
  String tooltipUpload(String value) {
    return '上行 $value';
  }

  @override
  String tooltipDownload(String value) {
    return '下行 $value';
  }

  @override
  String tooltipTotal(String value) {
    return '合计 $value';
  }

  @override
  String get weekdayShort => '周一,周二,周三,周四,周五,周六,周日';

  @override
  String get ticketSupport => '工单支持';

  @override
  String get ticketSupportSubtitle => '提交问题并查看回复';

  @override
  String get tickets => '工单';

  @override
  String get ticketSupportCompactSubtitle => '提交问题并查看客服回复';

  @override
  String get newTicket => '新建工单';

  @override
  String get ticketLoadFailed => '工单加载失败';

  @override
  String get noTickets => '暂无工单';

  @override
  String get noTicketsSubtitle => '有问题可以新建工单联系客服';

  @override
  String get untitledTicket => '未命名工单';

  @override
  String get ticketFieldsRequired => '请填写标题和问题描述';

  @override
  String get ticketSubjectTooShort => '问题标题至少 5 个字符';

  @override
  String get ticketMessageTooShort => '问题描述至少 10 个字符';

  @override
  String get ticketSubmitted => '工单已提交';

  @override
  String get ticketSubscriptionMismatch => '当前套餐有效，但工单接口未同步套餐状态，请稍后重试或联系管理员';

  @override
  String get issueSubject => '问题标题';

  @override
  String get issueSubjectHint => '用一句话描述你的问题';

  @override
  String get priority => '优先级';

  @override
  String get issueDescription => '问题描述';

  @override
  String get issueDescriptionHint => '详细描述你遇到的问题';

  @override
  String get submitting => '提交中...';

  @override
  String get submitTicket => '提交工单';

  @override
  String get replyRequired => '请输入回复内容';

  @override
  String get replySent => '回复已发送';

  @override
  String get ticketClosed => '工单已关闭';

  @override
  String get ticketDetails => '工单详情';

  @override
  String get replyHint => '输入回复内容';

  @override
  String get closing => '关闭中...';

  @override
  String get closeTicket => '关闭工单';

  @override
  String get sendReply => '发送回复';

  @override
  String get priorityLow => '低';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityUrgent => '紧急';

  @override
  String get noTicketMessages => '暂无消息记录';

  @override
  String get customerSupport => '客服';

  @override
  String get me => '我';

  @override
  String get ticketClosedStatus => '已关闭';

  @override
  String get invalidRechargeAmount => '请输入有效的充值金额';

  @override
  String get noTransferableCommission => '暂无可划转佣金';

  @override
  String get withdrawalUnavailable => '提现暂未开放';

  @override
  String get noWithdrawableCommission => '暂无可提现佣金';

  @override
  String get noWithdrawalMethods => '暂无可用提现方式';

  @override
  String get myWallet => '我的钱包';

  @override
  String get myWalletSubtitle => '查看余额、佣金与充值';

  @override
  String get accountAssets => '账户资产';

  @override
  String get accountBalance => '账户余额';

  @override
  String get withdrawableCommission => '可提现佣金';

  @override
  String get transferCommission => '佣金划转';

  @override
  String get transferShort => '划转';

  @override
  String get requestWithdrawal => '申请提现';

  @override
  String get withdrawShort => '提现';

  @override
  String get rechargeBalance => '充值余额';

  @override
  String get rechargeBalanceNotice => '充值后的余额仅限消费，无法提现';

  @override
  String get customAmount => '自定义金额';

  @override
  String get rechargeAmountHint => '请输入充值金额';

  @override
  String get recharge => '充值';

  @override
  String get transferAmountRequired => '请输入划转金额';

  @override
  String get transferAmountTooHigh => '划转金额不能超过可提现佣金';

  @override
  String get commissionTransferred => '佣金已划转到余额';

  @override
  String get transferCommissionNotice => '将可提现佣金划转到账户余额，划转后可用于购买套餐。';

  @override
  String get transferAmount => '划转金额';

  @override
  String transferableAmount(String amount) {
    return '可划转 $amount';
  }

  @override
  String get transferring => '划转中...';

  @override
  String get confirmTransfer => '确认划转';

  @override
  String get withdrawalAmountRequired => '请输入提现金额';

  @override
  String get withdrawalAmountTooHigh => '提现金额不能超过可提现佣金';

  @override
  String minimumWithdrawal(String amount) {
    return '最低提现金额为 $amount';
  }

  @override
  String get withdrawalAccountRequired => '请输入提现账户';

  @override
  String get withdrawalSubmitted => '提现工单已提交';

  @override
  String get withdrawalMethod => '提现方式';

  @override
  String get withdrawalAccount => '提现账户';

  @override
  String get withdrawalAccountHint => '请输入收款账号';

  @override
  String get withdrawalAmount => '提现金额';

  @override
  String withdrawableAmount(String amount) {
    return '可提现 $amount';
  }

  @override
  String withdrawableWithMinimum(String amount, String minimum) {
    return '可提现 $amount · 最低 $minimum';
  }

  @override
  String get submitWithdrawal => '提交提现';

  @override
  String itemCopied(String item) {
    return '$item 已复制';
  }

  @override
  String get settingsUpdated => '设置已更新';

  @override
  String get myAccount => '我的账户';

  @override
  String get myAccountSubtitle => '查看账户信息与订阅详情';

  @override
  String get expiredStatus => '已到期';

  @override
  String get suspendedStatus => '已封禁';

  @override
  String get normalStatus => '正常';

  @override
  String get accountInformation => '账户信息';

  @override
  String get accountStatus => '账户状态';

  @override
  String get expiryTime => '到期时间';

  @override
  String get balanceAndRecharge => '余额与充值';

  @override
  String get purchaseAndPayment => '购买与支付';

  @override
  String get usageRecords => '使用记录';

  @override
  String get contactAfterSales => '联系售后';

  @override
  String get resetDayUnavailable => '重置日 --';

  @override
  String monthlyResetDay(int day) {
    return '每月 $day 日重置';
  }

  @override
  String get trafficOverview => '流量概览';

  @override
  String usedPercent(String percent) {
    return '已用 $percent%';
  }

  @override
  String get remaining => '剩余';

  @override
  String usedTraffic(String used, String total) {
    return '已用 $used / $total GB';
  }

  @override
  String get currentPlan => '当前套餐';

  @override
  String get noCurrentPlan => '暂无套餐';

  @override
  String get noPlanDescription => '当前没有有效套餐，购买套餐后即可获取节点和流量。';

  @override
  String get logout => '退出登录';

  @override
  String get logoutDataNotice => '当前登录状态和本地节点缓存将被清除';

  @override
  String get logoutConfirmMessage => '确认退出当前账号？退出后需要重新登录。';

  @override
  String get confirmLogout => '确认退出';

  @override
  String currentPlanValue(String plan) {
    return '当前套餐：$plan';
  }

  @override
  String expiryValue(String expiry) {
    return '到期：$expiry';
  }

  @override
  String get manage => '管理';

  @override
  String get accountManagement => '账号管理';

  @override
  String get expiryReminder => '到期提醒';

  @override
  String get expiryReminderSubtitle => '接收账户到期提醒邮件';

  @override
  String get trafficReminder => '流量提醒';

  @override
  String get trafficReminderSubtitle => '接收流量用尽提醒邮件';

  @override
  String get autoRenewal => '自动续费';

  @override
  String get autoRenewalSubtitle => '到期前自动续费套餐';

  @override
  String get updateLoginPassword => '更新登录密码';

  @override
  String get logoutCurrentAccount => '退出当前账号';

  @override
  String get passwordTooShort => '新密码至少 8 位';

  @override
  String get currentPassword => '当前密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get confirmNewPasswordHint => '请输入确认新密码';

  @override
  String get updating => '更新中...';

  @override
  String get confirmChange => '确认修改';

  @override
  String get trayConnectedTun => '已连接 · 虚拟网卡';

  @override
  String get trayConnectedSystemProxy => '已连接 · 系统代理';

  @override
  String openApp(String appName) {
    return '打开 $appName';
  }

  @override
  String trayNode(String node) {
    return '节点：$node';
  }

  @override
  String get connectNow => '立即连接';

  @override
  String get repairSystemProxy => '修复系统代理';

  @override
  String get quit => '退出';

  @override
  String get cannotOpenUpdateUrl => '无法打开更新下载地址';

  @override
  String get downloadPageOpened => '已打开下载页面';

  @override
  String get downloadCompleteOpeningInstaller => '下载完成，正在打开安装包';

  @override
  String newVersionAvailable(String version) {
    return '发现新版本 v$version，点击下载最新版本';
  }

  @override
  String get downloadNow => '立即下载';

  @override
  String get refresh => '刷新';

  @override
  String get back => '返回';

  @override
  String get search => '搜索';

  @override
  String get backToAccount => '返回我的';

  @override
  String get viewDetails => '查看详情';

  @override
  String get requestFailed => '请求失败，请稍后重试';

  @override
  String get sessionExpiredError => '登录已过期，请重新登录';

  @override
  String get tooManyRequestsError => '操作太频繁，请稍后再试';

  @override
  String get invalidSubmissionError => '提交内容有误，请检查后重试';

  @override
  String get connectionTimeoutError => '连接超时，请检查网络后重试';

  @override
  String get cannotConnectServerError => '无法连接到服务器，请检查网络';

  @override
  String get serverUnavailableError => '服务器暂时不可用，请稍后重试';

  @override
  String get invalidServerResponseError => '服务器响应异常，请稍后重试';

  @override
  String get unsafeSubscriptionError => '订阅地址不安全，已拒绝使用';

  @override
  String get serverNotConfiguredError => '请先配置服务器地址';

  @override
  String get installerVerificationError => '安装包校验失败，请重新下载';

  @override
  String get updateDownloadError => '更新下载失败，请稍后重试';

  @override
  String get networkRequestError => '网络请求失败，请检查网络后重试';

  @override
  String get invalidCredentialsError => '邮箱或密码错误';

  @override
  String get invalidVerificationCodeError => '验证码错误或已过期';

  @override
  String get accountDisabledError => '当前账号已被禁用，请联系客服';

  @override
  String get unexpectedError => '操作失败，请稍后重试';
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
  String get silentStartup => '靜默啟動到系統匣';

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

  @override
  String get fillEmailPrefix => '請先填寫電子郵件前綴';

  @override
  String get invalidEmail => '請填寫正確的電子郵件地址';

  @override
  String get verificationCodeSent => '驗證碼已傳送，請查收郵件';

  @override
  String get passwordsMismatch => '兩次密碼不一致';

  @override
  String get verificationCodeRequired => '請填寫郵件驗證碼';

  @override
  String get acceptTermsRequired => '請先同意服務條款';

  @override
  String registrationSuccess(String appName) {
    return '註冊成功，歡迎加入 $appName！';
  }

  @override
  String get verificationCode => '驗證碼';

  @override
  String get verificationCodeHint => '請輸入郵件驗證碼';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get confirmPasswordHint => '請再次輸入密碼';

  @override
  String get inviteCode => '邀請碼';

  @override
  String get inviteCodeOptional => '邀請碼（選填）';

  @override
  String get termsAgreementPrefix => '我已閱讀並同意 ';

  @override
  String get termsOfService => '服務條款';

  @override
  String get alreadyHaveAccount => '已有帳號？';

  @override
  String get sendVerificationCode => '傳送驗證碼';

  @override
  String get sending => '傳送中…';

  @override
  String resendIn(int seconds) {
    return '重新傳送 (${seconds}s)';
  }

  @override
  String get resend => '重新傳送';

  @override
  String get allFieldsRequired => '請填寫所有欄位';

  @override
  String get passwordResetSuccess => '密碼重設成功，請重新登入';

  @override
  String get registeredEmailHint => '請輸入註冊電子郵件';

  @override
  String get newPassword => '新密碼';

  @override
  String get newPasswordHint => '請輸入新密碼';

  @override
  String get resetPassword => '重設密碼';

  @override
  String get backToLogin => '返回登入';

  @override
  String get passwordFieldsRequired => '請填寫所有密碼欄位';

  @override
  String get passwordChanged => '密碼修改成功';

  @override
  String get currentPasswordHint => '請輸入目前密碼';

  @override
  String get passwordAdvice => '建議使用 8 位以上字母與數字組合';

  @override
  String get saveChanges => '儲存修改';

  @override
  String get refreshed => '已重新整理';

  @override
  String get connectionSuccess => '連線成功';

  @override
  String get dashboardSubtitle => '查看目前連線、節點與流量狀態';

  @override
  String get all => '全部';

  @override
  String get favorites => '收藏';

  @override
  String get asia => '亞洲';

  @override
  String get europe => '歐洲';

  @override
  String get america => '美洲';

  @override
  String get oceania => '大洋洲';

  @override
  String get nodesSubtitle => '選擇適合你的高速線路';

  @override
  String get selectLineAndLatency => '選擇線路並查看延遲';

  @override
  String get noMatchingNodes => '沒有符合的節點';

  @override
  String get tryDifferentNodeFilter => '換個關鍵字或分區再試試';

  @override
  String get searchNodes => '搜尋節點';

  @override
  String get autoSelect => '自動選擇';

  @override
  String get manualSelect => '手動選擇';

  @override
  String get autoSelectBestDescription => '依延遲自動使用最佳線路';

  @override
  String get autoSelectEnabled => '已開啟自動選擇，將使用最佳節點';

  @override
  String switchedToNode(String node) {
    return '已切換至 $node';
  }

  @override
  String get noTestableNodes => '暫無可測速節點';

  @override
  String get latencyTestComplete => '測速完成';

  @override
  String get latencyTestFailed => '測速失敗，請檢查節點後重試';

  @override
  String get latencyTest => '測速';

  @override
  String get noNodes => '暫無節點';

  @override
  String get waitForSubscription => '若剛登入，請稍候訂閱資料載入完成';

  @override
  String get chooseNode => '選擇節點';

  @override
  String nodeCountSummary(int count) {
    return '$count 個節點 · 篩選線路並查看延遲';
  }

  @override
  String get noNodesSubscription => '暫無節點 · 請檢查訂閱狀態';

  @override
  String get close => '關閉';

  @override
  String get currentNode => '目前節點';

  @override
  String get nodeLoading => '節點載入中';

  @override
  String get nodeStatus => '節點狀態';

  @override
  String get fetchingNodes => '正在取得節點...';

  @override
  String get noAvailableNodes => '暫無可用節點';

  @override
  String get syncingSubscription => '正在同步訂閱資料...';

  @override
  String get subscriptionLoadsAfterLogin => '登入後會自動載入訂閱節點';

  @override
  String get encryptionProtectionEnabled => '加密保護已開啟';

  @override
  String get establishingEncryptedChannel => '正在建立加密通道...';

  @override
  String get closingEncryptedChannel => '正在關閉加密通道...';

  @override
  String get networkNotProtected => '網路目前未受加密保護';

  @override
  String nodeMode(String mode) {
    return '節點模式 · $mode';
  }

  @override
  String get switchNode => '切換節點';

  @override
  String get viewNodes => '查看節點';

  @override
  String get startConnection => '開始連線';

  @override
  String get connecting => '連線中…';

  @override
  String get disconnectConnection => '中斷連線';

  @override
  String get disconnecting => '中斷中…';

  @override
  String get reconnect => '重新連線';

  @override
  String get proxyModeDescriptionRule => '自動分流，本地直連、其他流量走代理';

  @override
  String get proxyModeDescriptionGlobal => '所有流量皆透過代理節點轉送';

  @override
  String get proxyModeDescriptionDirect => '不使用代理，直接連線目標網站';

  @override
  String switchedProxyMode(String mode) {
    return '已切換至 $mode';
  }

  @override
  String get proxyModeNextConnection => '代理模式將於下次連線後生效';

  @override
  String get ruleMode => '規則';

  @override
  String get globalMode => '全域';

  @override
  String get directMode => '直連';

  @override
  String get currentLatency => '目前延遲';

  @override
  String get downloadSpeed => '下載速度';

  @override
  String get uploadSpeed => '上傳速度';

  @override
  String get subscriptionExpired => '訂閱已到期，連線將無法使用';

  @override
  String get subscriptionExpiresToday => '訂閱今日到期，請及時續費';

  @override
  String subscriptionExpiresInDays(int days) {
    return '訂閱將於 $days 天後到期';
  }

  @override
  String get renewNow => '前往續費 →';

  @override
  String get renewPlan => '續費';

  @override
  String get retry => '重試';

  @override
  String get businessEdition => '商務版';

  @override
  String get protected => '保護中';

  @override
  String get connectionFailed => '連線失敗';

  @override
  String get notConnected => '未連線';

  @override
  String get unavailable => '暫未開放';

  @override
  String get androidLimitedNotice => '目前 Android 版本先提供登入、購買與節點查看';

  @override
  String get syncingNodes => '正在同步節點...';

  @override
  String get selectNodePrompt => '請選擇節點';

  @override
  String nodeModeLabel(String mode) {
    return '節點模式：$mode';
  }

  @override
  String get buyPlans => '購買方案';

  @override
  String get buyPlansSubtitle => '選擇適合你的方案和流量包';

  @override
  String get planPurchase => '方案購買';

  @override
  String get recurringPlan => '週期方案';

  @override
  String get oneTime => '一次性';

  @override
  String get dataPack => '流量包';

  @override
  String get noPlans => '暫無方案資訊';

  @override
  String get refreshLater => '請稍後重新整理再試';

  @override
  String get unlimitedTime => '/ 不限時';

  @override
  String get oneTimePlan => '一次性方案';

  @override
  String devicesCount(int count) {
    return '$count 台裝置';
  }

  @override
  String get unlimitedDevices => '不限裝置';

  @override
  String get popular => '熱門';

  @override
  String get recommended => '推薦';

  @override
  String get buyNow => '立即購買';

  @override
  String get unavailableForPurchase => '暫不可購買';

  @override
  String get monthly => '月付';

  @override
  String get quarterly => '季付';

  @override
  String get halfYear => '半年';

  @override
  String get yearly => '年付';

  @override
  String get perMonth => '/ 月';

  @override
  String get perQuarter => '/ 季';

  @override
  String get perHalfYear => '/ 半年';

  @override
  String get perYear => '/ 年';

  @override
  String get orderHistorySubtitle => '查看購買與付款記錄';

  @override
  String get order => '訂單';

  @override
  String get orderLoadFailed => '訂單載入失敗';

  @override
  String get noOrders => '暫無訂單';

  @override
  String get ordersAppearAfterPurchase => '購買方案後會顯示在這裡';

  @override
  String get orderCancelled => '訂單已取消';

  @override
  String get accountTopUp => '帳戶儲值';

  @override
  String orderNumber(String number) {
    return '訂單編號 $number';
  }

  @override
  String get type => '類型';

  @override
  String get date => '日期';

  @override
  String get amount => '金額';

  @override
  String get status => '狀態';

  @override
  String get cancelOrder => '取消訂單';

  @override
  String get continuePayment => '繼續付款';

  @override
  String get processing => '處理中';

  @override
  String get cancelOrderConfirm => '確認取消此待付款訂單？取消後需要重新下單。';

  @override
  String get thinkAgain => '再想想';

  @override
  String get confirmCancel => '確認取消';

  @override
  String get inviteFriends => '邀請好友';

  @override
  String get inviteSubtitle => '分享邀請連結並查看佣金記錄';

  @override
  String get inviteCommission => '邀請返佣';

  @override
  String get inviteCodeCreated => '邀請碼已建立';

  @override
  String get inviteLink => '邀請連結';

  @override
  String get copyLink => '複製連結';

  @override
  String get creating => '建立中';

  @override
  String get createInviteCode => '建立邀請碼';

  @override
  String inviteCodeIndex(int index) {
    return '邀請碼 $index';
  }

  @override
  String get inviteLinkUnavailable => '邀請連結未設定';

  @override
  String get registeredUsers => '已註冊使用者';

  @override
  String peopleCount(int count) {
    return '$count 人';
  }

  @override
  String get pendingCommission => '確認中佣金';

  @override
  String get totalCommission => '累計佣金';

  @override
  String get commissionRate => '佣金比例';

  @override
  String get commissionRecords => '佣金記錄';

  @override
  String get noCommissionRecords => '暫無佣金記錄';

  @override
  String get invitedUser => '受邀使用者';

  @override
  String recordOrderAmount(String date, String amount) {
    return '$date · 訂單 $amount';
  }

  @override
  String get copied => '已複製';

  @override
  String linkCopiedForApp(String app) {
    return '連結已複製，可貼到$app';
  }

  @override
  String get confirmOrder => '確認訂單';

  @override
  String get selectBillingCycle => '選擇週期';

  @override
  String get couponCode => '優惠碼';

  @override
  String get couponHint => '輸入優惠碼（選填）';

  @override
  String get remove => '移除';

  @override
  String get verifying => '驗證中…';

  @override
  String get verify => '驗證';

  @override
  String get couponApplied => '優惠碼已套用';

  @override
  String get invalidCoupon => '優惠碼無效';

  @override
  String discountAmount(String amount) {
    return '已優惠 $amount';
  }

  @override
  String discountPercent(int percent) {
    return '已優惠 $percent%';
  }

  @override
  String get originalPrice => '方案原價';

  @override
  String get discount => '優惠折抵';

  @override
  String get totalDue => '應付總計';

  @override
  String get cancel => '取消';

  @override
  String get submitOrder => '提交訂單';

  @override
  String operationFailed(String operation, String error) {
    return '$operation失敗：$error';
  }

  @override
  String get selectPaymentMethod => '選擇付款方式';

  @override
  String get browserPayment => '瀏覽器付款';

  @override
  String get scanToPay => '掃碼付款';

  @override
  String get paymentSuccess => '付款成功';

  @override
  String get paymentTimedOut => '付款已逾時';

  @override
  String get qrExpired => 'QR Code 已過期';

  @override
  String get amountDue => '應付金額';

  @override
  String get balanceApplied => '餘額已折抵';

  @override
  String get subscriptionCredit => '舊訂閱折抵';

  @override
  String get refundAmountLabel => '退款金額';

  @override
  String get paymentHandlingFee => '付款手續費';

  @override
  String paymentFeeDescription(String value) {
    return '手續費：$value';
  }

  @override
  String get balancePayment => '餘額付款';

  @override
  String get activateWithBalance => '使用餘額啟用';

  @override
  String get choosePaymentMethod => '選擇付款方式';

  @override
  String get noPaymentMethods => '暫無可用付款方式';

  @override
  String get payNow => '前往付款';

  @override
  String get scanWithPhone => '使用手機掃碼完成付款';

  @override
  String get openInBrowser => '或在瀏覽器開啟';

  @override
  String remainingTime(String time) {
    return '剩餘 $time';
  }

  @override
  String get paymentCompleted => '我已完成付款';

  @override
  String get paymentNotDetected => '暫未偵測到付款，請稍後再試';

  @override
  String get paymentProcessing => '訂單正在處理中，狀態會自動更新';

  @override
  String get orderActivated => '訂單已啟用，請重新整理頁面查看';

  @override
  String get done => '完成';

  @override
  String get refreshQrCode => '重新整理 QR Code';

  @override
  String get getPaymentMethods => '取得付款方式';

  @override
  String get startPayment => '發起付款';

  @override
  String get queryPayment => '查詢';

  @override
  String get refreshPayment => '重新整理';

  @override
  String get orderPending => '待付款';

  @override
  String get orderProcessing => '處理中';

  @override
  String get orderCancelledStatus => '已取消';

  @override
  String get orderCompleted => '已完成';

  @override
  String get orderFailed => '失敗';

  @override
  String get twoYears => '兩年';

  @override
  String get threeYears => '三年';

  @override
  String get perTwoYears => '/ 兩年';

  @override
  String get perThreeYears => '/ 三年';

  @override
  String get orderDiscounted => '已折抵';

  @override
  String get soldOut => '已售罄';

  @override
  String lowStockRemaining(int count) {
    return '僅剩 $count 份';
  }

  @override
  String existingPlanSwitchWarning(String current, String target) {
    return '你目前正在使用「$current」。購買「$target」可能取代或折抵現有訂閱，請確認後再繼續。';
  }

  @override
  String get unknown => '未知';

  @override
  String get buyout => '買斷';

  @override
  String get wechat => 'WeChat';

  @override
  String get connectionInProgress => '連線處理中';

  @override
  String get connected => '已連線';

  @override
  String diagnosticPlatform(String platform) {
    return '平台：$platform';
  }

  @override
  String diagnosticConnectionStatus(String status) {
    return '連線狀態：$status';
  }

  @override
  String diagnosticProxyPort(int port) {
    return '本機代理連接埠：$port';
  }

  @override
  String diagnosticRecordedAt(String time) {
    return '記錄時間：$time';
  }

  @override
  String diagnosticRecentError(String error) {
    return '最近錯誤：$error';
  }

  @override
  String get noRuntimeLogs => '暫無執行記錄，請先嘗試連線後再查看。';

  @override
  String get systemDns => '系統 DNS';

  @override
  String get httpSecurityWarning =>
      '目前伺服器使用 HTTP 連線，資料傳輸未加密，可能遭到攔截。建議聯絡服務商啟用 HTTPS。';

  @override
  String get diagnosticCopyDescription => '複製後傳送給管理員或客服，可協助快速定位問題';

  @override
  String get diagnosticCopied => '診斷資訊已複製，請傳送給管理員或客服';

  @override
  String get copyDiagnostics => '一鍵複製';

  @override
  String get restartClientError => '連線失敗，請重新啟動用戶端後再試';

  @override
  String get proxyPortUnavailableError => '本機代理連接埠啟動失敗，請關閉其他代理軟體後再試';

  @override
  String get missingCoreError => '連線失敗，找不到 mihomo 核心';

  @override
  String get permissionDeniedError => '權限不足，請以管理員身分執行用戶端';

  @override
  String get tunInterfaceUnavailableError => 'TUN 虛擬網卡啟動失敗，請檢查系統權限後再試';

  @override
  String get tunKillSwitchUnavailableError => 'TUN 中斷保護啟動失敗，已停止連線以避免流量外洩';

  @override
  String get androidStartFailedError => 'Android 核心啟動失敗';

  @override
  String get unexpectedCoreExitError => '核心異常退出，連線已中斷，請重新連線';

  @override
  String get invalidNodeConfigError => '目前節點設定無效，請切換節點後再試';

  @override
  String get genericConnectionFailureError => '連線失敗，請切換節點或稍後再試';

  @override
  String get configBuildFailedError => '產生設定失敗，請選擇其他節點後再試';

  @override
  String get cachedModeActive => '伺服器連線失敗，已啟用本機快取模式，不影響已快取節點使用。';

  @override
  String get serverUnavailableNoCache => '目前無法連線伺服器，且沒有本機節點快取，請檢查網路或聯絡客服。';

  @override
  String get trafficStatistics => '流量統計';

  @override
  String get trafficStatisticsSubtitle => '查看流量、裝置和方案週期';

  @override
  String remainingTraffic(String value) {
    return '剩餘 $value GB';
  }

  @override
  String get onlineDevices => '在線裝置';

  @override
  String get currentOnlineDevices => '目前在線裝置數';

  @override
  String get remainingDays => '剩餘天數';

  @override
  String get permanent => '永久';

  @override
  String get daysUnit => '天';

  @override
  String get subscriptionLongTerm => '訂閱長期有效';

  @override
  String expiresAt(String date) {
    return '到期 $date';
  }

  @override
  String get trafficResetTime => '流量重設時間';

  @override
  String get neverResets => '不重設';

  @override
  String daysCount(int count) {
    return '$count 天';
  }

  @override
  String get noTrafficReset => '目前方案未設定重設週期';

  @override
  String get untilNextReset => '距下次重設';

  @override
  String get trafficTrend => '流量趨勢圖';

  @override
  String periodTrafficTotal(String period, String total) {
    return '$period 共 $total';
  }

  @override
  String recentDays(int count) {
    return '最近$count天';
  }

  @override
  String tooltipUpload(String value) {
    return '上行 $value';
  }

  @override
  String tooltipDownload(String value) {
    return '下行 $value';
  }

  @override
  String tooltipTotal(String value) {
    return '合計 $value';
  }

  @override
  String get weekdayShort => '週一,週二,週三,週四,週五,週六,週日';

  @override
  String get ticketSupport => '工單支援';

  @override
  String get ticketSupportSubtitle => '提交問題並查看回覆';

  @override
  String get tickets => '工單';

  @override
  String get ticketSupportCompactSubtitle => '提交問題並查看客服回覆';

  @override
  String get newTicket => '新增工單';

  @override
  String get ticketLoadFailed => '工單載入失敗';

  @override
  String get noTickets => '暫無工單';

  @override
  String get noTicketsSubtitle => '有問題可以新增工單聯絡客服';

  @override
  String get untitledTicket => '未命名工單';

  @override
  String get ticketFieldsRequired => '請填寫標題和問題描述';

  @override
  String get ticketSubjectTooShort => '問題標題至少需要 5 個字元';

  @override
  String get ticketMessageTooShort => '問題描述至少需要 10 個字元';

  @override
  String get ticketSubmitted => '工單已提交';

  @override
  String get ticketSubscriptionMismatch => '目前套餐有效，但工單介面未同步套餐狀態，請稍後重試或聯絡管理員';

  @override
  String get issueSubject => '問題標題';

  @override
  String get issueSubjectHint => '用一句話描述你的問題';

  @override
  String get priority => '優先級';

  @override
  String get issueDescription => '問題描述';

  @override
  String get issueDescriptionHint => '詳細描述你遇到的問題';

  @override
  String get submitting => '提交中...';

  @override
  String get submitTicket => '提交工單';

  @override
  String get replyRequired => '請輸入回覆內容';

  @override
  String get replySent => '回覆已傳送';

  @override
  String get ticketClosed => '工單已關閉';

  @override
  String get ticketDetails => '工單詳情';

  @override
  String get replyHint => '輸入回覆內容';

  @override
  String get closing => '關閉中...';

  @override
  String get closeTicket => '關閉工單';

  @override
  String get sendReply => '傳送回覆';

  @override
  String get priorityLow => '低';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityUrgent => '緊急';

  @override
  String get noTicketMessages => '暫無訊息記錄';

  @override
  String get customerSupport => '客服';

  @override
  String get me => '我';

  @override
  String get ticketClosedStatus => '已關閉';

  @override
  String get invalidRechargeAmount => '請輸入有效的儲值金額';

  @override
  String get noTransferableCommission => '暫無可劃轉佣金';

  @override
  String get withdrawalUnavailable => '提現暫未開放';

  @override
  String get noWithdrawableCommission => '暫無可提現佣金';

  @override
  String get noWithdrawalMethods => '暫無可用提現方式';

  @override
  String get myWallet => '我的錢包';

  @override
  String get myWalletSubtitle => '查看餘額、佣金與儲值';

  @override
  String get accountAssets => '帳戶資產';

  @override
  String get accountBalance => '帳戶餘額';

  @override
  String get withdrawableCommission => '可提現佣金';

  @override
  String get transferCommission => '佣金劃轉';

  @override
  String get transferShort => '劃轉';

  @override
  String get requestWithdrawal => '申請提現';

  @override
  String get withdrawShort => '提現';

  @override
  String get rechargeBalance => '儲值餘額';

  @override
  String get rechargeBalanceNotice => '儲值後的餘額僅限消費，無法提現';

  @override
  String get customAmount => '自訂金額';

  @override
  String get rechargeAmountHint => '請輸入儲值金額';

  @override
  String get recharge => '儲值';

  @override
  String get transferAmountRequired => '請輸入劃轉金額';

  @override
  String get transferAmountTooHigh => '劃轉金額不能超過可提現佣金';

  @override
  String get commissionTransferred => '佣金已劃轉到餘額';

  @override
  String get transferCommissionNotice => '將可提現佣金劃轉到帳戶餘額，劃轉後可用於購買方案。';

  @override
  String get transferAmount => '劃轉金額';

  @override
  String transferableAmount(String amount) {
    return '可劃轉 $amount';
  }

  @override
  String get transferring => '劃轉中...';

  @override
  String get confirmTransfer => '確認劃轉';

  @override
  String get withdrawalAmountRequired => '請輸入提現金額';

  @override
  String get withdrawalAmountTooHigh => '提現金額不能超過可提現佣金';

  @override
  String minimumWithdrawal(String amount) {
    return '最低提現金額為 $amount';
  }

  @override
  String get withdrawalAccountRequired => '請輸入提現帳戶';

  @override
  String get withdrawalSubmitted => '提現工單已提交';

  @override
  String get withdrawalMethod => '提現方式';

  @override
  String get withdrawalAccount => '提現帳戶';

  @override
  String get withdrawalAccountHint => '請輸入收款帳號';

  @override
  String get withdrawalAmount => '提現金額';

  @override
  String withdrawableAmount(String amount) {
    return '可提現 $amount';
  }

  @override
  String withdrawableWithMinimum(String amount, String minimum) {
    return '可提現 $amount · 最低 $minimum';
  }

  @override
  String get submitWithdrawal => '提交提現';

  @override
  String itemCopied(String item) {
    return '$item 已複製';
  }

  @override
  String get settingsUpdated => '設定已更新';

  @override
  String get myAccount => '我的帳戶';

  @override
  String get myAccountSubtitle => '查看帳戶資訊與訂閱詳情';

  @override
  String get expiredStatus => '已到期';

  @override
  String get suspendedStatus => '已停權';

  @override
  String get normalStatus => '正常';

  @override
  String get accountInformation => '帳戶資訊';

  @override
  String get accountStatus => '帳戶狀態';

  @override
  String get expiryTime => '到期時間';

  @override
  String get balanceAndRecharge => '餘額與儲值';

  @override
  String get purchaseAndPayment => '購買與付款';

  @override
  String get usageRecords => '使用記錄';

  @override
  String get contactAfterSales => '聯絡售後';

  @override
  String get resetDayUnavailable => '重設日 --';

  @override
  String monthlyResetDay(int day) {
    return '每月 $day 日重設';
  }

  @override
  String get trafficOverview => '流量概覽';

  @override
  String usedPercent(String percent) {
    return '已用 $percent%';
  }

  @override
  String get remaining => '剩餘';

  @override
  String usedTraffic(String used, String total) {
    return '已用 $used / $total GB';
  }

  @override
  String get currentPlan => '目前方案';

  @override
  String get noCurrentPlan => '暫無方案';

  @override
  String get noPlanDescription => '目前沒有有效方案，購買方案後即可取得節點和流量。';

  @override
  String get logout => '登出';

  @override
  String get logoutDataNotice => '目前登入狀態和本機節點快取將被清除';

  @override
  String get logoutConfirmMessage => '確認登出目前帳號？登出後需要重新登入。';

  @override
  String get confirmLogout => '確認登出';

  @override
  String currentPlanValue(String plan) {
    return '目前方案：$plan';
  }

  @override
  String expiryValue(String expiry) {
    return '到期：$expiry';
  }

  @override
  String get manage => '管理';

  @override
  String get accountManagement => '帳號管理';

  @override
  String get expiryReminder => '到期提醒';

  @override
  String get expiryReminderSubtitle => '接收帳戶到期提醒郵件';

  @override
  String get trafficReminder => '流量提醒';

  @override
  String get trafficReminderSubtitle => '接收流量用盡提醒郵件';

  @override
  String get autoRenewal => '自動續費';

  @override
  String get autoRenewalSubtitle => '到期前自動續費方案';

  @override
  String get updateLoginPassword => '更新登入密碼';

  @override
  String get logoutCurrentAccount => '登出目前帳號';

  @override
  String get passwordTooShort => '新密碼至少需要 8 位';

  @override
  String get currentPassword => '目前密碼';

  @override
  String get confirmNewPassword => '確認新密碼';

  @override
  String get confirmNewPasswordHint => '請再次輸入新密碼';

  @override
  String get updating => '更新中...';

  @override
  String get confirmChange => '確認修改';

  @override
  String get trayConnectedTun => '已連線 · 虛擬網卡';

  @override
  String get trayConnectedSystemProxy => '已連線 · 系統代理';

  @override
  String openApp(String appName) {
    return '開啟 $appName';
  }

  @override
  String trayNode(String node) {
    return '節點：$node';
  }

  @override
  String get connectNow => '立即連線';

  @override
  String get repairSystemProxy => '修復系統代理';

  @override
  String get quit => '結束';

  @override
  String get cannotOpenUpdateUrl => '無法開啟更新下載網址';

  @override
  String get downloadPageOpened => '已開啟下載頁面';

  @override
  String get downloadCompleteOpeningInstaller => '下載完成，正在開啟安裝程式';

  @override
  String newVersionAvailable(String version) {
    return '發現新版本 v$version，點擊下載最新版本';
  }

  @override
  String get downloadNow => '立即下載';

  @override
  String get refresh => '重新整理';

  @override
  String get back => '返回';

  @override
  String get search => '搜尋';

  @override
  String get backToAccount => '返回我的';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get requestFailed => '請求失敗，請稍後重試';

  @override
  String get sessionExpiredError => '登入已過期，請重新登入';

  @override
  String get tooManyRequestsError => '操作太頻繁，請稍後再試';

  @override
  String get invalidSubmissionError => '提交內容有誤，請檢查後重試';

  @override
  String get connectionTimeoutError => '連線逾時，請檢查網路後重試';

  @override
  String get cannotConnectServerError => '無法連線到伺服器，請檢查網路';

  @override
  String get serverUnavailableError => '伺服器暫時無法使用，請稍後重試';

  @override
  String get invalidServerResponseError => '伺服器回應異常，請稍後重試';

  @override
  String get unsafeSubscriptionError => '訂閱網址不安全，已拒絕使用';

  @override
  String get serverNotConfiguredError => '請先設定伺服器位址';

  @override
  String get installerVerificationError => '安裝程式驗證失敗，請重新下載';

  @override
  String get updateDownloadError => '更新下載失敗，請稍後重試';

  @override
  String get networkRequestError => '網路請求失敗，請檢查網路後重試';

  @override
  String get invalidCredentialsError => '電子郵件或密碼錯誤';

  @override
  String get invalidVerificationCodeError => '驗證碼錯誤或已過期';

  @override
  String get accountDisabledError => '目前帳號已被停用，請聯絡客服';

  @override
  String get unexpectedError => '操作失敗，請稍後重試';
}
