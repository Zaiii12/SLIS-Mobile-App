import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the stored access token as a Bearer header on every request.
/// On a 401, calls [onUnauthorized] once (single-flight across concurrent
/// 401s) to refresh the access token, then retries the original request
/// through [_dio] — the same client instance that issued it, so the retried
/// request keeps that client's interceptors (this one) and, for
/// identity-service, its cookie jar (needed for the httpOnly refresh
/// cookie). One instance is constructed per service client in
/// [DioClientFactory] (all sharing the same [TokenStorage]/[onUnauthorized]),
/// rather than one instance shared across clients, specifically so each can
/// hold this back-reference.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required Future<String?> Function() onUnauthorized,
    required void Function() onSessionExpired,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Future<String?> Function() _onUnauthorized;
  final void Function() _onSessionExpired;

  Future<String?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retriedAfterRefresh'] == true;

    if (!isUnauthorized || alreadyRetried) {
      handler.next(err);
      return;
    }

    final newAccessToken = await (_refreshInFlight ??= _refresh());
    _refreshInFlight = null;

    if (newAccessToken == null) {
      // Refresh failed — most commonly because this session was superseded
      // by a login elsewhere (single-session-per-platform enforcement) or
      // the refresh token expired. Either way, the stored token is no
      // longer usable, so force the user back to the login screen instead
      // of leaving them stuck on a screen that will keep 401ing silently.
      _onSessionExpired();
      handler.next(err);
      return;
    }

    final requestOptions = err.requestOptions;
    requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    requestOptions.extra['retriedAfterRefresh'] = true;

    try {
      final response = await _dio.fetch(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refresh() => _onUnauthorized();
}
