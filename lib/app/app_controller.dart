import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/config/app_config.dart';
import '../shared/models/app_models.dart';
import '../shared/models/mock_data.dart';
import '../shared/services/api_client.dart';
import '../shared/services/data_loader.dart';
import '../shared/services/latency_tester.dart';
import '../shared/services/panel_api.dart';
import '../shared/services/token_storage.dart';
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
}

/// Which authentication screen is visible while logged out.
enum AuthScreen { login, register, changePassword }

/// Coordinator: owns navigation, auth, and subscription data.
/// Settings and core-process concerns are delegated to [SettingsController]
/// and [CoreController] respectively. All public getters/setters are preserved
/// so [AppScope] callers require no changes.
class AppController extends ChangeNotifier {
  AppController() {
    _settings.addListener(notifyListeners);
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
  UserModel _user = MockData.user;
  TrafficModel _traffic = MockData.traffic;
  NodeModel _currentNode = MockData.currentNode;
  List<NodeModel> _nodes = MockData.nodes;
  List<PlanModel> _plans = MockData.plans;
  bool _autoSelected = false;
  String _inviteCode = MockData.inviteCode;
  String _inviteLink = MockData.inviteLink;
  double _commissionRate = MockData.commissionRate;
  int _invitedCount = MockData.invitedCount;
  double _withdrawable = MockData.withdrawable;
  List<double> _dailyUsage = MockData.dailyUsage;

  // ── Settings delegates ────────────────────────────────────────────────────

  ThemeMode get themeMode => _settings.themeMode;
  bool get isDark => _settings.isDark;
  bool get autoStart => _settings.autoStart;
  bool get autoUpdate => _settings.autoUpdate;
  bool get devMode => _settings.devMode;
  String get language => _settings.language;
  String get proxyMode => _settings.proxyMode;
  String get dnsMode => _settings.dnsMode;
  int get proxyPort => _settings.proxyPort;

  void setThemeMode(ThemeMode mode) => _settings.setThemeMode(mode);
  void toggleDarkMode(bool enabled) => _settings.toggleDarkMode(enabled);
  Future<void> setProxyPort(int port) => _settings.setProxyPort(port);
  void setAutoStart(bool v) => _settings.setAutoStart(v);
  void setAutoUpdate(bool v) => _settings.setAutoUpdate(v);
  void setDevMode(bool v) => _settings.setDevMode(v);
  void setLanguage(String v) => _settings.setLanguage(v);
  void setProxyMode(String v) => _settings.setProxyMode(v);
  void setDnsMode(String v) => _settings.setDnsMode(v);

  // ── Core delegates ─────────────────────────────────────────────────────────

  bool get coreRunning => _core.coreRunning;
  bool get coreConnecting => _core.coreConnecting;
  String get coreError => _core.coreError;
  Stream<String> get coreLogStream => _core.logStream;
  Duration get connectedDuration => _core.connectedDuration;

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
  PanelApi get api => _api;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _settings.load();

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

    _core.init();
    _isInitializing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(notifyListeners);
    _core.removeListener(notifyListeners);
    _settings.dispose();
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

  void logout() {
    _core.stopAndReset();
    _isAuthenticated = false;
    _authScreen = AuthScreen.login;
    _subscribeUrl = '';
    _autoSelected = false;
    TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
    _user = MockData.user;
    _traffic = MockData.traffic;
    _currentNode = MockData.currentNode;
    _nodes = MockData.nodes;
    _plans = MockData.plans;
    _inviteCode = MockData.inviteCode;
    _inviteLink = MockData.inviteLink;
    _commissionRate = MockData.commissionRate;
    _invitedCount = MockData.invitedCount;
    _withdrawable = MockData.withdrawable;
    _dailyUsage = MockData.dailyUsage;
    notifyListeners();
  }

  // ── Connection ────────────────────────────────────────────────────────────

  Future<String?> toggleConnection() => _core.toggleConnection(
        nodes: _nodes,
        currentNode: currentNode,
        proxyMode: _settings.proxyMode,
        dnsMode: _settings.dnsMode,
        proxyPort: _settings.proxyPort,
      );

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    final snap = await _dataLoader.loadAll();
    _applySnapshot(snap);
    if (_nodes.isNotEmpty) {
      _currentNode = _nodes.first;
      _autoSelected = true;
      unawaited(testLatencies()); // notifies per node as results arrive
    }
  }

  Future<void> refreshNodes() async {
    final snap = await _dataLoader.loadNodes(_subscribeUrl);
    if (snap.nodes != null && snap.nodes!.isNotEmpty) {
      _nodes = snap.nodes!;
      _currentNode = _nodes.first;
      _autoSelected = true;
      if (snap.traffic != null) _traffic = snap.traffic!;
      unawaited(testLatencies());
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
    if (snap.commissionRate != null) _commissionRate = snap.commissionRate!;
    if (snap.invitedCount != null) _invitedCount = snap.invitedCount!;
    if (snap.withdrawable != null) _withdrawable = snap.withdrawable!;
    if (snap.dailyUsage != null) _dailyUsage = snap.dailyUsage!;
  }

  // ── Node selection ────────────────────────────────────────────────────────

  Future<void> setCurrentNode(NodeModel node) async {
    _autoSelected = false;
    _currentNode = node;
    notifyListeners();
    if (_core.isRunning) {
      await _core.switchNode(node);
    }
  }

  Future<void> selectAuto() async {
    _autoSelected = true;
    final best = _bestNode;
    if (best != null) {
      _currentNode = best;
      notifyListeners();
      if (_core.isRunning) {
        await _core.switchNode(best);
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

  /// Tests latencies for all nodes. Delegates to [CoreController]; updates
  /// node list and notifies on each result.
  Future<void> testLatencies() async {
    if (_nodes.isEmpty) return;
    _nodes = _nodes.map((n) => n.copyWith(latency: -1)).toList();
    notifyListeners();

    final snapshot = List<NodeModel>.from(_nodes);
    await _core.testLatencies(snapshot, onResult: (idx, updated) {
      if (idx < _nodes.length) {
        final list = List<NodeModel>.from(_nodes);
        list[idx] = updated;
        _nodes = list;
        if (_autoSelected) {
          final best = _bestNode;
          if (best != null) _currentNode = best;
        }
        notifyListeners();
      }
    });
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
