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

  // Error Interceptor - Handle common errors
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !(error.requestOptions.path.contains('/auth/login') || error.requestOptions.path.contains('/auth/signup'))) {
          // Token expired or invalid - logout user
          await _tokenManager.clearAll();
          // You might want to navigate to login page here
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
  }) async {
    try {
      final response = await _dio.post(
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
        return TimeoutException(message: 'Kết nối quá thời gian. Vui lòng thử lại.');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        String message = 'Lỗi máy chủ';
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
            message: 'Không thể kết nối tới máy chủ. Kiểm tra API_BASE_URL hoặc mạng nội bộ.',
          );
        }
        if (underlying is HandshakeException) {
          return NetworkException(
            message: 'Kết nối bảo mật thất bại (SSL). Kiểm tra chứng chỉ máy chủ.',
          );
        }
        return NetworkException(
          message: 'Không thể kết nối. Vui lòng kiểm tra mạng hoặc địa chỉ máy chủ.',
        );

      default:
        return ServerException(
          message: 'Lỗi không xác định',
        );
    }
  }
}
