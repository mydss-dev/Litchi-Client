import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../shared/config/app_config.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/models/node_runtime_state.dart';
import '../shared/services/api_client.dart';
import '../shared/services/auth_session_service.dart';
import '../shared/services/data_load_error_service.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/network_error_classifier.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/node_selection_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/register_config_cache.dart';
import '../shared/services/update_service.dart';
import 'core_connection_request.dart';
import 'core_controller.dart';
import 'core_platform_support.dart';
import 'core_state_sync_service.dart';
import 'account_controller.dart';
import 'invite_controller.dart';
import 'notices_controller.dart';
import 'settings_controller.dart';
import 'subscription_controller.dart';
import 'wallet_controller.dart';

/// Top-level navigation destinations shown in the sidebar.
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

/// Which authentication screen is visible while logged out.
enum AuthScreen { login, register, changePassword, forgotPassword }

/// Coordinator: owns navigation, auth, and subscription data.
/// Settings and core-process concerns are delegated to [SettingsController]
/// and [CoreController] respectively. All public getters/setters are preserved
/// so [AppScope] callers require no changes.
class AppController extends ChangeNotifier {
  AppController() {
    _settings.addListener(notifyListeners);
    _core.addListener(_onCoreChanged);
    _core.addListener(notifyListeners);
    _wallet.addListener(notifyListeners);
    _invite.addListener(notifyListeners);
    _notices.addListener(notifyListeners);
    _account.addListener(notifyListeners);
    _subscription.addListener(notifyListeners);
  }

  final SettingsController _settings = SettingsController();
  final CoreController _core = CoreController();

  // ── Navigation / auth state ───────────────────────────────────────────────

  bool _isAuthenticated = false;
  bool _isInitializing = false;
  AppPage _page = AppPage.dashboard;
  AuthScreen _authScreen = AuthScreen.login;

  // ── Services ──────────────────────────────────────────────────────────────

  final ApiClient _apiClient = ApiClient();
  late final PanelApi _api = PanelApi(_apiClient);
  late final AuthSessionService _authSession = AuthSessionService(
    _apiClient,
    _api,
  );
  late final DataLoader _dataLoader = DataLoader(_api);

  // ── Data (mock defaults until API populates) ──────────────────────────────

  final SubscriptionController _subscription = SubscriptionController();
  late final AccountController _account = AccountController(_api);
  NodeRuntimeState _nodeState = const NodeRuntimeState();
  List<PlanModel> _plans = const [];
  late final InviteController _invite = InviteController(_api, refreshData);
  late final WalletController _wallet = WalletController(_api, refreshData);
  String? _dataLoadError;
  String? _startupMessage;
  final NoticesController _notices = NoticesController();
  UpdateInfo? _updateInfo;
  RegisterConfig _registerConfig = const RegisterConfig();
  bool _disposed = false;

  // ── Settings delegates ────────────────────────────────────────────────────

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

  Future<void> setProxyPort(int port) async {
    final old = _settings.proxyPort;
    await _settings.setProxyPort(port);
    if (_settings.proxyPort != old) {
      unawaited(_reloadCoreConfig());
    }
  }

  void setAutoStart(bool v) => _settings.setAutoStart(v);
  void setAutoUpdate(bool v) => _settings.setAutoUpdate(v);
  void setDevMode(bool v) => _settings.setDevMode(v);
  void setLanguage(String v) => _settings.setLanguage(v);

  void setProxyMode(ProxyMode v) {
    final old = _settings.proxyMode;
    _settings.setProxyMode(v);
    if (_settings.proxyMode == old) return;
    if (Platform.isAndroid && coreRunning) {
      unawaited(_reloadCoreConfig());
    } else if (_core.coreProcessRunning) {
      unawaited(_core.setMode(v));
    }
  }

  void setNetworkMode(NetworkMode v) {
    final old = _settings.networkMode;
    _settings.setNetworkMode(v);
    if (_settings.networkMode != old) {
      unawaited(_reloadCoreConfig());
    }
  }

