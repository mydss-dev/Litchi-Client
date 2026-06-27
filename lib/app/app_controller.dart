import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/network_error_classifier.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/register_config_cache.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/tcp_ping_service.dart';
import '../shared/services/token_storage.dart';
import '../shared/services/update_service.dart';
import 'account_controller.dart';
import 'core_connection_request.dart';
import 'core_controller.dart';
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

class AppController extends ChangeNotifier {
  AppController() {
    _settings.addListener(notifyListeners);
    _core.addListener(_onCoreChanged);
    _core.addListener(notifyListeners);
    _notices.addListener(notifyListeners);
    _subscription.addListener(notifyListeners);
    _wallet.addListener(notifyListeners);
    _invite.addListener(notifyListeners);
    _account.addListener(notifyListeners);
    _nodes.addListener(notifyListeners);
  }

  final SettingsController _settings = SettingsController();
  final CoreController _core = CoreController();
  final NodeController _nodes = NodeController();
  final NoticesController _notices = NoticesController();
  final SubscriptionController _subscription = SubscriptionController();
  late final WalletController _wallet = WalletController(_api, refreshData);
  late final InviteController _invite = InviteController(_api, refreshData);
  late final AccountController _account = AccountController(_api);

  final ApiClient _apiClient = ApiClient();
  late final PanelApi _api = PanelApi(_apiClient);
  late final DataLoader _dataLoader = DataLoader(_api);

  bool _isAuthenticated = false;
  bool _isInitializing = false;
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

  ThemeMode get themeMode => _settings.themeMode;
  bool get isDark => _settings.isDark;
  bool get autoStart => _settings.autoStart;
  bool get autoUpdate => _settings.autoUpdate;
  bool get devMode => _settings.devMode;
  String get language => _settings.language;
  ProxyMode get proxyMode => _settings.proxyMode;
  NetworkMode get networkMode => _settings.networkMode;
  String get dnsMode => _settings.dnsMode;
  int get proxyPort => _settings.proxyPort;
  bool get killSwitch => _settings.killSwitch;
  bool get allowInsecureNodes => _settings.allowInsecureNodes;

  void setThemeMode(ThemeMode mode) => _settings.setThemeMode(mode);
  void toggleDarkMode(bool enabled) => _settings.toggleDarkMode(enabled);
  void setAutoStart(bool v) => _settings.setAutoStart(v);
  void setAutoUpdate(bool v) => _settings.setAutoUpdate(v);
  void setDevMode(bool v) => _settings.setDevMode(v);
  void setLanguage(String v) => _settings.setLanguage(v);

  Future<void> setProxyPort(int port) async {
    final old = _settings.proxyPort;
    await _settings.setProxyPort(port);
    if (_settings.proxyPort != old) unawaited(_reloadCoreConfig());
  }

  void setKillSwitch(bool v) {
    _settings.setKillSwitch(v);
    _core.killSwitchEnabled = _settings.killSwitch;
  }

  void setAllowInsecureNodes(bool v) {
    final old = _settings.allowInsecureNodes;
    _settings.setAllowInsecureNodes(v);
    if (_settings.allowInsecureNodes != old) unawaited(_reloadCoreConfig());
  }

  void setProxyMode(ProxyMode v) {
    final old = _settings.proxyMode;
    _settings.setProxyMode(v);
    if (_settings.proxyMode == old) return;
    if (_core.coreProcessRunning) unawaited(_core.setMode(v));
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
      _core.fixProxy(_settings.proxyPort, networkMode: _settings.networkMode);
  Future<String?> exportLogs() => _core.exportLogs();
  static Future<String> getCoreVersion() => CoreController.getCoreVersion();

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  AppPage get page => _page;
  AuthScreen get authScreen => _authScreen;
  bool get mobileProfileChildPage => _mobileProfileChildPage;

  UserModel get user => _account.user;
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
    _core.killSwitchEnabled = _settings.killSwitch;

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
    await _restoreCachedNodes();

    _isAuthenticated = true;
    _isInitialLoading = true;
    _isInitializing = false;
    notifyListeners();

    if (supportsCoreConnection && _settings.wasConnected) {
      unawaited(toggleConnection().then((_) {}));
    }

    unawaited(_refreshAfterAutoLogin());
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
    if (supportsCoreConnection) unawaited(_testStartupLatencies());
  }

