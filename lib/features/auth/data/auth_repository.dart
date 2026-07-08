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

  /// True if a stored access token exists, meaning the app can attempt to
  /// restore a session without showing the login screen first. This pass
  /// doesn't re-fetch the user profile on restore (no `/me/` endpoint was
  /// confirmed) so the caller should treat the restored session as
  /// "authenticated" without a fresh User until one logs in again.
  Future<bool> hasStoredSession() async {
    final token = await _tokenStorage.readAccessToken();
    return token != null;
  }

  Future<void> logout() async {
    await _authApi.logout();
    await _tokenStorage.clear();
  }
}
