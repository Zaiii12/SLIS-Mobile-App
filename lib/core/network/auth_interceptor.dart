import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the stored access token as a Bearer header on every request.
/// On a 401, calls [onUnauthorized] once (single-flight across concurrent
/// 401s) to refresh the access token, then retries the original request.
///
/// Shared across all 4 service Dio clients so the same refresh flow and
/// token source apply everywhere, even though only identity-service issues
/// tokens.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._tokenStorage,
    required this._onUnauthorized,
  });

  final TokenStorage _tokenStorage;
  final Future<String?> Function() _onUnauthorized;

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
      handler.next(err);
      return;
    }

    final requestOptions = err.requestOptions;
    requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    requestOptions.extra['retriedAfterRefresh'] = true;

    try {
      final dio = Dio()
        ..options.baseUrl = requestOptions.baseUrl
        ..options.connectTimeout = requestOptions.connectTimeout
        ..options.receiveTimeout = requestOptions.receiveTimeout;
      final response = await dio.fetch(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refresh() => _onUnauthorized();
}
