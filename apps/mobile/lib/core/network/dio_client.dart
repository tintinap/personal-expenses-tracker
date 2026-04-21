import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PRD §8 — Dio HTTP client with JWT interceptor and retry logic
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    // TODO: Configure from .env
    baseUrl: 'http://localhost:3000',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(responseBody: false));

  return dio;
});

/// JWT auth interceptor that adds Bearer token and handles refresh
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          final dio = Dio(BaseOptions(
            baseUrl: err.requestOptions.baseUrl,
          ));
          final response = await dio.post('/auth/refresh', data: {
            'refreshToken': refreshToken,
          });

          final newAccessToken = response.data['accessToken'];
          final newRefreshToken = response.data['refreshToken'];

          await _storage.write(key: 'access_token', value: newAccessToken);
          await _storage.write(key: 'refresh_token', value: newRefreshToken);

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] =
              'Bearer $newAccessToken';
          final retryResponse = await Dio().fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          // Refresh failed — clear tokens, user needs to re-auth
          await _storage.deleteAll();
        }
      }
    }
    handler.next(err);
  }
}
