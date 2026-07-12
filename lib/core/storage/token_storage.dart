import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure (Keychain/Keystore) storage for auth tokens. Never use
/// SharedPreferences for these values.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _userNameKey = 'user_name';

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Per the RBAC handoff: role comes only from `user.role` in the login
  /// response (the JWT carries `user_id`, never role), so it must be cached
  /// here at login and refreshed via a manual re-fetch, not decoded from the
  /// token.
  Future<void> saveUser({
    required String id,
    required String role,
    required String name,
  }) async {
    await _storage.write(key: _userIdKey, value: id);
    await _storage.write(key: _userRoleKey, value: role);
    await _storage.write(key: _userNameKey, value: name);
  }

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<String?> readUserRole() => _storage.read(key: _userRoleKey);

  Future<String?> readUserName() => _storage.read(key: _userNameKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _userNameKey);
  }
}
