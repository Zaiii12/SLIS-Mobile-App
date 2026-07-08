import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Builds the 4 independent [Dio] clients ASIA's services require (there is
/// no API gateway). All share one [AuthInterceptor] instance so token
/// attachment and refresh-on-401 behave identically everywhere.
///
/// Only the identity-service client carries a cookie jar: identity-service's
/// refresh endpoint reads the refresh token from an httpOnly cookie (a
/// browser convention), so the cookie jar transparently captures it on login
/// and replays it on refresh without any backend change.
class DioClientFactory {
  DioClientFactory({
    required TokenStorage tokenStorage,
    required Future<String?> Function() onUnauthorized,
  }) : _authInterceptor = AuthInterceptor(
          tokenStorage: tokenStorage,
          onUnauthorized: onUnauthorized,
        );

  final AuthInterceptor _authInterceptor;
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
    dio.interceptors.add(_authInterceptor);
    return dio;
  }
}
