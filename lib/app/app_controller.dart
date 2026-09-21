import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_locale_preference.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/services/account_summary_cache.dart';
import '../shared/services/api_client.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/desktop_network_monitor.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/notice_cache_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/register_config_cache.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/session_failure_policy.dart';
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
  orders,
  tickets,
  giftCard,
  more,
}

bool isPageEnabled(AppPage page) => switch (page) {
  AppPage.shop => AppConfig.panelFeatures.shop,
  AppPage.invite => AppConfig.panelFeatures.invite,
  AppPage.orders => AppConfig.panelFeatures.orders,
  AppPage.traffic => AppConfig.panelFeatures.traffic,
  AppPage.tickets => AppConfig.panelFeatures.tickets,
  AppPage.giftCard => AppConfig.panelFeatures.giftCard,
  _ => true,
};

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

  /// TODO(v3-review): temporary visual-review bypass — remove before release.
  /// Debug builds skip the auth screen entirely so the workspace can be
  /// reviewed without signing in; session expiry and logout are also muted
  /// because the getter below stays true. Release builds are untouched.
  /// Logout-semantics tests flip this off to exercise the real path.
  static bool debugBypassLogin = kDebugMode && !kIsWeb;

  AppPage _page = AppPage.dashboard;
  AuthScreen _authScreen = AuthScreen.login;

  List<PlanModel> _plans = const [];
  int? _currentPlanId;
  String? _dataLoadError;
  String? _startupMessage;
  UpdateInfo? _updateInfo;
  RegisterConfig _registerConfig = const RegisterConfig();
  List<TicketModel> _tickets = const [];
  bool _ticketsLoaded = false;
  bool _ticketsLoading = false;
  String? _ticketsError;
  bool _disposed = false;
  bool _isInitialLoading = false;
  bool _logoutInFlight = false;
  int _latencyRunId = 0;
  bool _latencyTestInFlight = false;
  bool get isLatencyTesting => _latencyTestInFlight;
  String? _authData;
  Future<void>? _accountSummarySave;
  bool _hasAccountSummary = false;
  // Only two successful negative API responses can confirm no plan.
  bool _confirmedNoPlan = false;
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
  DnsMode get dnsMode => _settings.dnsMode;
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

  Future<String?> setKillSwitch(bool v) async {
    _settings.setKillSwitch(v);
    return _applyKillSwitchSetting(v);
  }

  Future<String?> _applyKillSwitchSetting(bool enabled) async {
    final applied = await _core.setKillSwitchEnabled(enabled);
    if (!applied && enabled) {
      _settings.setKillSwitch(false);
      _startupMessage = CoreErrorMessageService.tunKillSwitchUnavailable;
      notifyListeners();
      return CoreErrorMessageService.tunKillSwitchUnavailable;
    }
    return null;
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

  Future<String?> setNetworkMode(NetworkMode v) async {
    final old = _settings.networkMode;
    _settings.setNetworkMode(v);
    if (_settings.networkMode != v) return '当前平台不支持此网络模式';
    if (_settings.networkMode != old) return _reloadCoreConfig();
    return null;
  }

  Future<String?> setDnsMode(DnsMode v) async {
    final old = _settings.dnsMode;
    _settings.setDnsMode(v);
    if (_settings.dnsMode != old) return _reloadCoreConfig();
    return null;
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

  // The debug bypass short-circuits the auth screen; every other consumer
  // (status refresh, session checks) keeps working off the real flag, so the
  // only visible difference is that a session-less run stays in the app.
  bool get isAuthenticated => _isAuthenticated || debugBypassLogin;
  bool get isInitializing => _isInitializing;
  AppPage get page => _page;
  AuthScreen get authScreen => _authScreen;

  UserModel get user => _account.user;
  RemoteUser? get accountDetails => _account.remoteUser;
  TrafficModel get traffic => _account.traffic;
  bool get autoSelected => _nodes.autoSelected;
  NodeModel get currentNode => _nodes.currentNode;
  List<NodeModel> get nodes => _nodes.nodes;
  List<PlanModel> get plans => _plans;
  int? get currentPlanId => _currentPlanId;
  bool get hasPlan =>
      _currentPlanId != null ||
      _account.user.plan.trim().isNotEmpty ||
      _subscription.subscribeUrl.trim().isNotEmpty ||
      // Live quota is plan evidence too — the same signal DataLoader counts
      // via `transferEnable > 0`. Without it the rail can say 暂无套餐 while
      // the traffic page above it shows a full quota.
      _account.traffic.totalGb > 0;

  String get planExpiryLabel {
    final value = user.expiry.trim();
    if (value.isNotEmpty) return value;
    return hasPlan ? '未提供' : '暂无套餐';
  }

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
  bool get hasConfirmedNoPlan => _confirmedNoPlan && !hasPlan;
  String get currencySymbol => _wallet.currencySymbol;
  String? get startupMessage => _startupMessage;
  void clearStartupMessage() => _startupMessage = null;
  PanelApi get api => _api;
  UpdateInfo? get updateInfo => _updateInfo;
  RegisterConfig get registerConfig => _registerConfig;
  List<TicketModel> get tickets => _tickets;
  bool get ticketsLoaded => _ticketsLoaded;
  bool get ticketsLoading => _ticketsLoading;
  String? get ticketsError => _ticketsError;
  List<NoticeModel> get notices => _notices.notices;
  bool get noticesLoading => _notices.isLoading;
  bool get hasUnreadNotice => _notices.hasUnreadNotice;
  List<NoticeModel> get pendingNoticePopups => _notices.pendingPopups;

  void dismissUpdate() {
    _updateInfo = null;
    notifyListeners();
  }

  void markNoticeRead() => _notices.markRead();
  void markNoticePopupSeen(int id) => _notices.markPopupSeen(id);

  Future<void> init() async {
    await _settings.load();
    await _notices.loadLastSeen();
    await _notices.loadCached();
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
    _confirmedNoPlan = false;
    await Future.wait([
      _restoreCachedNodes(authData),
      _restoreCachedAccountSummary(authData),
    ]);
    _isAuthenticated = true;
    final sessionEpoch = ++_sessionEpoch;
    _startStatusRefresh();
    _isInitialLoading = true;
    _isInitializing = false;
    notifyListeners();
    unawaited(_refreshAfterAutoLogin(sessionEpoch));
    unawaited(_checkForUpdate());
  }

  Future<void> _loadCachedRegisterConfig() async {
    final cached = await RegisterConfigCache.load(AppConfig.apiBase);
    if (cached == null) return;
    _registerConfig = cached;
  }

  Future<void> _restoreCachedNodes(String authData) async {
    final cached = await NodeCacheService.load(authData);
    if (cached.isEmpty) return;
    _invalidateLatencyRuns();
    _nodes.setNodes(cached);
    _restoreLastNode();
    if (supportsCoreConnection) unawaited(_preloadCoreOnly());
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
    } catch (_) {
      // Best-effort; expected when the server is not yet reachable.
    }
  }

  Future<void> _refreshAfterAutoLogin(int sessionEpoch) async {
    final sw = Stopwatch()..start();
    try {
      _dataLoadError = null;
      await _loadAllData(sessionEpoch);
      if (!_isSessionCurrent(sessionEpoch)) return;
      // Keep any partial-load errors recorded by the snapshot.
      _isInitialLoading = false;
      notifyListeners();
      if (_settings.wasConnected) {
        unawaited(_tryAutoReconnectSafely(sessionEpoch));
      }
    } catch (e) {
      if (!_isSessionCurrent(sessionEpoch)) return;
      SecureLogger.warn(
        'Auth background refresh failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
      final kind = SessionFailurePolicy.classify(e);
      if (kind == SessionFailureKind.authentication) {
        await _expireSessionAndStopCore('登录已过期，请重新登录');
        return;
      }
      _isInitialLoading = false;
      if (kind == SessionFailureKind.network) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
        notifyListeners();
        if (_settings.wasConnected && _nodes.isNotEmpty) {
          unawaited(toggleConnection().then((_) {}));
        }
      } else {
        _dataLoadError = SessionFailurePolicy.syncError(e);
        notifyListeners();
      }
    }
  }

  /// Never reconnect a known expired, suspended or traffic-exhausted account.
  /// Unrelated API failures do not expire the session or permit reconnection.
  Future<void> _tryAutoReconnectSafely(int sessionEpoch) async {
    if (!_isSessionCurrent(sessionEpoch) || _nodes.isEmpty) return;
    try {
      final info = await _api.getUserInfo(silent: true);
      if (!_isSessionCurrent(sessionEpoch)) return;
      final subscribe = await _api.getSubscribeInfo(silent: true);
      if (!_isSessionCurrent(sessionEpoch)) return;
      final planConfirmed =
          info.hasPlanEvidence ||
          (subscribe.planId != null && subscribe.planId! > 0) ||
          subscribe.subscribeUrl.trim().isNotEmpty ||
          subscribe.transferEnable > 0;
      final expiredAt = subscribe.expiredAt ?? info.expiredAt;
      final expired =
          expiredAt != null &&
          expiredAt > 0 &&
          expiredAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final quotaExhausted = subscribe.transferEnable > 0
          ? subscribe.upload + subscribe.download >= subscribe.transferEnable
          : info.transferEnable > 0 && info.used >= info.transferEnable;
      if (!planConfirmed ||
          info.subscribeStatus != 0 ||
          expired ||
          quotaExhausted) {
        _settings.setWasConnected(false);
        _dataLoadError = '套餐不可用或状态未确认，已停止自动连接，请检查账户状态';
        notifyListeners();
        return;
      }
      await toggleConnection();
    } catch (e) {
      if (!_isSessionCurrent(sessionEpoch)) return;
      final kind = SessionFailurePolicy.classify(e);
      if (kind == SessionFailureKind.authentication) {
        await _expireSessionAndStopCore('登录已过期，请重新登录');
        return;
      }
      if (kind == SessionFailureKind.network && _nodes.isNotEmpty) {
        // Preserve the established offline-cache behavior for genuine outages.
        await toggleConnection();
        return;
      }
      _dataLoadError = SessionFailurePolicy.syncError(e);
      notifyListeners();
    }
  }

  Future<void> _checkForUpdate() async {
    if (!_settings.autoUpdate) return;
    final info = await UpdateService.check();
    if (info != null && !_disposed) {
      _updateInfo = info;
      notifyListeners();
    }
  }

  void _applyAccountStatus(DataSnapshot snap) {
    if (snap.user != null || snap.subscribeUrl != null) {
      _hasAccountSummary = true;
    }
    // Failure or incomplete data is unknown, never a confirmed no-plan.
    _confirmedNoPlan = snap.hasPlan == false;
    final confirmedNoPlan = _confirmedNoPlan;
    if (confirmedNoPlan) {
      final hadSubscriptionState =
          hasPlan || _nodes.isNotEmpty || _core.coreProcessRunning;
      _currentPlanId = null;
      _subscription.reset();
      if (_nodes.isNotEmpty) {
        _invalidateLatencyRuns();
        _nodes.setNodes(const []);
      }
      _settings.setWasConnected(false);
      if (hadSubscriptionState) unawaited(_core.stopAndReset());
    } else if (snap.currentPlanId != null) {
      _currentPlanId = snap.currentPlanId;
    }
    if (snap.user != null) {
      final fresh = snap.user!;
      final previous = _account.user;
      final merged = confirmedNoPlan
          ? fresh.copyWith(plan: '', expiry: '')
          : fresh.copyWith(
              plan: fresh.plan.trim().isEmpty && previous.plan.trim().isNotEmpty
                  ? previous.plan
                  : fresh.plan,
              expiry:
                  fresh.expiry.trim().isEmpty &&
                      previous.expiry.trim().isNotEmpty
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

  Future<void> _refreshAccountStatusSilently() async {
    if (_disposed || !_isAuthenticated) return;
    if (_statusRefreshInFlight) return;
    if (connectionActionLocked) return;
    final sessionEpoch = _sessionEpoch;
    final authData = _authData;
    _statusRefreshInFlight = true;
    try {
      final snap = await _dataLoader.loadAccountStatus(silent: true);
      if (!_isSessionCurrent(sessionEpoch) || authData != _authData) return;
      _applyAccountStatus(snap);
    } catch (_) {
      // Background polling never logs out or interrupts a connection.
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
          unawaited(_desktopNetworkMonitor.checkNow());
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
        } else if (Platform.isWindows &&
            _settings.networkMode == NetworkMode.tun) {
          await _core.refreshWindowsTunDns(_buildConnectionRequest());
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
    _apiClient.updateServerUrls(
      AppConfig.effectiveApiBases,
      forceRebuild: true,
    );
    if (!isPageEnabled(_page)) _page = AppPage.dashboard;
    unawaited(refreshRegisterConfigCache());
    unawaited(_checkForUpdate());
    notifyListeners();
  }

  void _onCoreChanged() {
    final status = _core.connectionStatus;
    if (status == ConnectionStatus.connected) {
      _settings.setWasConnected(true);
      if (!autoSelected && currentNode.latency == 0) {
        unawaited(testNodeLatency(currentNode));
      }
    } else if (status == ConnectionStatus.disconnected) {
      _settings.setWasConnected(false);
      if (!_core.coreProcessRunning) _nodes.markAllLatency(0);
    }
  }

  void goToPage(AppPage page) {
    if (!isPageEnabled(page) || _page == page) return;
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
    _confirmedNoPlan = false;
    await Future.wait([
      _restoreCachedNodes(authData),
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
    _confirmedNoPlan = false;
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _startupMessage = message;
    _account.reset();
    _nodes.reset();
    _plans = const [];
    _currentPlanId = null;
    _invite.reset();
    _wallet.reset();
    _subscription.reset();
    _dataLoadError = null;
    _notices.reset();
    _tickets = const [];
    _ticketsLoaded = false;
    _ticketsLoading = false;
    _ticketsError = null;
    await NodeCacheService.clear();
    await NoticeCacheService.clear();
    await _accountSummarySave;
    await AccountSummaryCache.clear();
    _isInitialLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> logout() async {
    // The visual-review bypass keeps the workspace mounted no matter what;
    // clearing session state here would just wipe the data under review.
    if (debugBypassLogin) return;
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
    _confirmedNoPlan = false;
      _account.reset();
      _nodes.reset();
      _plans = const [];
      _currentPlanId = null;
      _invite.reset();
      _wallet.reset();
      _subscription.reset();
      _dataLoadError = null;
      _notices.reset();
      _tickets = const [];
      _ticketsLoaded = false;
      _ticketsLoading = false;
      _ticketsError = null;
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
  );

  Future<String?> toggleConnection() {
    if (!supportsCoreConnection) {
      return Future.value('当前平台暂未接入核心连接');
    }
    return _core.toggleConnection(_buildConnectionRequest());
  }

  static Future<bool> checkAdminPrivileges() async =>
      checkWindowsAdminPrivilege();

  bool _isSessionCurrent(int sessionEpoch) =>
      !_disposed && _isAuthenticated && sessionEpoch == _sessionEpoch;

  Future<void> _loadAllData(int sessionEpoch) async {
    final snap = await _dataLoader.loadAccountStatus();
    if (!_isSessionCurrent(sessionEpoch)) return;
    _applyAccountStatus(snap);

    final secondaryLoad = _dataLoader.loadSecondary(snap);
    await _dataLoader.loadPrimary(snap);
    if (!_isSessionCurrent(sessionEpoch)) return;
    _applySnapshot(snap);
    _saveAccountSummary();
    if (_nodes.isNotEmpty) {
      _lastNodesRefreshAt = DateTime.now();
      unawaited(NodeCacheService.save(_nodes.nodes, _authData!));
      _restoreLastNode();
      if (supportsCoreConnection) unawaited(_preloadCoreOnly());
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
        if (e is! ApiNotConfiguredException) {
          SecureLogger.warn('AppController currency load failed', e);
        }
      }
    }
    try {
      if (_notices.notices.isEmpty) _notices.setLoading(true);
      final notices = await _api.getNotices();
      if (!_isSessionCurrent(sessionEpoch)) return;
      _notices.setNotices(notices);
      unawaited(_notices.saveCache());
    } catch (e) {
      if (e is! ApiNotConfiguredException) {
        SecureLogger.warn('AppController notices load failed', e);
      }
      _notices.setLoading(false);
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
      // Do not erase a genuine partial-load warning from _applySnapshot.
    } catch (e) {
      if (!_isSessionCurrent(sessionEpoch)) return;
      // No API base configured is a setup stage, not a failure: pages keep
      // their neutral empty states instead of an endless retry banner.
      if (e is ApiNotConfiguredException) return;
      final kind = SessionFailurePolicy.classify(e);
      if (kind == SessionFailureKind.authentication) {
        await _expireSessionAndStopCore('登录已过期，请重新登录');
        return;
      }
      if (kind == SessionFailureKind.network) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
      } else {
        _dataLoadError = SessionFailurePolicy.syncError(e);
      }
    }
    notifyListeners();
  }

  Future<void> refreshTickets() async {
    if (_ticketsLoading || !_isAuthenticated) return;
    final sessionEpoch = _sessionEpoch;
    _ticketsLoading = true;
    _ticketsError = null;
    if (!_disposed) notifyListeners();
    try {
      final tickets = await api.getTickets();
      if (!_isSessionCurrent(sessionEpoch)) return;
      _tickets = tickets;
      _ticketsLoaded = true;
    } catch (error) {
      if (!_isSessionCurrent(sessionEpoch)) return;
      if (error is ApiNotConfiguredException) {
        _tickets = const [];
        _ticketsLoaded = true;
      } else {
        _ticketsError = error
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      }
    } finally {
      if (_isSessionCurrent(sessionEpoch)) {
        _ticketsLoading = false;
        notifyListeners();
      }
    }
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
      if (snap.nodesError != null) {
        // Keep cached nodes and the live core, but make failure visible.
        _dataLoadError = snap.nodesError;
      } else if (snap.nodes != null && snap.nodes!.isNotEmpty) {
        _dataLoadError = null;
        _invalidateLatencyRuns();
        _nodes.setNodes(snap.nodes!);
        _restoreLastNode();
        _account.setTraffic(snap.traffic);
        _lastNodesRefreshAt = DateTime.now();
        unawaited(NodeCacheService.save(_nodes.nodes, _authData!));
        if (supportsCoreConnection) {
          await _reloadCoreConfig(startIfStopped: true);
        }
      }
      notifyListeners();
    } catch (e) {
      if (_isSessionCurrent(sessionEpoch)) {
        if (e is ApiNotConfiguredException) {
          // Setup stage: keep cached nodes without an error banner or log.
          notifyListeners();
          return;
        }
        _dataLoadError = '节点刷新失败，已保留现有节点，请稍后重试';
        notifyListeners();
      }
      SecureLogger.warn('AppController refreshNodes failed', e);
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
    if (snap.hasPlan == false) {
      _currentPlanId = null;
    } else if (snap.currentPlanId != null) {
      _currentPlanId = snap.currentPlanId;
    }
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
    );
    if (snap.criticalError != null) {
      _dataLoadError = snap.criticalError;
    } else if (snap.nodesError != null) {
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
    if (node.latency == 0) unawaited(testNodeLatency(node));
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

  /// Probe only a newly selected, untested node. Never clear other results.
  Future<void> testNodeLatency(NodeModel node) async {
    if (!supportsCoreConnection || _latencyTestInFlight || node.latency != 0) {
      return;
    }
    final runId = _latencyRunId;
    final candidates = _nodes.nodes
        .where(
          (item) =>
              item.id == node.id &&
              item.server == node.server &&
              item.port == node.port &&
              item.name == node.name,
        )
        .toList();
    if (candidates.length != 1) return;
    _nodes.markNodeLatency(node.id, -1);
    try {
      if (!coreProcessRunning && !await _preloadCoreOnly()) {
        if (_isCurrentLatencyRun(runId)) _nodes.markNodeLatency(node.id, 9999);
        return;
      }
      await _core.testLatencies(
        [node],
        onResult: (index, updated) {
          if (!_isCurrentLatencyRun(runId)) return;
          final current = _nodes.nodes
              .where((item) => item.id == node.id)
              .toList();
          if (current.length != 1 ||
              current.single.server != node.server ||
              current.single.port != node.port ||
              current.single.name != node.name) {
            return;
          }
          _nodes.markNodeLatency(node.id, updated.latency);
        },
      );
    } catch (_) {
      if (_isCurrentLatencyRun(runId)) _nodes.markNodeLatency(node.id, 9999);
    }
  }

  Future<String?> _reloadCoreConfig({bool startIfStopped = false}) async {
    if (!supportsCoreConnection) return null;
    if (_nodes.isEmpty) return null;
    if (!startIfStopped && !coreProcessRunning) return null;
    final error = await _core.reloadCore(_buildConnectionRequest());
    if (error != null && error.isNotEmpty) {
      _startupMessage = error;
      notifyListeners();
      return error;
    }
    // Reloading connection configuration does not initiate a full test.
    return null;
  }

  /// Explicit button action: bounded batches with progressive per-node UI.
  Future<bool> testLatencies() async {
    if (!supportsCoreConnection || _nodes.isEmpty || _latencyTestInFlight) {
      return false;
    }
    _latencyTestInFlight = true;
    notifyListeners();
    final runId = _nextLatencyRunId();
    final snapshot = List<NodeModel>.from(_nodes.nodes);
    _nodes.markAllLatency(-1);
    try {
      if (!coreProcessRunning && !await _preloadCoreOnly()) {
        _markLatencyTestFailed(runId, snapshot);
        return false;
      }
      await _core.testLatencies(
        snapshot,
        onResult: (idx, updated) {
          if (_isCurrentLatencyRun(runId)) _nodes.applyLatencyAt(idx, updated);
        },
      );
      return _isCurrentLatencyRun(runId) &&
          _nodes.nodes.any((node) => node.latency > 0 && node.latency < 9999);
    } catch (_) {
      _markLatencyTestFailed(runId, snapshot);
      return false;
    } finally {
      _latencyTestInFlight = false;
      if (!_disposed) notifyListeners();
    }
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
    // New snapshots are merged against unchanged endpoints by NodeController.
    // Do not blank an already displayed result just because labels refreshed.
    _latencyRunId++;
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
