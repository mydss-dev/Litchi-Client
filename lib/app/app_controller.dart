import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/config/app_config.dart';
import '../shared/models/app_models.dart';
import '../shared/models/mock_data.dart';
import '../shared/services/api_client.dart';
import '../shared/services/core_manager.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/latency_tester.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/settings_service.dart';
import '../shared/services/singbox_api_client.dart';
import '../shared/services/singbox_config.dart';
import '../shared/services/token_storage.dart';

/// Top-level navigation destinations shown in the sidebar (§8.4).
enum AppPage { dashboard, nodes, shop, traffic, invite, settings, account, orders }

/// Which authentication screen is visible while logged out (§16).
enum AuthScreen { login, register, changePassword }

/// Coordinator: holds all UI state, delegates persistence and data fetching
/// to [SettingsService] and [DataLoader].
class AppController extends ChangeNotifier {
  AppController();

  // ── Navigation / init state ───────────────────────────────────────────────

  bool       _isAuthenticated = false;
  bool       _isInitializing  = true;
  AppPage    _page             = AppPage.dashboard;
  AuthScreen _authScreen       = AuthScreen.login;
  ThemeMode  _themeMode        = ThemeMode.light;

  // ── Settings ──────────────────────────────────────────────────────────────

  bool   _autoStart  = false;
  bool   _autoUpdate = true;
  bool   _devMode    = false;
  String _language   = '简体中文';
  String _proxyMode  = '智能模式';
  String _dnsMode    = '系统 DNS';
  int    _proxyPort  = 7890;

  // ── Services ──────────────────────────────────────────────────────────────

  final ApiClient  _apiClient  = ApiClient();
  late final PanelApi  _api        = PanelApi(_apiClient);
  late final DataLoader _dataLoader = DataLoader(_api);
  final CoreManager    _core        = CoreManager();
  StreamSubscription<CoreState>? _coreStateSub;

  // ── Connection state ──────────────────────────────────────────────────────

  DateTime? _connectedAt;
  bool      _coreConnecting = false;
  String    _coreError      = '';

  // ── Data (mock defaults until API populates) ──────────────────────────────

  String           _subscribeUrl   = '';
  UserModel        _user           = MockData.user;
  TrafficModel     _traffic        = MockData.traffic;
  NodeModel        _currentNode    = MockData.currentNode;
  List<NodeModel>  _nodes          = MockData.nodes;
  List<PlanModel>  _plans          = MockData.plans;
  bool             _autoSelected   = false;
  String           _inviteCode     = MockData.inviteCode;
  String           _inviteLink     = MockData.inviteLink;
  double           _commissionRate = MockData.commissionRate;
  int              _invitedCount   = MockData.invitedCount;
  double           _withdrawable   = MockData.withdrawable;
  List<double>     _dailyUsage     = MockData.dailyUsage;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool       get isAuthenticated => _isAuthenticated;
  bool       get isInitializing  => _isInitializing;
  AppPage    get page            => _page;
  AuthScreen get authScreen      => _authScreen;
  ThemeMode  get themeMode       => _themeMode;
  bool       get isDark          => _themeMode == ThemeMode.dark;

  bool   get autoStart  => _autoStart;
  bool   get autoUpdate => _autoUpdate;
  bool   get devMode    => _devMode;
  String get language   => _language;
  String get proxyMode  => _proxyMode;
  String get dnsMode    => _dnsMode;

  UserModel    get user    => _user;
  TrafficModel get traffic => _traffic;
  bool         get autoSelected => _autoSelected;

  bool             get coreRunning    => _core.isRunning;
  bool             get coreConnecting => _coreConnecting;
  String           get coreError      => _coreError;
  int              get proxyPort      => _proxyPort;
  Stream<String>   get coreLogStream  => _core.logStream;
  PanelApi         get api            => _api;
  Duration get connectedDuration =>
      _connectedAt != null ? DateTime.now().difference(_connectedAt!) : Duration.zero;

  NodeModel        get currentNode    => _autoSelected ? (_bestNode ?? _currentNode) : _currentNode;
  List<NodeModel>  get nodes          => _nodes;
  List<PlanModel>  get plans          => _plans;
  String           get inviteCode     => _inviteCode;
  String           get inviteLink     => _inviteLink;
  double           get commissionRate => _commissionRate;
  int              get invitedCount   => _invitedCount;
  double           get withdrawable   => _withdrawable;
  List<double>     get dailyUsage     => _dailyUsage;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    final s = await SettingsService.load();
    _proxyPort  = s.proxyPort;
    _autoStart  = s.autoStart;
    _autoUpdate = s.autoUpdate;
    _devMode    = s.devMode;
    _language   = s.language;
    _proxyMode  = s.proxyMode;
    _dnsMode    = s.dnsMode;
    _themeMode  = s.themeMode;

