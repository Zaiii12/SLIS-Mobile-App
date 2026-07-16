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
    await _tokenStorage.saveUser(
      id: result.user.id,
      role: result.user.role,
      name: result.user.name,
    );
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

  /// Validates a stored session by refreshing the access token, then
  /// re-fetches the user profile via `GET /api/auth/users/<id>/` so role is
  /// current as of this cold start (per the RBAC handoff: role can drift
  /// server-side mid-session and only a re-fetch picks that up). Returns
  /// null if the session can't be restored.
  Future<User?> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) return null;

    final newToken = await refreshAccessToken();
    if (newToken == null) return null;

    final userId = await _tokenStorage.readUserId();
    if (userId == null) return null;

    try {
      final user = await _authApi.fetchUser(userId);
      await _tokenStorage.saveUser(id: user.id, role: user.role, name: user.name);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _authApi.logout();
    await _tokenStorage.clear();
  }

  /// Clears stored tokens/user without calling `/api/auth/logout/` — for use
  /// when the backend has already invalidated the session server-side (e.g.
  /// superseded by another login), so that call would just fail with 401.
  Future<void> clearLocalSession() async {
    await _tokenStorage.clear();
  }
}
