import 'package:dio/dio.dart';

import '../models/user.dart';

class AuthResult {
  const AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final User user;
}

/// Calls against identity-service's `/api/auth/` endpoints. This is the only
/// service that issues JWTs; the other 3 services validate them statelessly.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> login({
    required String identifier,
    required String password,
    bool rememberMe = true,
  }) async {
    final response = await _dio.post(
      '/api/auth/login/',
      data: {
        'identifier': identifier,
        'password': password,
        'remember_me': rememberMe,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return AuthResult(
      accessToken: data['access'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  /// Refreshes the access token. The refresh token itself is never sent
  /// explicitly here — it travels as an httpOnly cookie captured by the
  /// identity-service Dio client's cookie jar (see DioClientFactory).
  Future<String?> refresh() async {
    try {
      final response = await _dio.post('/api/auth/refresh/');
      final data = response.data as Map<String, dynamic>;
      return data['access'] as String?;
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout/');
    } on DioException {
      // Best-effort: proceed with clearing local state regardless.
    }
  }

  /// Re-fetches the user profile, including current role. Per the RBAC
  /// handoff, role can change server-side mid-session, so this is the only
  /// way to pick that up short of a fresh login.
  Future<User> fetchUser(String id) async {
    final response = await _dio.get('/api/auth/users/$id/');
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}