    _apiClient.configure(AppConfig.apiBase);
    _apiClient.onSessionExpired = logout;

    final authData = await TokenStorage.getAuthData();
    if (authData != null && authData.isNotEmpty) {
      _apiClient.updateAuthData(authData);
      try {
        await _loadAllData();
        _isAuthenticated = true;
      } catch (_) {
        await TokenStorage.clearAuthData();
        _apiClient.updateAuthData(null);
      }
    }

    _coreStateSub = _core.stateStream.listen(_onCoreStateChanged);
    _isInitializing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _coreStateSub?.cancel();
    _core.dispose();
    super.dispose();
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
  }) async {
    final result = await _api.register(
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      inviteCode: inviteCode,
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

  // ── Settings setters ──────────────────────────────────────────────────────

  Future<void> setProxyPort(int port) async {
    if (port < 1 || port > 65535 || port == _proxyPort) return;
    _proxyPort = port;
    SettingsService.setProxyPort(port);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    SettingsService.setThemeMode(mode);
    notifyListeners();
  }

  void toggleDarkMode(bool enabled) =>
      setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);

  void setAutoStart(bool v) {
    if (_autoStart == v) return;
    _autoStart = v;
    SettingsService.setAutoStart(v);
    notifyListeners();
  }

  void setAutoUpdate(bool v) {
    if (_autoUpdate == v) return;
    _autoUpdate = v;
    SettingsService.setAutoUpdate(v);
    notifyListeners();
  }

  void setDevMode(bool v) {
    if (_devMode == v) return;
    _devMode = v;
    SettingsService.setDevMode(v);
    notifyListeners();
  }

  void setLanguage(String v) {
    if (_language == v) return;
    _language = v;
    SettingsService.setLanguage(v);
    notifyListeners();
  }

  void setProxyMode(String v) {
    if (_proxyMode == v) return;
    _proxyMode = v;
    SettingsService.setProxyMode(v);
    notifyListeners();
  }

  void setDnsMode(String v) {
    if (_dnsMode == v) return;
    _dnsMode = v;
    SettingsService.setDnsMode(v);
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  /// Connect or disconnect sing-box. Returns an error string or null.
  Future<String?> toggleConnection() async {
    if (_coreConnecting) return null;

    if (_core.isRunning) {
      _coreConnecting = true;
      notifyListeners();
      await _core.stop();
      await ProxySetter.disable();
      _connectedAt    = null;
      _coreError      = '';
      _coreConnecting = false;
      notifyListeners();
      return null;
    }

    final validNodes = _nodes.where((n) => n.rawUri.isNotEmpty).toList();
    if (validNodes.isEmpty) {
      _coreError = '没有可用节点，请刷新节点列表后重试';
      notifyListeners();
      return _coreError;
    }

    final selectedTag = SingboxConfig.nodeTagFor(currentNode);
    final config = SingboxConfig.buildFullConfig(
      validNodes,
      selectedTag: selectedTag,
      port: _proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: _proxyMode,
      dnsMode: _dnsMode,
    );

    if (config == null) {
      _coreError = '生成配置失败，请选择其他节点后重试';
      notifyListeners();
      return _coreError;
    }

    _coreConnecting = true;
    _coreError      = '';
    notifyListeners();

    try {
      final configPath = await SingboxConfig.writeConfig(config);
      await _core.start(configPath, apiPort: SingboxConfig.defaultApiPort);

      if (_core.isRunning) {
        await ProxySetter.enable(port: _proxyPort);
        _connectedAt = DateTime.now();
        _coreError   = '';
      } else {
        _coreError = _core.lastError.isNotEmpty
            ? _core.lastError
            : '连接失败，请检查 sing-box.exe 是否存在';
      }
    } catch (e) {
      _coreError = '连接异常: $e';
    } finally {
      _coreConnecting = false;
      notifyListeners();
    }
    return _coreError.isNotEmpty ? _coreError : null;
  }

  void logout() {
    if (_core.isRunning) {
      _core.stop();
      ProxySetter.disable();
      _connectedAt = null;
    }
    _isAuthenticated = false;
    _authScreen      = AuthScreen.login;
    _subscribeUrl    = '';
    _autoSelected    = false;
    _coreError       = '';
    TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
    _user           = MockData.user;
    _traffic        = MockData.traffic;
    _currentNode    = MockData.currentNode;
    _nodes          = MockData.nodes;
    _plans          = MockData.plans;
    _inviteCode     = MockData.inviteCode;
    _inviteLink     = MockData.inviteLink;
    _commissionRate = MockData.commissionRate;
    _invitedCount   = MockData.invitedCount;
    _withdrawable   = MockData.withdrawable;
    _dailyUsage     = MockData.dailyUsage;
    notifyListeners();
  }

  // ── Core state watcher ────────────────────────────────────────────────────

  void _onCoreStateChanged(CoreState state) {
    // React only to unexpected crashes (deliberate stop() clears _connectedAt first).
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_connectedAt != null || _coreConnecting)) {
      _connectedAt    = null;
      _coreConnecting = false;
      if (_core.lastError.isNotEmpty) _coreError = _core.lastError;
      ProxySetter.disable();
      notifyListeners();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    final snap = await _dataLoader.loadAll();
    _applySnapshot(snap);
    if (_nodes.isNotEmpty) {
      _currentNode  = _nodes.first;
      _autoSelected = true;
      testLatencies(); // fire-and-forget; notifies per node as results arrive
    }
  }

  Future<void> refreshNodes() async {
    final snap = await _dataLoader.loadNodes(_subscribeUrl);
    if (snap.nodes != null && snap.nodes!.isNotEmpty) {
      _nodes        = snap.nodes!;
      _currentNode  = _nodes.first;
      _autoSelected = true;
      if (snap.traffic != null) _traffic = snap.traffic!;
      testLatencies(); // fire-and-forget
    }
    notifyListeners();
  }

  void _applySnapshot(DataSnapshot snap) {
    if (snap.user           != null) _user           = snap.user!;
    if (snap.traffic        != null) _traffic        = snap.traffic!;
    if (snap.subscribeUrl   != null) _subscribeUrl   = snap.subscribeUrl!;
    if (snap.nodes          != null) _nodes          = snap.nodes!;
    if (snap.plans          != null) _plans          = snap.plans!;
    if (snap.inviteCode     != null) _inviteCode     = snap.inviteCode!;
    if (snap.inviteLink     != null) _inviteLink     = snap.inviteLink!;
    if (snap.commissionRate != null) _commissionRate = snap.commissionRate!;
    if (snap.invitedCount   != null) _invitedCount   = snap.invitedCount!;
    if (snap.withdrawable   != null) _withdrawable   = snap.withdrawable!;
    if (snap.dailyUsage     != null) _dailyUsage     = snap.dailyUsage!;
  }

  // ── Node selection ────────────────────────────────────────────────────────

  Future<void> setCurrentNode(NodeModel node) async {
    _autoSelected = false;
    _currentNode  = node;
    notifyListeners();
    if (_core.isRunning) {
      await SingboxApiClient.switchProxy(
        SingboxConfig.nodeTagFor(node),
        apiPort: SingboxConfig.defaultApiPort,
      );
    }
  }

  Future<void> selectAuto() async {
    _autoSelected = true;
    final best = _bestNode;
    if (best != null) {
      _currentNode = best;
      notifyListeners();
      if (_core.isRunning) {
        await SingboxApiClient.switchProxy(
          SingboxConfig.nodeTagFor(best),
          apiPort: SingboxConfig.defaultApiPort,
        );
      }
    } else {
      notifyListeners();
    }
  }

  NodeModel? get _bestNode {
    NodeModel? best;
    for (final n in _nodes) {
      if (n.latency <= 0 || n.latency >= LatencyTester.unreachable) continue;
      if (best == null || n.latency < best.latency) best = n;
    }
    return best;
  }

  /// Tests latencies for all nodes (max 10 concurrent). Notifies per result.
  Future<void> testLatencies() async {
    if (_nodes.isEmpty) return;
    _nodes = _nodes.map((n) => n.copyWith(latency: -1)).toList();
    notifyListeners();

    final sem = _Semaphore(10);

    await Future.wait(_nodes.asMap().entries.map((e) async {
      await sem.acquire();
      try {
        final idx  = e.key;
        final node = e.value;

        final int ms;
        if (_core.isRunning) {
          ms = await SingboxApiClient.testDelay(
                SingboxConfig.nodeTagFor(node),
                apiPort: SingboxConfig.defaultApiPort,
              ) ?? LatencyTester.unreachable;
        } else {
          ms = await LatencyTester.ping(node.server, node.port);
        }

        if (idx < _nodes.length) {
          final updated = List<NodeModel>.from(_nodes);
          updated[idx] = node.copyWith(latency: ms);
          _nodes = updated;
          if (_autoSelected) {
            final best = _bestNode;
            if (best != null) _currentNode = best;
          }
          notifyListeners();
        }
      } finally {
        sem.release();
      }
    }));
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

// ── Simple counting semaphore ─────────────────────────────────────────────────

class _Semaphore {
  _Semaphore(this._max);

  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_count < _max) { _count++; return; }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
    _count++;
  }

  void release() {
    _count--;
    if (_queue.isNotEmpty) _queue.removeAt(0).complete();
  }
}