  void setDnsMode(String v) {
    final old = _settings.dnsMode;
    _settings.setDnsMode(v);
    if (_settings.dnsMode != old) {
      unawaited(_reloadCoreConfig());
    }
  }

  void setKillSwitch(bool v) {
    _settings.setKillSwitch(v);
    _core.killSwitchEnabled = _settings.killSwitch;
  }

  void setAllowInsecureNodes(bool v) {
    final old = _settings.allowInsecureNodes;
    _settings.setAllowInsecureNodes(v);
    if (_settings.allowInsecureNodes != old) {
      // The flag changes the generated outbound config — rebuild the core.
      unawaited(_reloadCoreConfig());
    }
  }

  // ── Core delegates ─────────────────────────────────────────────────────────

  ConnectionStatus get connectionStatus => _core.connectionStatus;
  bool get coreRunning => _core.coreRunning;
  bool get coreConnecting => _core.coreConnecting;
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
      CorePlatformSupport.supportsCurrentPlatform;

  CoreConnectionRequest get _connectionRequest => CoreConnectionRequest(
    nodes: _nodeState.nodes,
    currentNode: currentNode,
    proxyMode: _settings.proxyMode,
    dnsMode: _settings.dnsMode,
    proxyPort: _settings.proxyPort,
    networkMode: _settings.networkMode,
    allowInsecure: _settings.allowInsecureNodes,
  );

  /// Graceful shutdown: kills core + disables system proxy. Call before exit.
  Future<void> shutdown() => _core.shutdown();

  /// Restart the running core (stop → 800 ms pause → reconnect).
  Future<String?> restartCore() async {
    if (!coreRunning) return null;
    await toggleConnection(); // stop
    await Future.delayed(const Duration(milliseconds: 800));
    return toggleConnection(); // start
  }

  /// Force-sync the system proxy to match current core state.
  Future<void> fixProxy() => _core.fixProxy(_settings.proxyPort);

  /// Export buffered log lines to %LOCALAPPDATA%\Litchi\. Returns the path.
  Future<String?> exportLogs() => _core.exportLogs();

  static Future<String> getCoreVersion() => CoreController.getCoreVersion();

  // ── Navigation / auth getters ─────────────────────────────────────────────

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  AppPage get page => _page;
  AuthScreen get authScreen => _authScreen;

  // ── Data getters ──────────────────────────────────────────────────────────

  UserModel get user => _account.user;
  TrafficModel get traffic => _account.traffic;
  bool get autoSelected => _nodeState.autoSelected;
  NodeModel get currentNode => _nodeState.displayNode;
  List<NodeModel> get nodes => _nodeState.nodes;
  List<PlanModel> get plans => _plans;
  List<InviteCodeModel> get inviteCodes => _invite.codes;
  String get inviteCode => _invite.code;
  String get inviteLink => _invite.link;
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
  int? get aliveIp => _subscription.aliveIp;
  int? get deviceLimit => _subscription.deviceLimit;
  int? get resetDay => _subscription.resetDay;
  int? get expiredAt => _subscription.expiredAt;
  String? get dataLoadError => _dataLoadError;
  String get currencySymbol => _wallet.currencySymbol;
  String? get startupMessage => _startupMessage;
  void clearStartupMessage() {
    if (_startupMessage == null) return;
    _startupMessage = null;
    notifyListeners();
  }

  PanelApi get api => _api;
  UpdateInfo? get updateInfo => _updateInfo;
  RegisterConfig get registerConfig => _registerConfig;

  void dismissUpdate() {
    _updateInfo = null;
    notifyListeners();
  }

  List<NoticeModel> get notices => _notices.notices;
  bool get hasUnreadNotice => _notices.hasUnreadNotice;

  void markNoticeRead() => _notices.markRead();

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _settings.load();
    await _notices.loadLastSeen();
    await _core.init();
    _core.killSwitchEnabled = _settings.killSwitch;

    _apiClient.configure(AppConfig.apiBase);
    _apiClient.onSessionExpired = logout;
    await _loadCachedRegisterConfig();
    unawaited(refreshRegisterConfigCache());

