import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../shared/config/app_config.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/credentials_storage.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/register_config_cache.dart';
import '../shared/services/token_storage.dart';
import '../shared/services/tcp_ping_service.dart';
import '../shared/services/update_service.dart';
import 'core_controller.dart';
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
    _notices.addListener(notifyListeners);
    _subscription.addListener(notifyListeners);
    _wallet.addListener(notifyListeners);
    _invite.addListener(notifyListeners);
  }

  final SettingsController _settings = SettingsController();
  final CoreController _core = CoreController();
  final NoticesController _notices = NoticesController();
  final SubscriptionController _subscription = SubscriptionController();
  late final WalletController _wallet = WalletController(_api, refreshData);
  late final InviteController _invite = InviteController(_api, refreshData);

  // ── Navigation / auth state ───────────────────────────────────────────────

  bool _isAuthenticated = false;
  bool _isInitializing = false;
  AppPage _page = AppPage.dashboard;
  AuthScreen _authScreen = AuthScreen.login;

  // ── Services ──────────────────────────────────────────────────────────────

  final ApiClient _apiClient = ApiClient();
  late final PanelApi _api = PanelApi(_apiClient);
  late final DataLoader _dataLoader = DataLoader(_api);

  // ── Data (mock defaults until API populates) ──────────────────────────────

  UserModel _user = const UserModel(
    name: '',
    plan: '',
    avatarLetter: '',
    expiry: '',
  );
  TrafficModel _traffic = const TrafficModel(
    totalGb: 0,
    usedGb: 0,
    remainGb: 0,
  );
  NodeModel _currentNode = const NodeModel(
    id: '',
    name: '',
    flag: '',
    latency: 0,
  );
  List<NodeModel> _nodes = const [];
  List<PlanModel> _plans = const [];
  bool _autoSelected = false;
  String? _dataLoadError;
  String? _startupMessage;
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
  void setKillSwitch(bool v) {
    _settings.setKillSwitch(v);
    _core.killSwitchEnabled = _settings.killSwitch;
  }

  void setAllowInsecureNodes(bool v) {
    final old = _settings.allowInsecureNodes;
    _settings.setAllowInsecureNodes(v);
    if (_settings.allowInsecureNodes != old) {
      unawaited(_reloadCoreConfig());
    }
  }

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
  bool get supportsCoreConnection => Platform.isWindows || Platform.isAndroid;

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

  UserModel get user => _user;
  TrafficModel get traffic => _traffic;
  bool get autoSelected => _autoSelected;
  NodeModel get currentNode =>
      _autoSelected ? (_bestNode ?? _currentNode) : _currentNode;
  List<NodeModel> get nodes => _nodes;
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
  int? get aliveIp => _subscription.aliveIp;
  int? get deviceLimit => _subscription.deviceLimit;
  int? get resetDay => _subscription.resetDay;
  int? get expiredAt => _subscription.expiredAt;
  String? get dataLoadError => _dataLoadError;
  String get currencySymbol => _wallet.currencySymbol;
  String? get startupMessage => _startupMessage;
  void clearStartupMessage() => _startupMessage = null;
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

    final authData = await TokenStorage.getAuthData();
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

    _apiClient.updateAuthData(authData);

    final cached = await NodeCacheService.load();
    if (cached.isNotEmpty) {
      _nodes = cached;
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
      if (_isNetworkError(e)) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
        if (!_disposed) notifyListeners();
        return;
      }

      await TokenStorage.clearAuthData();
      _apiClient.updateAuthData(null);
      if (await _loginFromSavedCredentials()) {
        return;
      }
      _isAuthenticated = false;
      _authScreen = AuthScreen.login;
      _startupMessage = '登录已过期，请重新登录';
      _nodes = const [];
      _currentNode = const NodeModel(id: '', name: '', flag: '', latency: 0);
      _autoSelected = false;
      if (!_disposed) notifyListeners();
    }
  }

  static bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('超时') ||
        msg.contains('无法连接') ||
        msg.contains('网络请求失败') ||
        msg.contains('服务器响应异常');
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
    _notices.removeListener(notifyListeners);
    _subscription.removeListener(notifyListeners);
    _wallet.removeListener(notifyListeners);
    _invite.removeListener(notifyListeners);
    _settings.dispose();
    _core.dispose();
    _notices.dispose();
    _subscription.dispose();
    _wallet.dispose();
    _invite.dispose();
    super.dispose();
  }

  void _onCoreChanged() {
    final status = _core.connectionStatus;
    if (status == ConnectionStatus.connected) {
      _settings.setWasConnected(true);
      unawaited(testLatencies());
    } else if (status == ConnectionStatus.disconnected) {
      _settings.setWasConnected(false);
      // Core process may still be alive (system proxy mode) — keep latency data.
      // Only clear when process actually stopped (e.g. TUN disconnect / logout).
      if (!_core.coreProcessRunning) {
        _nodes = _nodes.map((n) => n.copyWith(latency: 0)).toList();
        notifyListeners();
      }
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
  }) async {
    final previous = _user;
    _user = _user.copyWith(
      remindExpire: remindExpire,
      remindTraffic: remindTraffic,
      autoRenewal: autoRenewal,
    );
    notifyListeners();

    try {
      await _api.updateUserSettings(
        remindExpire: remindExpire,
        remindTraffic: remindTraffic,
        autoRenewal: autoRenewal,
      );
      return null;
    } catch (e) {
      _user = previous;
      notifyListeners();
      return e.toString().replaceFirst('ApiException: ', '');
    }
  }

  Future<void> _completeAuthentication(String authData) async {
    await TokenStorage.saveAuthData(authData);
    _apiClient.updateAuthData(authData);
    await _loadAllData();
    _isAuthenticated = true;
    _dataLoadError = null;
    _page = AppPage.dashboard;
    notifyListeners();
  }

  Future<bool> _loginFromSavedCredentials() async {
    final saved = await CredentialsStorage.load();
    if (saved == null) return false;
    try {
      final result = await _api.login(saved.email, saved.password);
      await _completeAuthentication(result.authData);
      return true;
    } catch (_) {
      _startupMessage = '自动登录失败，请手动登录';
      await TokenStorage.clearAuthData();
      _apiClient.updateAuthData(null);
      return false;
    }
  }

  void logout() {
    _core.stopAndReset();
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _autoSelected = false;
    TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
    _user = const UserModel(name: '', plan: '', avatarLetter: '', expiry: '');
    _traffic = const TrafficModel(totalGb: 0, usedGb: 0, remainGb: 0);
    _currentNode = const NodeModel(id: '', name: '', flag: '', latency: 0);
    _nodes = const [];
    _plans = const [];
    _invite.reset();
    _wallet.reset();
    _subscription.reset();
    _dataLoadError = null;
    _notices.reset();
    unawaited(NodeCacheService.clear());
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<String?> toggleConnection() {
    if (!supportsCoreConnection) {
      return Future.value('当前平台暂未接入核心连接');
    }
    return _core.toggleConnection(
      nodes: _nodes,
      currentNode: currentNode,
      proxyMode: _settings.proxyMode,
      dnsMode: _settings.dnsMode,
      proxyPort: _settings.proxyPort,
      networkMode: _settings.networkMode,
      allowInsecure: _settings.allowInsecureNodes,
    );
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
      _wallet.setCurrencySymbol(await _api.getCommCurrencySymbol());
    } catch (_) {}
    try {
      _notices.setNotices(await _api.getNotices());
    } catch (_) {}
    if (_nodes.isNotEmpty) {
      unawaited(NodeCacheService.save(_nodes));
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
      if (_isNetworkError(e)) {
        _dataLoadError = _nodes.isNotEmpty
            ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
            : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
      } else {
        await TokenStorage.clearAuthData();
        _apiClient.updateAuthData(null);
        _isAuthenticated = false;
        _authScreen = AuthScreen.login;
        _startupMessage = '登录已过期，请重新登录';
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
      _nodes = snap.nodes!;
      _restoreLastNode();
      if (snap.traffic != null) _traffic = snap.traffic!;
      unawaited(NodeCacheService.save(_nodes));
      if (supportsCoreConnection) {
        await _reloadCoreConfig(startIfStopped: true);
      }
    }
    notifyListeners();
  }

  void _applySnapshot(DataSnapshot snap) {
    if (snap.user != null) _user = snap.user!;
    if (snap.traffic != null) _traffic = snap.traffic!;
    _subscription.applySnapshot(subscribeUrl: snap.subscribeUrl);
    if (snap.nodes != null) _nodes = snap.nodes!;
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
    );
    if (snap.criticalError != null) _dataLoadError = snap.criticalError;
  }

  // ── Node selection ────────────────────────────────────────────────────────

  /// Tries to restore the last manually-selected node from persistent storage.
  /// Falls back to the first node in auto-select mode if the node is not found.
  void _restoreLastNode() {
    if (_nodes.isEmpty) return;
    final lastId = _settings.lastNodeId;
    final saved = lastId.isNotEmpty
        ? _nodes.where((n) => n.id == lastId).firstOrNull
        : null;
    if (saved != null) {
      _currentNode = saved;
      _autoSelected = false;
    } else {
      _currentNode = _nodes.first;
      _autoSelected = true;
    }
  }

  /// Switch to [node]. Returns an error string if the core rejected the
  /// switch, or null on success.
  Future<String?> setCurrentNode(NodeModel node) async {
    _autoSelected = false;
    _currentNode = node;
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
    _autoSelected = true;
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

  // Used by _AutoCard to display the current best-latency node for reference.
  NodeModel? get _bestNode {
    NodeModel? best;
    for (final n in _nodes) {
      if (n.latency <= 0 || n.latency >= 9999) continue;
      if (best == null || n.latency < best.latency) best = n;
    }
    return best;
  }

  Future<void> _startCoreInBackground({bool runLatencyTest = false}) async {
    if (!supportsCoreConnection) return;
    if (Platform.isAndroid) {
      // Android can't run a background core (the core needs the VpnService
      // tunnel), so there is nothing to pre-start. Do a TCP-ping pass instead
      // so node latencies show up automatically before the user connects.
      if (runLatencyTest) await testLatencies();
      return;
    }
    await _core.startCoreOnly(
      nodes: _nodes,
      currentNode: currentNode,
      proxyMode: _settings.proxyMode,
      dnsMode: _settings.dnsMode,
      proxyPort: _settings.proxyPort,
      allowInsecure: _settings.allowInsecureNodes,
    );
    if (_core.coreProcessRunning && runLatencyTest) {
      // Small delay to let the Clash API initialise before testing.
      await Future.delayed(const Duration(milliseconds: 1000));
      await testLatencies();
    }
  }

  Future<void> _reloadCoreConfig({bool startIfStopped = false}) async {
    if (!supportsCoreConnection) return;
    if (_nodes.isEmpty) return;
    if (!startIfStopped && !coreProcessRunning) return;

    final error = await _core.reloadCore(
      nodes: _nodes,
      currentNode: currentNode,
      proxyMode: _settings.proxyMode,
      dnsMode: _settings.dnsMode,
      proxyPort: _settings.proxyPort,
      networkMode: _settings.networkMode,
      allowInsecure: _settings.allowInsecureNodes,
    );
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
    if (_nodes.isEmpty) return;

    // On Android before connecting, the sing-box core cannot expose the Clash
    // API yet, so we fall back to a direct TCP handshake ping per node.
    if (Platform.isAndroid && !coreProcessRunning) {
      // Mark all nodes as testing (-1).
      _nodes = _nodes.map((n) => n.copyWith(latency: -1)).toList();
      notifyListeners();

      // Ping in concurrent batches so a long list (and slow/timing-out nodes)
      // finishes in seconds instead of sequentially adding up every timeout.
      final snapshot = List<NodeModel>.from(_nodes);
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
        // Apply by node id so a concurrent node-list refresh can't misalign rows.
        final latencyById = {for (final r in results) r.id: r.latency};
        _nodes = _nodes
            .map(
              (n) => latencyById.containsKey(n.id)
                  ? n.copyWith(latency: latencyById[n.id])
                  : n,
            )
            .toList();
        notifyListeners();
      }
      return;
    }

    if (!coreProcessRunning) {
      if (!Platform.isAndroid) {
        await _startCoreInBackground();
      }
      if (coreProcessRunning) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    // Mark all nodes as testing (-1) so the UI shows an in-progress state.
    _nodes = _nodes.map((n) => n.copyWith(latency: -1)).toList();
    notifyListeners();

    if (!coreProcessRunning) {
      _nodes = _nodes.map((n) => n.copyWith(latency: 9999)).toList();
      _startupMessage = '测速失败：核心未启动，请检查 sing-box.exe 是否存在';
      notifyListeners();
      return;
    }

    final snapshot = List<NodeModel>.from(_nodes);
    await _core.testLatencies(
      snapshot,
      onResult: (idx, updated) {
        if (idx < _nodes.length) {
          final list = List<NodeModel>.from(_nodes);
          list[idx] = updated;
          _nodes = list;
          notifyListeners();
        }
      },
    );
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

  static AppController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope?.notifier != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
