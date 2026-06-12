import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../shared/config/app_config.dart';
import '../shared/models/api_models.dart';
import '../shared/models/app_models.dart';
import '../shared/services/api_client.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/node_cache_service.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/settings_service.dart';
import '../shared/services/token_storage.dart';
import '../shared/services/update_service.dart';
import 'core_controller.dart';
import 'settings_controller.dart';

/// Top-level navigation destinations shown in the sidebar.
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
  }

  final SettingsController _settings = SettingsController();
  final CoreController _core = CoreController();

  // ── Navigation / auth state ───────────────────────────────────────────────

  bool _isAuthenticated = false;
  bool _isInitializing = true;
  AppPage _page = AppPage.dashboard;
  AuthScreen _authScreen = AuthScreen.login;

  // ── Services ──────────────────────────────────────────────────────────────

  final ApiClient _apiClient = ApiClient();
  late final PanelApi _api = PanelApi(_apiClient);
  late final DataLoader _dataLoader = DataLoader(_api);

  // ── Data (mock defaults until API populates) ──────────────────────────────

  String _subscribeUrl = '';
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
  String _inviteCode = '';
  String _inviteLink = '';
  double _commissionRate = 0;
  int _invitedCount = 0;
  double _withdrawable = 0;
  List<double> _dailyUsage = const [];
  List<TrafficUsagePoint> _trafficUsage = [];
  int? _aliveIp;
  int? _deviceLimit;
  int? _resetDay;
  int? _expiredAt;
  String? _dataLoadError;
  String _currencySymbol = '¥';
  String? _startupMessage;
  List<NoticeModel> _notices = [];
  int _lastSeenNoticeId = 0;
  UpdateInfo? _updateInfo;
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
    if (_settings.proxyMode != old && _core.coreProcessRunning) {
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
  String get inviteCode => _inviteCode;
  String get inviteLink => _inviteLink;
  double get commissionRate => _commissionRate;
  int get invitedCount => _invitedCount;
  double get withdrawable => _withdrawable;
  List<double> get dailyUsage => _dailyUsage;
  List<TrafficUsagePoint> get trafficUsage => _trafficUsage;
  int? get aliveIp => _aliveIp;
  int? get deviceLimit => _deviceLimit;
  int? get resetDay => _resetDay;
  int? get expiredAt => _expiredAt;
  String? get dataLoadError => _dataLoadError;
  String get currencySymbol => _currencySymbol;
  String? get startupMessage => _startupMessage;
  void clearStartupMessage() => _startupMessage = null;
  PanelApi get api => _api;
  UpdateInfo? get updateInfo => _updateInfo;

  void dismissUpdate() {
    _updateInfo = null;
    notifyListeners();
  }

  List<NoticeModel> get notices => _notices;
  bool get hasUnreadNotice =>
      _notices.isNotEmpty && _notices.first.id > _lastSeenNoticeId;

  void markNoticeRead() {
    if (_notices.isEmpty) return;
    _lastSeenNoticeId = _notices.first.id;
    SettingsService.setLastSeenNoticeId(_lastSeenNoticeId);
    notifyListeners();
  }

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _settings.load();
    _lastSeenNoticeId = await SettingsService.loadLastSeenNoticeId();
    await _core.init();

    _apiClient.configure(AppConfig.apiBase);
    _apiClient.onSessionExpired = logout;

    final authData = await TokenStorage.getAuthData();
    if (authData != null && authData.isNotEmpty) {
      _apiClient.updateAuthData(authData);
      try {
        await _loadAllData();
        _isAuthenticated = true;
      } catch (e) {
        if (_isNetworkError(e)) {
          // Network unavailable at startup — token is likely still valid.
          // Stay logged in and let the ErrorBanner guide the user to retry.
          _isAuthenticated = true;
          _dataLoadError = '网络连接失败，请检查网络后刷新';
          // Restore cached nodes so the core can still start for latency tests.
          final cached = await NodeCacheService.load();
          if (cached.isNotEmpty) {
            _nodes = cached;
            _restoreLastNode();
            unawaited(_startCoreInBackground());
          }
        } else {
          await TokenStorage.clearAuthData();
          _apiClient.updateAuthData(null);
          _startupMessage = '登录已过期，请重新登录';
        }
      }
    }

    _isInitializing = false;
    notifyListeners();

    if (_isAuthenticated && _settings.wasConnected) {
      unawaited(toggleConnection().then((_) {}));
    }
    unawaited(_checkForUpdate());
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
    _settings.dispose();
    _core.dispose();
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

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> loginWithCredentials(String email, String password) async {
    final result = await _api.login(email, password);
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

  Future<void> _completeAuthentication(String authData) async {
    await TokenStorage.saveAuthData(authData);
    _apiClient.updateAuthData(authData);
    await _loadAllData();
    _isAuthenticated = true;
    _page = AppPage.dashboard;
    notifyListeners();
  }

  void logout() {
    _core.stopAndReset();
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _subscribeUrl = '';
    _autoSelected = false;
    TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
    _user = const UserModel(name: '', plan: '', avatarLetter: '', expiry: '');
    _traffic = const TrafficModel(totalGb: 0, usedGb: 0, remainGb: 0);
    _currentNode = const NodeModel(id: '', name: '', flag: '', latency: 0);
    _nodes = const [];
    _plans = const [];
    _inviteCode = '';
    _inviteLink = '';
    _commissionRate = 0;
    _invitedCount = 0;
    _withdrawable = 0;
    _dailyUsage = const [];
    _trafficUsage = [];
    _aliveIp = null;
    _deviceLimit = null;
    _resetDay = null;
    _expiredAt = null;
    _dataLoadError = null;
    _currencySymbol = '¥';
    _notices = [];
    unawaited(NodeCacheService.clear());
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<String?> toggleConnection() => _core.toggleConnection(
        nodes: _nodes,
        currentNode: currentNode,
        proxyMode: _settings.proxyMode,
        dnsMode: _settings.dnsMode,
        proxyPort: _settings.proxyPort,
        networkMode: _settings.networkMode,
      );

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
      _currencySymbol = await _api.getCommCurrencySymbol();
    } catch (_) {}
    try {
      _notices = await _api.getNotices();
    } catch (_) {}
    if (_nodes.isNotEmpty) {
      unawaited(NodeCacheService.save(_nodes));
      _restoreLastNode();
      // Start core in background so latency testing works before user connects.
      unawaited(_startCoreInBackground());
    }
  }

  /// Re-fetches all remote data. Clears any prior load error.
  Future<void> refreshData() async {
    _dataLoadError = null;
    notifyListeners();
    await _loadAllData();
    notifyListeners();
  }

  Future<void> refreshNodes() async {
    final snap = await _dataLoader.loadNodes(_subscribeUrl);
    if (snap.nodes != null && snap.nodes!.isNotEmpty) {
      _nodes = snap.nodes!;
      _restoreLastNode();
      if (snap.traffic != null) _traffic = snap.traffic!;
      unawaited(NodeCacheService.save(_nodes));
      await _reloadCoreConfig(startIfStopped: true);
    }
    notifyListeners();
  }

  void _applySnapshot(DataSnapshot snap) {
    if (snap.user != null) _user = snap.user!;
    if (snap.traffic != null) _traffic = snap.traffic!;
    if (snap.subscribeUrl != null) _subscribeUrl = snap.subscribeUrl!;
    if (snap.nodes != null) _nodes = snap.nodes!;
    if (snap.plans != null) _plans = snap.plans!;
    if (snap.inviteCode != null) _inviteCode = snap.inviteCode!;
    if (snap.inviteLink != null) _inviteLink = snap.inviteLink!;
    // OSS override: rebuild invite link with the configured base domain.
    if (AppConfig.inviteUrlBase.isNotEmpty && _inviteCode.isNotEmpty) {
      final base = AppConfig.inviteUrlBase.replaceAll(RegExp(r'/+$'), '');
      _inviteLink = '$base/register?code=$_inviteCode';
    }
    if (snap.commissionRate != null) _commissionRate = snap.commissionRate!;
    if (snap.invitedCount != null) _invitedCount = snap.invitedCount!;
    if (snap.withdrawable != null) _withdrawable = snap.withdrawable!;
    if (snap.dailyUsage != null) _dailyUsage = snap.dailyUsage!;
    if (snap.trafficUsage != null) _trafficUsage = snap.trafficUsage!;
    if (snap.aliveIp != null) _aliveIp = snap.aliveIp;
    if (snap.deviceLimit != null) _deviceLimit = snap.deviceLimit;
    if (snap.resetDay != null) _resetDay = snap.resetDay;
    if (snap.expiredAt != null) _expiredAt = snap.expiredAt;
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
    if (_core.coreProcessRunning) {
      final ok = await _core.switchNode(node);
      if (!ok) return '节点切换失败，核心未响应，请重试';
    }
    return null;
  }

  Future<void> selectAuto() async {
    _autoSelected = true;
    _settings.setLastNodeId('');
    notifyListeners();
    if (_core.coreProcessRunning) {
      // Hand off to sing-box's urltest outbound — it picks the fastest node
      // automatically based on real proxy latency, no Flutter involvement.
      await _core.switchToAuto();
    }
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

  Future<void> _startCoreInBackground() async {
    await _core.startCoreOnly(
      nodes: _nodes,
      currentNode: currentNode,
      proxyMode: _settings.proxyMode,
      dnsMode: _settings.dnsMode,
      proxyPort: _settings.proxyPort,
    );
    if (_core.coreProcessRunning) {
      // Small delay to let the Clash API initialise before testing.
      await Future.delayed(const Duration(milliseconds: 800));
      unawaited(testLatencies());
    }
  }

  Future<void> _reloadCoreConfig({bool startIfStopped = false}) async {
    if (_nodes.isEmpty) return;
    if (!startIfStopped && !_core.coreProcessRunning) return;

    final error = await _core.reloadCore(
      nodes: _nodes,
      currentNode: currentNode,
      proxyMode: _settings.proxyMode,
      dnsMode: _settings.dnsMode,
      proxyPort: _settings.proxyPort,
      networkMode: _settings.networkMode,
    );
    if (error != null && error.isNotEmpty) {
      _startupMessage = error;
      notifyListeners();
      return;
    }

    if (_core.coreProcessRunning) {
      await Future.delayed(const Duration(milliseconds: 800));
      unawaited(testLatencies());
    }
  }

  /// Tests latencies for all nodes via the Clash API.
  /// Requires the sing-box process to be running (not necessarily connected).
  Future<void> testLatencies() async {
    if (_nodes.isEmpty) return;

    // Mark all nodes as testing (-1) so the UI shows an in-progress state.
    // Only when the core is alive — otherwise the test no-ops and the marks
    // would never be resolved back to real values.
    if (_core.coreProcessRunning) {
      _nodes = _nodes.map((n) => n.copyWith(latency: -1)).toList();
      notifyListeners();
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
}