    final authData = await _authSession.restoreSavedAuthData();
    if (authData == null || authData.isEmpty) {
      if (await _loginFromSavedCredentials()) {
        unawaited(_checkForUpdate());
        return;
      }
      _isInitializing = false;
      notifyListeners();
      unawaited(_checkForUpdate());
      return;
    }

    final cached = await NodeCacheService.load();
    if (cached.isNotEmpty) {
      _nodeState = _nodeState.copyWith(nodes: cached);
      _restoreLastNode();
      if (supportsCoreConnection) {
        unawaited(_startCoreInBackground(runLatencyTest: true));
      }
    }

    // Saved token auto-login should never block the UI. Enter the main shell
    // first, then validate / refresh server data in the background.
    _isAuthenticated = true;
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

  Future<void> refreshRegisterConfigCache() async {
    try {
      final config = await _api.fetchRegisterConfig();
      await RegisterConfigCache.save(AppConfig.apiBase, config);
      _registerConfig = config;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Keep the cached/default registration config. The register API remains
      // the final authority when the user submits the form.
    }
  }

  Future<void> _refreshAfterAutoLogin() async {
    try {
      await _loadAllData();
      _dataLoadError = null;
      if (!_disposed) notifyListeners();
    } catch (e) {
      if (NetworkErrorClassifier.isNetworkError(e)) {
        _dataLoadError = DataLoadErrorService.offlineMessage(
          hasCachedNodes: _nodeState.nodes.isNotEmpty,
        );
        if (!_disposed) notifyListeners();
        return;
      }

      await _authSession.clear();
      if (await _loginFromSavedCredentials()) {
        return;
      }
      _isAuthenticated = false;
      _authScreen = AuthScreen.login;
      _startupMessage = '登录已过期，请重新登录';
      _resetSessionData();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.check();
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
    _wallet.removeListener(notifyListeners);
    _invite.removeListener(notifyListeners);
    _notices.removeListener(notifyListeners);
    _account.removeListener(notifyListeners);
    _subscription.removeListener(notifyListeners);
    _settings.dispose();
    _core.dispose();
    _wallet.dispose();
    _invite.dispose();
    _notices.dispose();
    _account.dispose();
    _subscription.dispose();
    super.dispose();
  }

  void _onCoreChanged() {
    final effect = CoreStateSyncService.effectFor(
      status: _core.connectionStatus,
      coreProcessRunning: _core.coreProcessRunning,
    );
    if (effect == null) return;

    final wasConnected = effect.wasConnected;
    if (wasConnected != null) {
      _settings.setWasConnected(wasConnected);
    }
    if (effect.runLatencyTest) {
      unawaited(testLatencies());
    }
    if (effect.clearLatency) {
      _nodeState = _nodeState.copyWith(
        nodes: NodeSelectionService.clearLatency(_nodeState.nodes),
      );
      notifyListeners();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void goToPage(AppPage page) {
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  void goToAuthScreen(AuthScreen screen) {
    if (_authScreen == screen) return;
    _authScreen = screen;
    notifyListeners();
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<void> loginWithCredentials(
    String email,
    String password, {
    Future<void> Function(String authData)? onAuthenticated,
  }) async {
    final result = await _api.login(email, password);
    await onAuthenticated?.call(result.authData);
    await _completeAuthentication(result.authData);
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
    await _authSession.applyAuthData(authData);
    await _loadAllData();
    _isAuthenticated = true;
    _dataLoadError = null;
    _page = AppPage.dashboard;
    notifyListeners();
  }

  Future<bool> _loginFromSavedCredentials() async {
    try {
      final result = await _authSession.loginFromSavedCredentials();
      if (result == null) return false;
      await _loadAllData();
      _isAuthenticated = true;
      _dataLoadError = null;
      _page = AppPage.dashboard;
      notifyListeners();
      return true;
    } catch (_) {
      _startupMessage = '自动登录失败，请手动登录';
      await _authSession.clear();
      return false;
    }
  }

  void logout() {
    _core.stopAndReset();
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _resetSessionData();
    unawaited(_authSession.clear());
    unawaited(NodeCacheService.clear());
    notifyListeners();
  }

  void _resetSessionData() {
    _subscription.reset();
    _account.reset();
    _nodeState = const NodeRuntimeState();
    _plans = const [];
    _invite.reset();
    _wallet.reset();
    _dataLoadError = null;
    _notices.reset();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<String?> toggleConnection() {
    if (!supportsCoreConnection) {
      return Future.value('当前平台暂未接入核心连接');
    }
    return _core.toggleConnection(_connectionRequest);
  }

  /// Checks whether the current process is running with elevated (admin) privileges.
  /// Returns true on non-Windows platforms (no-op).
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

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    final snap = await _dataLoader.loadAll();
    _applySnapshot(snap);
    // Non-critical extras — must never abort node restore / core startup.
    try {
      final currencySymbol = await _api.getCommCurrencySymbol();
      _wallet.setCurrencySymbol(currencySymbol);
    } catch (_) {}
    try {
      _notices.setNotices(await _api.getNotices());
    } catch (_) {}
    if (_nodeState.nodes.isNotEmpty) {
      unawaited(NodeCacheService.save(_nodeState.nodes));
      _restoreLastNode();
      if (supportsCoreConnection) {
        // Start core in background so latency testing works before user connects.
        unawaited(_startCoreInBackground(runLatencyTest: true));
      }
    }
  }

  /// Re-fetches all remote data. Clears any prior load error.
  Future<void> refreshData() async {
    _dataLoadError = null;
    notifyListeners();
    try {
      await _loadAllData();
      _dataLoadError = null;
    } catch (e) {
      if (NetworkErrorClassifier.isNetworkError(e)) {
        _dataLoadError = DataLoadErrorService.offlineMessage(
          hasCachedNodes: _nodeState.nodes.isNotEmpty,
        );
      } else {
        await _authSession.clear();
        _isAuthenticated = false;
        _authScreen = AuthScreen.login;
        _startupMessage = '登录已过期，请重新登录';
        _resetSessionData();
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
      _nodeState = _nodeState.copyWith(nodes: snap.nodes!);
      _restoreLastNode();
      _account.setTraffic(snap.traffic);
      unawaited(NodeCacheService.save(_nodeState.nodes));
      if (supportsCoreConnection) {
        await _reloadCoreConfig(startIfStopped: true);
      }
    }
    notifyListeners();
  }

  void _applySnapshot(DataSnapshot snap) {
    _account.applySnapshot(user: snap.user, traffic: snap.traffic);
    _subscription.applySnapshot(
      subscribeUrl: snap.subscribeUrl,
      dailyUsage: snap.dailyUsage,
      trafficUsage: snap.trafficUsage,
      aliveIp: snap.aliveIp,
      deviceLimit: snap.deviceLimit,
      resetDay: snap.resetDay,
      expiredAt: snap.expiredAt,
    );
    if (snap.nodes != null) {
      _nodeState = _nodeState.copyWith(nodes: snap.nodes!);
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
    if (snap.criticalError != null) _dataLoadError = snap.criticalError;
  }

  // ── Node selection ────────────────────────────────────────────────────────

  /// Tries to restore the last manually-selected node from persistent storage.
  /// Falls back to the first node in auto-select mode if the node is not found.
  void _restoreLastNode() {
    final restored = NodeSelectionService.restoreLastSelection(
      nodes: _nodeState.nodes,
      lastNodeId: _settings.lastNodeId,
    );
    _nodeState = _nodeState.copyWith(
      currentNode: restored.currentNode,
      autoSelected: restored.autoSelected,
    );
  }

  /// Switch to [node]. Returns an error string if the core rejected the
  /// switch, or null on success.
  Future<String?> setCurrentNode(NodeModel node) async {
    _nodeState = _nodeState.copyWith(currentNode: node, autoSelected: false);
    _settings.setLastNodeId(node.id);
    notifyListeners();
    if (Platform.isAndroid && coreRunning) {
      await _reloadCoreConfig();
      return null;
    }
    if (supportsCoreConnection && _core.coreProcessRunning) {
      final ok = await _core.switchNode(node);
      if (!ok) return '节点切换失败，核心未响应，请重试';
    }
    return null;
  }

  Future<String?> selectAuto() async {
    _nodeState = _nodeState.copyWith(autoSelected: true);
    _settings.setLastNodeId('');
    notifyListeners();
    if (Platform.isAndroid && coreRunning) {
      await _reloadCoreConfig();
      return null;
    }
    if (supportsCoreConnection && _core.coreProcessRunning) {
      // Hand off to sing-box's urltest outbound — it picks the fastest node
      // automatically based on real proxy latency, no Flutter involvement.
      final ok = await _core.switchToAuto();
      if (!ok) return '自动选择切换失败，核心未响应，请重试';
    }
    return null;
  }

  Future<void> _startCoreInBackground({bool runLatencyTest = false}) async {
    if (!supportsCoreConnection) return;
    await _core.startCoreOnly(_connectionRequest);
    if (_core.coreProcessRunning && runLatencyTest) {
      // Small delay to let the Clash API initialise before testing.
      await Future.delayed(const Duration(milliseconds: 1000));
      await testLatencies();
    }
  }

  Future<void> _reloadCoreConfig({bool startIfStopped = false}) async {
    if (!supportsCoreConnection) return;
    if (_nodeState.isEmpty) return;
    if (!startIfStopped && !coreProcessRunning) return;

    final error = await _core.reloadCore(_connectionRequest);
    if (error != null && error.isNotEmpty) {
      _startupMessage = error;
      notifyListeners();
      return;
    }

    if (coreProcessRunning) {
      await Future.delayed(const Duration(milliseconds: 1000));
      unawaited(testLatencies());
    }
  }

  /// Tests latencies for all nodes via the Clash API.
  /// Starts the sing-box process in background mode if needed.
  Future<void> testLatencies() async {
    if (!supportsCoreConnection) return;
    if (_nodeState.isEmpty) return;

    if (!coreProcessRunning) {
      if (Platform.isAndroid && !coreRunning) return;
      if (!Platform.isAndroid) {
        await _startCoreInBackground();
      }
      if (_disposed) return;
      if (coreProcessRunning) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    if (_disposed) return;

    // Mark all nodes as testing (-1) so the UI shows an in-progress state.
    _nodeState = _nodeState.copyWith(
      nodes: NodeSelectionService.markLatencyTesting(_nodeState.nodes),
    );
    notifyListeners();

    if (!coreProcessRunning) {
      _nodeState = _nodeState.copyWith(
        nodes: NodeSelectionService.markLatencyFailed(_nodeState.nodes),
      );
      _startupMessage = '测速失败：核心未启动，请检查 sing-box.exe 是否存在';
      notifyListeners();
      return;
    }

    final snapshot = List<NodeModel>.from(_nodeState.nodes);
    final pending = <int, NodeModel>{};
    Timer? flushTimer;

    void flushLatencyResults() {
      if (_disposed) return;
      if (pending.isEmpty) return;
      final list = NodeSelectionService.applyLatencyResults(
        _nodeState.nodes,
        pending,
      );
      pending.clear();
      _nodeState = _nodeState.copyWith(nodes: list);
      notifyListeners();
    }

    try {
      await _core.testLatencies(
        snapshot,
        onResult: (idx, updated) {
          if (_disposed) return;
          if (idx < _nodeState.nodes.length) {
            pending[idx] = updated;
            flushTimer ??= Timer.periodic(
              const Duration(milliseconds: 100),
              (_) => flushLatencyResults(),
            );
          }
        },
      );
    } finally {
      flushTimer?.cancel();
      flushLatencyResults();
    }
  }
}

/// Exposes [AppController] to descendants and rebuilds them on change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Reads the controller WITHOUT subscribing to rebuilds. Use this when you
  /// only need to call methods, or when subscribing to a specific slice via
  /// [AppSelector] / [ValueListenableBuilder] instead of the whole controller.
  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
