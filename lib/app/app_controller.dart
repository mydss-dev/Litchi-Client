import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_locale_preference.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/services/account_summary_cache.dart';
import '../shared/services/api_client.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/desktop_network_monitor.dart';
import '../shared/services/network_error_classifier.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/register_config_cache.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/windows_shell.dart';
import '../shared/services/token_storage.dart';
import '../shared/services/update_service.dart';
import 'account_controller.dart';
import 'core_connection_request.dart';
import 'core_controller.dart';
import 'core_error_message_service.dart';
import 'invite_controller.dart';
import 'node_controller.dart';
import 'notices_controller.dart';
import 'settings_controller.dart';
import 'subscription_controller.dart';
import 'wallet_controller.dart';

enum AppPage {
  dashboard,
  nodes,
  shop,
  traffic,
  invite,
  settings,
  account,
  wallet,
  orders,
  tickets,
}

enum AuthScreen { login, register, changePassword, forgotPassword }

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController() {
    AppConfig.revision.addListener(_onRemoteConfigChanged);
    _settings.addListener(notifyListeners);
    _core.addListener(_onCoreChanged);
    _core.addListener(notifyListeners);
    _notices.addListener(notifyListeners);
    _subscription.addListener(notifyListeners);
    _wallet.addListener(notifyListeners);
    _invite.addListener(notifyListeners);
    _account.addListener(notifyListeners);
    _nodes.addListener(notifyListeners);
    WidgetsBinding.instance.addObserver(this);
  }

  final SettingsController _settings = SettingsController();
  final CoreController _core = CoreController();
  final NodeController _nodes = NodeController();
  final NoticesController _notices = NoticesController();
  final SubscriptionController _subscription = SubscriptionController();
  final DesktopNetworkMonitor _desktopNetworkMonitor = DesktopNetworkMonitor();
  late final WalletController _wallet = WalletController(_api, refreshData);
  late final InviteController _invite = InviteController(_api, refreshData);
  late final AccountController _account = AccountController(_api);

  final ApiClient _apiClient = ApiClient();
  late final PanelApi _api = PanelApi(_apiClient);
  late final DataLoader _dataLoader = DataLoader(_api);

  bool _isAuthenticated = false;
  bool _isInitializing = true;
  AppPage _page = AppPage.dashboard;
  AuthScreen _authScreen = AuthScreen.login;
  bool _mobileProfileChildPage = false;

  List<PlanModel> _plans = const [];
  String? _dataLoadError;
  String? _startupMessage;
  UpdateInfo? _updateInfo;
  RegisterConfig _registerConfig = const RegisterConfig();
  bool _disposed = false;
  bool _isInitialLoading = false;
  bool _logoutInFlight = false;
  int _latencyRunId = 0;
  String? _authData;
  Future<void>? _accountSummarySave;
  bool _hasAccountSummary = false;
  int _sessionEpoch = 0;

  Timer? _statusRefreshTimer;
  bool _statusRefreshInFlight = false;
  bool _nodesRefreshInFlight = false;
  bool _desktopRecoveryInFlight = false;
  DateTime? _lastNodesRefreshAt;
  static const Duration _statusRefreshInterval = Duration(minutes: 5);
  static const Duration _nodesRefreshMaxAge = Duration(minutes: 30);

  ThemeMode get themeMode => _settings.themeMode;
  bool get isDark => _settings.isDark;
  bool get autoStart => _settings.autoStart;
  bool get silentStart => _settings.silentStart;
  bool get autoUpdate => _settings.autoUpdate;
  AppLocalePreference get language => _settings.language;
  Locale? get locale => _settings.language.locale;
  ProxyMode get proxyMode => _settings.proxyMode;
  NetworkMode get networkMode => _settings.networkMode;
  String get dnsMode => _settings.dnsMode;
  int get proxyPort => _settings.proxyPort;
  int get activeProxyPort =>
      _core.coreProcessRunning ? _core.activeProxyPort : _settings.proxyPort;
  bool get killSwitch => _settings.killSwitch;

  void setThemeMode(ThemeMode mode) => _settings.setThemeMode(mode);
  void toggleDarkMode(bool enabled) => _settings.toggleDarkMode(enabled);
  void setAutoStart(bool v) => _settings.setAutoStart(v);
  void setSilentStart(bool v) => _settings.setSilentStart(v);
  void setAutoUpdate(bool v) {
    _settings.setAutoUpdate(v);
    if (!v) {
      dismissUpdate();
    } else {
      unawaited(_checkForUpdate());
    }
  }

  void setLanguage(AppLocalePreference v) => _settings.setLanguage(v);

  Future<void> setProxyPort(int port) async {
    final old = _settings.proxyPort;
    await _settings.setProxyPort(port);
    if (_settings.proxyPort != old) unawaited(_reloadCoreConfig());
  }

  void setKillSwitch(bool v) {
    _settings.setKillSwitch(v);
    unawaited(_applyKillSwitchSetting(v));
  }

  Future<void> _applyKillSwitchSetting(bool enabled) async {
    final applied = await _core.setKillSwitchEnabled(enabled);
    if (!applied && enabled) {
      _settings.setKillSwitch(false);
      _startupMessage = CoreErrorMessageService.tunKillSwitchUnavailable;
      notifyListeners();
    }
  }

  Future<String?> setProxyMode(ProxyMode v) async {
    final old = _settings.proxyMode;
    if (old == v) return null;

    _settings.setProxyMode(v);

    if (_core.coreProcessRunning) {
      final ok = await _core.setMode(v);
      if (!ok) {
        _settings.setProxyMode(old);
        return '模式切换失败，请重试';
      }
    }

    return null;
  }

  void setNetworkMode(NetworkMode v) {
    final old = _settings.networkMode;
    _settings.setNetworkMode(v);
    if (_settings.networkMode != old) unawaited(_reloadCoreConfig());
  }

  void setDnsMode(String v) {
    final old = _settings.dnsMode;
    _settings.setDnsMode(v);
    if (_settings.dnsMode != old) unawaited(_reloadCoreConfig());
  }

  ConnectionStatus get connectionStatus => _core.connectionStatus;
  bool get coreRunning => _core.coreRunning;
  bool get coreConnecting => _core.coreConnecting;
  bool get connectionActionLocked => _core.connectionActionLocked;
  String get coreError => _core.coreError;
  int get upBps => _core.upBps;
  int get downBps => _core.downBps;
  ValueNotifier<int> get upBpsNotifier => _core.upBpsNotifier;
  ValueNotifier<int> get downBpsNotifier => _core.downBpsNotifier;
  Stream<String> get coreLogStream => _core.logStream;
  List<String> get coreLogs => _core.recentLogs;
  Duration get connectedDuration => _core.connectedDuration;
  bool get coreProcessRunning => _core.coreProcessRunning;
  bool get supportsCoreConnection =>
      Platform.isWindows || Platform.isMacOS || Platform.isAndroid;

  Future<void> shutdown() => _core.shutdown();

  Future<String?> restartCore() async {
    if (!coreRunning) return null;
    await toggleConnection();
    await Future.delayed(const Duration(milliseconds: 800));
    return toggleConnection();
  }

  Future<void> fixProxy() =>
      _core.fixProxy(activeProxyPort, networkMode: _settings.networkMode);
  static Future<String> getCoreVersion() => CoreController.getCoreVersion();

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  AppPage get page => _page;
  AuthScreen get authScreen => _authScreen;
  bool get mobileProfileChildPage => _mobileProfileChildPage;

  UserModel get user => _account.user;
  RemoteUser? get accountDetails => _account.remoteUser;
  TrafficModel get traffic => _account.traffic;
  bool get autoSelected => _nodes.autoSelected;
  NodeModel get currentNode => _nodes.currentNode;
  List<NodeModel> get nodes => _nodes.nodes;
  List<PlanModel> get plans => _plans;
  List<InviteCodeModel> get inviteCodes => _invite.inviteCodes;
  String get inviteCode => _invite.inviteCode;
  String get inviteLink => _invite.inviteLink;
  List<RemoteInviteRecord> get inviteRecords => _wallet.inviteRecords;
  double get commissionRate => _wallet.commissionRate;
  int get invitedCount => _wallet.invitedCount;
  double get earnedCommission => _wallet.earnedCommission;
  double get pendingCommission => _wallet.pendingCommission;
  double get withdrawable => _wallet.withdrawable;
  bool get withdrawEnabled => _wallet.withdrawEnabled;
  List<String> get withdrawMethods => _wallet.withdrawMethods;
  double get minWithdrawAmount => _wallet.minWithdrawAmount;
  List<double> get dailyUsage => _subscription.dailyUsage;
  List<TrafficUsagePoint> get trafficUsage => _subscription.trafficUsage;

  double get todayTrafficGb {
    final now = DateTime.now();
    var total = 0.0;
    for (final point in _subscription.trafficUsage) {
      final date = point.date;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        total += point.totalGb;
      }
    }
    return total;
  }

  int? get aliveIp => _subscription.aliveIp;
  int? get deviceLimit => _subscription.deviceLimit;
  int? get resetDay => _subscription.resetDay;
  int? get expiredAt => _subscription.expiredAt;
  String? get dataLoadError => _dataLoadError;
  bool get isInitialLoading => _isInitialLoading;
  bool get hasAccountSummary => _hasAccountSummary;
  String get currencySymbol => _wallet.currencySymbol;
  String? get startupMessage => _startupMessage;
  void clearStartupMessage() => _startupMessage = null;
  PanelApi get api => _api;
  UpdateInfo? get updateInfo => _updateInfo;
  RegisterConfig get registerConfig => _registerConfig;
  List<NoticeModel> get notices => _notices.notices;
  bool get hasUnreadNotice => _notices.hasUnreadNotice;

  void dismissUpdate() {
    _updateInfo = null;
    notifyListeners();
  }

  void markNoticeRead() => _notices.markRead();

  Future<void> init() async {
    await _settings.load();
    await _notices.loadLastSeen();
    await _core.init();
    if (Platform.isAndroid) {
      if (_core.quickTileDisconnected) {
        _settings.setWasConnected(false);
      } else if (_core.coreRunning) {
        _settings.setWasConnected(true);
      }
    }
    await _core.setKillSwitchEnabled(_settings.killSwitch);
    await _desktopNetworkMonitor.start(_recoverDesktopConnection);

    _apiClient.configure(AppConfig.effectiveApiBases);
    _apiClient.onSessionExpired = logout;
    await _loadCachedRegisterConfig();
    unawaited(refreshRegisterConfigCache());

    final authData = await TokenStorage.getAuthData();
    if (authData == null || authData.isEmpty) {
      _isInitializing = false;
      notifyListeners();
      unawaited(_checkForUpdate());
      return;
    }

    _apiClient.updateAuthData(authData);
    _authData = authData;
    await Future.wait([
      _restoreCachedNodes(),
      _restoreCachedAccountSummary(authData),
    ]);

    _isAuthenticated = true;
    final sessionEpoch = ++_sessionEpoch;
    _startStatusRefresh();
    _isInitialLoading = true;
    _isInitializing = false;
    notifyListeners();

    // Deferred: _refreshAfterAutoLogin() will verify the account with the
    // API before auto-reconnecting — never connect before we know the
    // session is still valid.
    unawaited(_refreshAfterAutoLogin(sessionEpoch));
    unawaited(_checkForUpdate());
  }

  Future<void> _loadCachedRegisterConfig() async {
    final cached = await RegisterConfigCache.load(AppConfig.apiBase);
    if (cached == null) return;
    _registerConfig = cached;
  }

  Future<void> _restoreCachedNodes() async {
    final cached = await NodeCacheService.load();
    if (cached.isEmpty) return;
    _invalidateLatencyRuns();
    _nodes.setNodes(cached);
    _restoreLastNode();
    if (supportsCoreConnection) unawaited(_preloadCoreAndTestLatencies());
  }

  Future<void> _restoreCachedAccountSummary(String authData) async {
    final cached = await AccountSummaryCache.load(authData);
    if (cached == null) return;
    _hasAccountSummary = true;
    _account.applySnapshot(user: cached.user, traffic: cached.traffic);
    _subscription.applySnapshot(
      aliveIp: cached.aliveIp,
      deviceLimit: cached.deviceLimit,
      resetDay: cached.resetDay,
      expiredAt: cached.expiredAt,
    );
  }

  Future<void> refreshRegisterConfigCache() async {
    try {
      final config = await _api.fetchRegisterConfig();
      await RegisterConfigCache.save(AppConfig.apiBase, config);
      _registerConfig = config;
      if (!_disposed) notifyListeners();
    } catch (e) {
      SecureLogger.debug('register config cache refresh failed', e);
    }
  }

  Future<void> _refreshAfterAutoLogin(int sessionEpoch) async {
    final sw = Stopwatch()..start();
    try {
      await _loadAllData(sessionEpoch);
      if (!_isSessionCurrent(sessionEpoch)) return;
      _dataLoadError = null;
      _isInitialLoading = false;
      if (!_disposed) notifyListeners();

      // API confirmed the account is still valid — safe to auto-reconnect.
      if (_settings.wasConnected) {
        unawaited(_tryAutoReconnectSafely());
      }
    } catch (e) {
      if (!_isSessionCurrent(sessionEpoch)) return;
      SecureLogger.warn(
        'Auth background refresh failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
      if (NetworkErrorClassifier.isNetworkError(e)) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
        if (!_disposed) notifyListeners();

        // Network error with cached nodes — cached-mode connection is safe.
        if (_settings.wasConnected && _nodes.isNotEmpty) {
          unawaited(toggleConnection().then((_) {}));
        }
        return;
      }

      await _expireSessionAndStopCore('登录已过期，请重新登录');
    }
  }

  /// Quick API check before auto-reconnecting so we never bring up the core
  /// on an expired / banned / out-of-traffic account.  Only a genuine network
  /// error permits cached-mode connection; any other failure expires the
  /// session and stops the core (if running).
  Future<void> _tryAutoReconnectSafely() async {
    try {
      await _api.getSubscribeInfo();
      // Backend confirmed account status is valid.
      await toggleConnection();
    } catch (e) {
      if (NetworkErrorClassifier.isNetworkError(e)) {
        // Only a confirmed network blip allows cached-mode connection.
        await toggleConnection();
        return;
      }
      // Token expired, account banned, plan exhausted, etc.
      await _expireSessionAndStopCore('登录已过期，请重新登录');
    }
  }

  Future<void> _checkForUpdate() async {
    if (!_settings.autoUpdate) return;
    final info = UpdateService.check();
    if (info != null && !_disposed) {
      _updateInfo = info;
      notifyListeners();
    }
  }

  // ── Account status refresh (lightweight timer for traffic / expiry / devices)

  /// Applies only the account & subscription counter fields, without touching
  /// nodes or latency state.
  void _applyAccountStatus(DataSnapshot snap) {
    if (snap.user != null || snap.subscribeUrl != null) {
      _hasAccountSummary = true;
    }
    if (snap.user != null) {
      final fresh = snap.user!;
      final previous = _account.user;
      final merged = fresh.copyWith(
        plan: fresh.plan.trim().isEmpty && previous.plan.trim().isNotEmpty
            ? previous.plan
            : fresh.plan,
        expiry: fresh.expiry.trim().isEmpty && previous.expiry.trim().isNotEmpty
            ? previous.expiry
            : fresh.expiry,
      );
      snap.user = merged;
      _account.applySnapshot(
        remoteUser: snap.remoteUser,
        user: merged,
        traffic: snap.traffic,
      );
    }
    _subscription.applySnapshot(
      subscribeUrl: snap.subscribeUrl,
      aliveIp: snap.aliveIp,
      deviceLimit: snap.deviceLimit,
      resetDay: snap.resetDay,
      expiredAt: snap.expiredAt,
    );
    _saveAccountSummary();
    if (!_disposed) notifyListeners();
  }

  void _saveAccountSummary() {
    final authData = _authData;
    if (authData == null || authData.isEmpty) return;
    final user = _account.user;
    final traffic = _account.traffic;
    final aliveIp = _subscription.aliveIp;
    final deviceLimit = _subscription.deviceLimit;
    final resetDay = _subscription.resetDay;
    final expiredAt = _subscription.expiredAt;
    _accountSummarySave = (_accountSummarySave ?? Future<void>.value()).then(
      (_) => AccountSummaryCache.save(
        authData,
        user: user,
        traffic: traffic,
        aliveIp: aliveIp,
        deviceLimit: deviceLimit,
        resetDay: resetDay,
        expiredAt: expiredAt,
      ),
    );
  }

  void _startStatusRefresh() {
    if (_disposed || !_isAuthenticated) return;
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(
      _statusRefreshInterval,
      (_) => unawaited(_refreshAccountStatusSilently()),
    );
  }

  void _stopStatusRefresh() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
  }

  /// Background poll: NEVER surfaces an error, NEVER logs the user out.
  /// A transient 401 on a timer must not kick the user — real auth expiry is
  /// handled the next time the user performs an action through refreshData().
  Future<void> _refreshAccountStatusSilently() async {
    if (_disposed || !_isAuthenticated) return;
    if (_statusRefreshInFlight) return;
    if (connectionActionLocked) return;
    _statusRefreshInFlight = true;
    try {
      final snap = await _dataLoader.loadAccountStatus();
      if (_disposed || !_isAuthenticated) return;
      _applyAccountStatus(snap);
    } catch (_) {
      // intentional: silent on a background poll.
    } finally {
      _statusRefreshInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isAuthenticated) {
          _startStatusRefresh();
          unawaited(_refreshAccountStatusSilently());
          unawaited(_refreshNodesIfStale());
          unawaited(
            _desktopNetworkMonitor.checkNow(notifyEvenIfUnchanged: true),
          );
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _stopStatusRefresh();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _stopStatusRefresh();
    _desktopNetworkMonitor.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    AppConfig.revision.removeListener(_onRemoteConfigChanged);
    _settings.removeListener(notifyListeners);
    _core.removeListener(_onCoreChanged);
    _core.removeListener(notifyListeners);
    _notices.removeListener(notifyListeners);
    _subscription.removeListener(notifyListeners);
    _wallet.removeListener(notifyListeners);
    _invite.removeListener(notifyListeners);
    _account.removeListener(notifyListeners);
    _nodes.removeListener(notifyListeners);
    _settings.dispose();
    _core.dispose();
    _notices.dispose();
    _subscription.dispose();
    _wallet.dispose();
    _invite.dispose();
    _account.dispose();
    _nodes.dispose();
    super.dispose();
  }

  Future<void> _recoverDesktopConnection() async {
    if (_desktopRecoveryInFlight ||
        _disposed ||
        !_isAuthenticated ||
        !_settings.wasConnected ||
        connectionActionLocked ||
        _nodes.isEmpty ||
        (!Platform.isWindows && !Platform.isMacOS)) {
      return;
    }

    _desktopRecoveryInFlight = true;
    try {
      // Let the OS finish replacing routes and adapters after wake/network
      // changes before touching the proxy or restarting the tunnel.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (_disposed ||
          !_isAuthenticated ||
          !_settings.wasConnected ||
          connectionActionLocked) {
        return;
      }

      if (coreRunning) {
        if (_settings.networkMode == NetworkMode.system) {
          await fixProxy();
        }
        return;
      }

      await toggleConnection();
    } catch (error) {
      SecureLogger.warn('desktop connection recovery failed', error);
    } finally {
      _desktopRecoveryInFlight = false;
    }
  }

  void _onRemoteConfigChanged() {
    if (_disposed) return;
    // Rebuild even when only api_prefix changed and the host list stayed the
    // same; Dio stores the combined base URL when it is constructed.
    _apiClient.updateServerUrls(
      AppConfig.effectiveApiBases,
      forceRebuild: true,
    );
    if (!_isPageEnabled(_page)) {
      _page = AppPage.dashboard;
      _mobileProfileChildPage = false;
    }
    unawaited(refreshRegisterConfigCache());
    unawaited(_checkForUpdate());
    notifyListeners();
  }

  bool _isPageEnabled(AppPage page) => switch (page) {
    AppPage.shop => AppConfig.panelFeatures.shop,
    AppPage.invite => AppConfig.panelFeatures.invite,
    AppPage.wallet => AppConfig.panelFeatures.wallet,
    AppPage.orders => AppConfig.panelFeatures.orders,
    AppPage.traffic => AppConfig.panelFeatures.traffic,
    AppPage.tickets => AppConfig.panelFeatures.tickets,
    _ => true,
  };

  void _onCoreChanged() {
    final status = _core.connectionStatus;
    if (status == ConnectionStatus.connected) {
      _settings.setWasConnected(true);
      unawaited(_testLatenciesInBackground());
    } else if (status == ConnectionStatus.disconnected) {
      _settings.setWasConnected(false);
      if (!_core.coreProcessRunning) _nodes.markAllLatency(0);
    }
  }

  void goToPage(AppPage page) {
    if (!_isPageEnabled(page)) return;
    _mobileProfileChildPage = false;
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  void goToProfileChildPage(AppPage page) {
    if (!_isPageEnabled(page)) return;
    _mobileProfileChildPage = page != AppPage.account;
    if (_page == page) {
      notifyListeners();
      return;
    }
    _page = page;
    notifyListeners();
  }

  void goToAuthScreen(AuthScreen screen) {
    if (_authScreen == screen) return;
    _authScreen = screen;
    notifyListeners();
  }

  Future<void> loginWithCredentials(
    String email,
    String password, {
    Future<void> Function(String authData)? onAuthenticated,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await _api.login(email, password);
      await onAuthenticated?.call(result.authData);
      await _completeAuthentication(result.authData);
    } catch (e) {
      SecureLogger.warn(
        'Auth loginWithCredentials failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
      rethrow;
    }
  }

  Future<void> registerWithCredentials({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? inviteCode,
    String? emailCode,
  }) async {
    final result = await _api.register(
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      inviteCode: inviteCode,
      emailCode: emailCode,
    );
    await _completeAuthentication(result.authData);
  }

  Future<void> changePasswordApi({
    required String oldPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      passwordConfirmation: passwordConfirmation,
    );
  }

  Future<String?> updateUserSettings({
    required bool remindExpire,
    required bool remindTraffic,
    required bool autoRenewal,
  }) => _account.updateUserSettings(
    remindExpire: remindExpire,
    remindTraffic: remindTraffic,
    autoRenewal: autoRenewal,
  );

  Future<void> _completeAuthentication(String authData) async {
    await TokenStorage.saveAuthData(authData);
    _apiClient.updateAuthData(authData);
    _authData = authData;
    await Future.wait([
      _restoreCachedNodes(),
      _restoreCachedAccountSummary(authData),
    ]);
    _isAuthenticated = true;
    final sessionEpoch = ++_sessionEpoch;
    _startStatusRefresh();
    _dataLoadError = null;
    _isInitialLoading = true;
    _page = AppPage.dashboard;
    notifyListeners();
    unawaited(_refreshAfterAutoLogin(sessionEpoch));
  }

  Future<void> _expireSessionAndStopCore(String message) async {
    ++_sessionEpoch;
    _stopStatusRefresh();
    await _core.stopAndReset();
    await TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
    _authData = null;
    _hasAccountSummary = false;
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _startupMessage = message;
    _account.reset();
    _nodes.reset();
    _plans = const [];
    _invite.reset();
    _wallet.reset();
    _subscription.reset();
    _dataLoadError = null;
    _notices.reset();
    await NodeCacheService.clear();
    await _accountSummarySave;
    await AccountSummaryCache.clear();
    _isInitialLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> logout() async {
    if (_logoutInFlight) return;
    _logoutInFlight = true;
    ++_sessionEpoch;
    _stopStatusRefresh();
    try {
      await _core.stopAndReset();
      _isAuthenticated = false;
      _authScreen = AuthScreen.login;
      await TokenStorage.clearAuthData();
      _apiClient.updateAuthData(null);
      _authData = null;
      _hasAccountSummary = false;
      _account.reset();
      _nodes.reset();
      _plans = const [];
      _invite.reset();
      _wallet.reset();
      _subscription.reset();
      _dataLoadError = null;
      _notices.reset();
      await NodeCacheService.clear();
      await _accountSummarySave;
      await AccountSummaryCache.clear();
      notifyListeners();
    } finally {
      _logoutInFlight = false;
    }
  }

  CoreConnectionRequest _buildConnectionRequest() => CoreConnectionRequest(
    nodes: _nodes.nodes,
    currentNode: currentNode,
    proxyMode: _settings.proxyMode,
    dnsMode: _settings.dnsMode,
    proxyPort: _settings.proxyPort,
    networkMode: _settings.networkMode,
    allowInsecure: false,
    rules: _subscription.rules,
    ruleProviders: _subscription.ruleProviders,
  );

  Future<String?> toggleConnection() {
    if (!supportsCoreConnection) {
      return Future.value('当前平台暂未接入核心连接');
    }
    return _core.toggleConnection(_buildConnectionRequest());
  }

  static Future<bool> checkAdminPrivileges() async {
    return checkWindowsAdminPrivilege();
  }

  bool _isSessionCurrent(int sessionEpoch) =>
      !_disposed && _isAuthenticated && sessionEpoch == _sessionEpoch;

  Future<void> _loadAllData(int sessionEpoch) async {
    final snap = await _dataLoader.loadAccountStatus();
    if (!_isSessionCurrent(sessionEpoch)) return;
    _applyAccountStatus(snap);

    // Start detail-page requests at the same time, but do not let them hold
    // back nodes and plan data needed by the first dashboard frame.
    final secondaryLoad = _dataLoader.loadSecondary(snap);
    await _dataLoader.loadPrimary(snap);
    if (!_isSessionCurrent(sessionEpoch)) return;
    _applySnapshot(snap);
    _saveAccountSummary();
    if (_nodes.isNotEmpty) {
      _lastNodesRefreshAt = DateTime.now();
      unawaited(NodeCacheService.save(_nodes.nodes));
      _restoreLastNode();
      if (supportsCoreConnection) unawaited(_preloadCoreAndTestLatencies());
    }
    if (!_disposed) notifyListeners();

    await secondaryLoad;
    if (!_isSessionCurrent(sessionEpoch)) return;
    _applySnapshot(snap);
    final features = AppConfig.panelFeatures;
    if (features.shop || features.invite || features.wallet) {
      try {
        final symbol = await _api.getCommCurrencySymbol();
        if (!_isSessionCurrent(sessionEpoch)) return;
        _wallet.setCurrencySymbol(symbol);
      } catch (e) {
        SecureLogger.warn('AppController currency load failed', e);
      }
    }
    try {
      final notices = await _api.getNotices();
      if (!_isSessionCurrent(sessionEpoch)) return;
      _notices.setNotices(notices);
    } catch (e) {
      SecureLogger.warn('AppController notices load failed', e);
    }
  }

  void cacheAccountDetails(RemoteUser user) => _account.setRemoteUser(user);

  Future<void> refreshData() async {
    final sessionEpoch = _sessionEpoch;
    _dataLoadError = null;
    notifyListeners();
    try {
      await _loadAllData(sessionEpoch);
      if (!_isSessionCurrent(sessionEpoch)) return;
      _dataLoadError = null;
    } catch (e) {
      if (NetworkErrorClassifier.isNetworkError(e)) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
      } else {
        await _expireSessionAndStopCore('登录已过期，请重新登录');
        return;
      }
    }
    notifyListeners();
  }

  Future<String?> createInviteCode() => _invite.createInviteCode();
  Future<String?> transferAllCommission() => _wallet.transferAllCommission();
  Future<String?> transferCommissionToBalance(double amount) =>
      _wallet.transferCommissionToBalance(amount);

  Future<String?> withdrawCommission({
    required double amount,
    required String account,
    required String method,
  }) => _wallet.withdrawCommission(
    amount: amount,
    account: account,
    method: method,
  );

  Future<void> refreshNodes() async {
    if (_nodesRefreshInFlight || !_isAuthenticated) return;
    _nodesRefreshInFlight = true;
    final sessionEpoch = _sessionEpoch;
    try {
      final snap = await _dataLoader.loadNodes(_subscription.subscribeUrl);
      if (!_isSessionCurrent(sessionEpoch)) return;
      if (snap.nodes != null && snap.nodes!.isNotEmpty) {
        _invalidateLatencyRuns();
        _nodes.setNodes(snap.nodes!);
        _restoreLastNode();
        _account.setTraffic(snap.traffic);
        _lastNodesRefreshAt = DateTime.now();
        unawaited(NodeCacheService.save(_nodes.nodes));
        if (supportsCoreConnection) {
          await _reloadCoreConfig(startIfStopped: true);
        }
      }
      notifyListeners();
    } finally {
      _nodesRefreshInFlight = false;
    }
  }

  Future<void> _refreshNodesIfStale() async {
    final refreshedAt = _lastNodesRefreshAt;
    if (refreshedAt != null &&
        DateTime.now().difference(refreshedAt) < _nodesRefreshMaxAge) {
      return;
    }
    try {
      await refreshNodes();
    } catch (e) {
      SecureLogger.debug('stale node refresh failed', e);
    }
  }

  void _applySnapshot(DataSnapshot snap) {
    _account.applySnapshot(
      remoteUser: snap.remoteUser,
      user: snap.user,
      traffic: snap.traffic,
    );
    _subscription.applySnapshot(subscribeUrl: snap.subscribeUrl);
    if (snap.nodes != null) {
      _invalidateLatencyRuns();
      _nodes.setNodes(snap.nodes!);
    }
    if (snap.plans != null) _plans = snap.plans!;
    _invite.applySnapshot(
      codes: snap.inviteCodes,
      code: snap.inviteCode,
      link: snap.inviteLink,
      urlBase: snap.inviteUrlBase,
    );
    _wallet.applySnapshot(
      inviteRecords: snap.inviteRecords,
      commissionRate: snap.commissionRate,
      invitedCount: snap.invitedCount,
      earnedCommission: snap.earnedCommission,
      pendingCommission: snap.pendingCommission,
      withdrawable: snap.withdrawable,
      withdrawClose: snap.withdrawClose,
      withdrawMethods: snap.withdrawMethods,
      minWithdrawAmount: snap.minWithdrawAmount,
      currencySymbol: snap.currencySymbol,
    );
    _subscription.applySnapshot(
      dailyUsage: snap.dailyUsage,
      trafficUsage: snap.trafficUsage,
      aliveIp: snap.aliveIp,
      deviceLimit: snap.deviceLimit,
      resetDay: snap.resetDay,
      expiredAt: snap.expiredAt,
      rules: snap.rules,
      ruleProviders: snap.ruleProviders,
    );
    if (snap.criticalError != null) {
      _dataLoadError = snap.criticalError;
    } else if (snap.nodesError != null && _nodes.isEmpty) {
      _dataLoadError = snap.nodesError;
    }
  }

  void _restoreLastNode() => _nodes.restoreLastSelection(_settings.lastNodeId);

  Future<String?> setCurrentNode(NodeModel node) async {
    if (supportsCoreConnection && _core.coreProcessRunning) {
      final ok = await _core.switchNode(node);
      if (!ok) return '节点切换失败，核心未响应，请重试';
    }
    _nodes.selectNode(node);
    _settings.setLastNodeId(node.id);
    return null;
  }

  Future<String?> selectAuto() async {
    if (supportsCoreConnection && _core.coreProcessRunning) {
      final ok = await _core.switchToAuto();
      if (!ok) return '自动选择切换失败，核心未响应，请重试';
    }
    _nodes.selectAuto();
    _settings.setLastNodeId('');
    return null;
  }

  Future<void> _preloadCoreAndTestLatencies() async {
    if (!supportsCoreConnection || _nodes.isEmpty) return;
    final ready = await _preloadCoreOnly();
    if (!ready) return;
    await _testLatenciesInBackground();
  }

  Future<void> _reloadCoreConfig({bool startIfStopped = false}) async {
    if (!supportsCoreConnection) return;
    if (_nodes.isEmpty) return;
    if (!startIfStopped && !coreProcessRunning) return;

    final error = await _core.reloadCore(_buildConnectionRequest());
    if (error != null && error.isNotEmpty) {
      _startupMessage = error;
      notifyListeners();
      return;
    }

    if (coreProcessRunning) {
      await Future.delayed(const Duration(milliseconds: 1000));
      unawaited(_testLatenciesInBackground());
    }
  }

  Future<bool> testLatencies() async {
    if (!supportsCoreConnection || _nodes.isEmpty) return false;

    final runId = _nextLatencyRunId();
    _nodes.markAllLatency(-1);
    final snapshot = List<NodeModel>.from(_nodes.nodes);

    if (!coreProcessRunning) {
      final ready = await _preloadCoreOnly();
      if (!ready) {
        _markLatencyTestFailed(runId, snapshot);
        return false;
      }
    }

    await _core.testLatencies(
      snapshot,
      onResult: (idx, updated) {
        if (_isCurrentLatencyRun(runId)) _nodes.applyLatencyAt(idx, updated);
      },
    );
    return _isCurrentLatencyRun(runId) &&
        _nodes.nodes.any((node) => node.latency > 0 && node.latency < 9999);
  }

  Future<void> _testLatenciesInBackground() async {
    if (!supportsCoreConnection || _nodes.isEmpty || !coreProcessRunning) {
      return;
    }

    final runId = _nextLatencyRunId();
    final snapshot = List<NodeModel>.from(_nodes.nodes);

    await _core.testLatencies(
      snapshot,
      onResult: (idx, updated) {
        if (_isCurrentLatencyRun(runId)) _nodes.applyLatencyAt(idx, updated);
      },
    );
  }

  Future<bool> _preloadCoreOnly() async {
    if (coreProcessRunning) return true;
    await _core.startCoreOnly(_buildConnectionRequest());
    return coreProcessRunning;
  }

  void _markLatencyTestFailed(int runId, List<NodeModel> snapshot) {
    if (!_isCurrentLatencyRun(runId)) return;
    _nodes.applyLatencyById({for (final node in snapshot) node.id: 9999});
  }

  int _nextLatencyRunId() => ++_latencyRunId;

  void _invalidateLatencyRuns() {
    _latencyRunId++;
    _nodes.markAllLatency(0);
  }

  bool _isCurrentLatencyRun(int id) => !_disposed && id == _latencyRunId;
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  AppController get controller => notifier!;

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.controller;
  }

  static AppController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'No AppScope found in context');
    return scope!.controller;
  }
}
