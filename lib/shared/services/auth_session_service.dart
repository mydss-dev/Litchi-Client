import '../models/api_models.dart';
import 'api_client.dart';
import 'credentials_storage.dart';
import 'panel_api.dart';
import 'token_storage.dart';

class AuthSessionService {
  const AuthSessionService(this._apiClient, this._api);

  final ApiClient _apiClient;
  final PanelApi _api;

  Future<String?> restoreSavedAuthData() async {
    final authData = await TokenStorage.getAuthData();
    if (authData == null || authData.isEmpty) return null;
    _apiClient.updateAuthData(authData);
    return authData;
  }

  Future<void> applyAuthData(String authData) async {
    await TokenStorage.saveAuthData(authData);
    _apiClient.updateAuthData(authData);
  }

  Future<AuthResult?> loginFromSavedCredentials() async {
    final saved = await CredentialsStorage.load();
    if (saved == null) return null;
    final result = await _api.login(saved.email, saved.password);
    await applyAuthData(result.authData);
    return result;
  }

  Future<void> clear() async {
    await TokenStorage.clearAuthData();
    _apiClient.updateAuthData(null);
  }
}
