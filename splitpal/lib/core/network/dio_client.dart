import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../utils/token_manager.dart';

class DioClient {
  late final Dio _dio;
  final TokenManager _tokenManager;

  DioClient({required TokenManager tokenManager})
      : _tokenManager = tokenManager {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        headers: ApiConstants.defaultHeaders,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_errorInterceptor());
  }

  Dio get dio => _dio;

  // Auth Interceptor - Add token to requests
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get token from secure storage
        final token = await _tokenManager.getToken();

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
    );
  }

  // Error Interceptor - Auto-refresh on 401, handle common errors
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !_isAuthPath(error.requestOptions.path)) {
          // Attempt to refresh the access token
          final refreshToken = await _tokenManager.getRefreshToken();
          if (refreshToken != null) {
            try {
              // Use a separate Dio instance to avoid interceptor recursion
              final refreshDio = Dio(BaseOptions(
                baseUrl: ApiConstants.apiBaseUrl,
                connectTimeout: AppConstants.connectionTimeout,
              ));
              final resp = await refreshDio.post(
                '/auth/refresh-token',
                data: {'refreshToken': refreshToken},
              );

              final data = resp.data['data'];
              if (data != null) {
                final newAccessToken = data['token'] as String;
                final newRefreshToken = data['refreshToken'] as String;

                // Persist new tokens
                await _tokenManager.saveToken(newAccessToken);
                await _tokenManager.saveRefreshToken(newRefreshToken);

                // Retry the original request with the new access token
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                final retryResp = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResp);
              }
            } catch (_) {
              // Refresh failed — fall through to clear session
            }
          }

          // No refresh token or refresh failed → force logout
          await _tokenManager.clearAll();
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: UnauthorizedException(
                message: 'Session expired. Please login again.',
              ),
            ),
          );
        } else {
          handler.next(error);
        }
      },
    );
  }

  /// Paths that should NOT trigger an auto-refresh attempt.
  bool _isAuthPath(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/signup') ||
        path.contains('/auth/refresh-token');
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Handle Dio errors and convert to custom exceptions
  Exception _handleDioError(DioException error) {
    // Dev logging to track real root cause
    debugPrint('[HTTP] ${error.type} | status=${error.response?.statusCode} | msg=${error.message} | err=${error.error}');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(message: 'Káº¿t ná»‘i quÃ¡ thá»i gian. Vui lÃ²ng thá»­ láº¡i.');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        String message = 'Lá»—i mÃ¡y chá»§';
        final data = error.response?.data;
        
        if (data is Map<String, dynamic>) {
          if (data['error'] is String) {
            message = data['error'];
          } else if (data['error'] is Map && data['error']['message'] != null) {
            message = data['error']['message'];
          } else if (data['message'] != null) {
            message = data['message'];
          }
        }

        if (statusCode == 401) {
          return UnauthorizedException(message: message);
        } else if (statusCode == 404) {
          return NotFoundException(message: message);
        } else if (statusCode == 400) {
          return ValidationException(
            message: message,
            errors: error.response?.data?['error']?['details'],
          );
        } else {
          return ServerException(
            message: message,
            statusCode: statusCode,
          );
        }

      case DioExceptionType.cancel:
        return NetworkException(message: 'Request cancelled');

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        final underlying = error.error;
        if (underlying is UnauthorizedException) return underlying;
        if (underlying is ValidationException) return underlying;
        if (underlying is SocketException) {
          return NetworkException(
            message: 'KhÃ´ng thá»ƒ káº¿t ná»‘i tá»›i mÃ¡y chá»§. Kiá»ƒm tra API_BASE_URL hoáº·c máº¡ng ná»™i bá»™.',
          );
        }
        if (underlying is HandshakeException) {
          return NetworkException(
            message: 'Káº¿t ná»‘i báº£o máº­t tháº¥t báº¡i (SSL). Kiá»ƒm tra chá»©ng chá»‰ mÃ¡y chá»§.',
          );
        }
        return NetworkException(
          message: 'KhÃ´ng thá»ƒ káº¿t ná»‘i. Vui lÃ²ng kiá»ƒm tra máº¡ng hoáº·c Ä‘á»‹a chá»‰ mÃ¡y chá»§.',
        );

      default:
        return ServerException(
          message: 'Lá»—i khÃ´ng xÃ¡c Ä‘á»‹nh',
        );
    }
  }
}
