import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Builds the 4 independent [Dio] clients ASIA's services require (there is
/// no API gateway). Each gets its own [AuthInterceptor] instance (sharing
/// the same [TokenStorage]/`onUnauthorized` callback) so a 401-triggered
/// retry replays through that same client — keeping its cookie jar (for
/// identity-service) and interceptor chain intact — rather than a bare `Dio()`
/// that would silently drop both.
///
/// Only the identity-service client carries a cookie jar: identity-service's
/// refresh endpoint reads the refresh token from an httpOnly cookie (a
/// browser convention), so the cookie jar transparently captures it on login
/// and replays it on refresh without any backend change.
class DioClientFactory {
  DioClientFactory({
    required TokenStorage tokenStorage,
    required Future<String?> Function() onUnauthorized,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized;

  final TokenStorage _tokenStorage;
  final Future<String?> Function() _onUnauthorized;
  final CookieJar _identityCookieJar = CookieJar();

  late final Dio identity = _build(ApiConfig.identityBaseUrl, withCookies: true);
  late final Dio student = _build(ApiConfig.studentBaseUrl);
  late final Dio enrollment = _build(ApiConfig.enrollmentBaseUrl);
  late final Dio billing = _build(ApiConfig.billingBaseUrl);

  Dio _build(String baseUrl, {bool withCookies = false}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    if (withCookies) {
      dio.interceptors.add(CookieManager(_identityCookieJar));
    }
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      tokenStorage: _tokenStorage,
      onUnauthorized: _onUnauthorized,
    ));
    return dio;
  }
}
