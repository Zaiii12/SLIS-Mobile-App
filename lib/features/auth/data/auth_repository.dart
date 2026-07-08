import '../../../core/storage/token_storage.dart';
import '../models/user.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository({required this._authApi, required this._tokenStorage});

  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  Future<User> login({required String identifier, required String password}) async {
    final result = await _authApi.login(identifier: identifier, password: password);
    await _tokenStorage.saveTokens(accessToken: result.accessToken);
    return result.user;
  }

  Future<String?> refreshAccessToken() async {
    final newToken = await _authApi.refresh();
    if (newToken != null) {
      await _tokenStorage.saveAccessToken(newToken);
    }
    return newToken;
  }

  /// True if a stored access token exists. This is presence-only and does
  /// not confirm the token is still valid; use [restoreSession] to validate
  /// against the backend before trusting it.
  Future<bool> hasStoredSession() async {
    final token = await _tokenStorage.readAccessToken();
    return token != null;
  }

  /// Validates a stored session by attempting a token refresh. No `/me/`
  /// endpoint is confirmed yet, so refresh doubles as the validity check:
  /// the identity-service rejects it if the underlying refresh token
  /// (httpOnly cookie) is expired or missing.
  Future<bool> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) return false;
    final newToken = await refreshAccessToken();
    return newToken != null;
  }

  Future<void> logout() async {
    await _authApi.logout();
    await _tokenStorage.clear();
  }
}