  Future<void> refreshRegisterConfigCache() async {
    try {
      final config = await _api.fetchRegisterConfig();
      await RegisterConfigCache.save(AppConfig.apiBase, config);
      _registerConfig = config;
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAfterAutoLogin() async {
    final sw = Stopwatch()..start();
    try {
      await _loadAllData();
      _dataLoadError = null;
      _isInitialLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      SecureLogger.warn(
        'Auth background refresh failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
      if (NetworkErrorClassifier.isNetworkError(e)) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
        if (!_disposed) notifyListeners();
        return;
      }

      await _expireSessionAndStopCore('登录已过期，请重新登录');
    }
  }

  Future<void> _checkForUpdate() async {
    final info = UpdateService.check();
    if (info != null && !_disposed) {
      _updateInfo = info;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
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
    _mobileProfileChildPage = false;
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  void goToProfileChildPage(AppPage page) {
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
    await _restoreCachedNodes();
    _isAuthenticated = true;
    _dataLoadError = null;
    _isInitialLoading = true;
    _page = AppPage.dashboard;
    notifyListeners();
    unawaited(_refreshAfterAutoLogin());
  }

  Future<void> _expireSessionAndStopCore(String message) async {
    await _core.stopAndReset();
    await TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
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
    _isInitialLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> logout() async {
    if (_logoutInFlight) return;
    _logoutInFlight = true;
    try {
      await _core.stopAndReset();
      _isAuthenticated = false;
      _authScreen = AuthScreen.login;
      await TokenStorage.clearAuthData();
      _apiClient.updateAuthData(null);
      _account.reset();
      _nodes.reset();
      _plans = const [];
      _invite.reset();
      _wallet.reset();
      _subscription.reset();
      _dataLoadError = null;
      _notices.reset();
      await NodeCacheService.clear();
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
    allowInsecure: _settings.allowInsecureNodes,
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
    if (!Platform.isWindows) return true;
    try {
      final result = await Process.run('powershell', [
        '-NonInteractive',
        '-NoProfile',
        '-Command',
        '([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
      ]).timeout(const Duration(seconds: 8));
      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadAllData() async {
    final snap = await _dataLoader.loadAll();
    _applySnapshot(snap);
    try {
      _wallet.setCurrencySymbol(await _api.getCommCurrencySymbol());
    } catch (e) {
      SecureLogger.warn('AppController currency load failed', e);
    }
    try {
      _notices.setNotices(await _api.getNotices());
    } catch (e) {
      SecureLogger.warn('AppController notices load failed', e);
    }
    if (_nodes.isNotEmpty) {
      unawaited(NodeCacheService.save(_nodes.nodes));
      _restoreLastNode();
      if (supportsCoreConnection) unawaited(_testStartupLatencies());
    }
  }

  Future<void> refreshData() async {
    _dataLoadError = null;
    notifyListeners();
    try {
      await _loadAllData();
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
    final snap = await _dataLoader.loadNodes(_subscription.subscribeUrl);
    if (snap.nodes != null && snap.nodes!.isNotEmpty) {
      _invalidateLatencyRuns();
      _nodes.setNodes(snap.nodes!);
      _restoreLastNode();
      _account.setTraffic(snap.traffic);
      unawaited(NodeCacheService.save(_nodes.nodes));
      if (supportsCoreConnection) await _reloadCoreConfig(startIfStopped: true);
    }
    notifyListeners();
  }

  void _applySnapshot(DataSnapshot snap) {
    _account.applySnapshot(user: snap.user, traffic: snap.traffic);
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

  Future<void> _testStartupLatencies() async {
    if (!supportsCoreConnection) return;
    if (Platform.isAndroid) {
      await testLatencies();
      return;
    }
    await _testTcpLatencies(showProgress: false);
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
      if (Platform.isAndroid) {
        unawaited(testLatencies());
      } else {
        unawaited(_testLatenciesInBackground());
      }
    }
  }

  Future<void> testLatencies() async {
    if (!supportsCoreConnection || _nodes.isEmpty) return;
    if (!coreProcessRunning) {
      await _testTcpLatencies(showProgress: true);
      return;
    }

    final runId = _nextLatencyRunId();
    _nodes.markAllLatency(-1);
    final snapshot = List<NodeModel>.from(_nodes.nodes);
    await _core.testLatencies(
      snapshot,
      onResult: (idx, updated) {
        if (_isCurrentLatencyRun(runId)) _nodes.applyLatencyAt(idx, updated);
      },
    );
  }

  Future<void> _testLatenciesInBackground() async {
    if (!supportsCoreConnection || _nodes.isEmpty) return;
    if (!coreProcessRunning) {
      await _testTcpLatencies(showProgress: false);
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

  Future<void> _testTcpLatencies({required bool showProgress}) async {
    final runId = _nextLatencyRunId();
    if (showProgress) _nodes.markAllLatency(-1);

    final snapshot = List<NodeModel>.from(_nodes.nodes);
    const concurrency = 8;
    for (var i = 0; i < snapshot.length; i += concurrency) {
      if (_disposed) return;
      final batch = snapshot.skip(i).take(concurrency).toList();
      final results = await Future.wait(
        batch.map((node) async {
          final ms = await TcpPingService.ping(node.server, node.port);
          return (id: node.id, latency: ms ?? 9999);
        }),
      );
      if (_disposed) return;
      if (_isCurrentLatencyRun(runId)) {
        _nodes.applyLatencyById({for (final r in results) r.id: r.latency});
      }
    }
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
