import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../errors/error_code.dart';
import 'api_result.dart';
import 'network_event_bus.dart';

/// Clean REST client powered by Dio adhering to:
/// "Sign-in and sign-out, GET /api/me, and every write:
/// create, assign, cancel, refund, acknowledge, user management"
class RestClient {
  final Dio _dio;
  final NetworkEventBus? _eventBus;
  String? _authToken;

  RestClient({
    Dio? dio,
    NetworkEventBus? eventBus,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ),
        _eventBus = eventBus {
    _setupInterceptors();
  }

  Dio get dio => _dio;

  void updateToken(String? token) {
    _authToken = token;
  }

  String? get currentToken => _authToken;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null && _authToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          final statusCode = error.response?.statusCode ?? 500;
          final responseData = error.response?.data;

          int? retryAfter;
          final retryHeader = error.response?.headers.value('retry-after');
          if (retryHeader != null) {
            retryAfter = int.tryParse(retryHeader);
          }

          final appException = AppException.fromRestResponse(
            statusCode: statusCode,
            body: responseData ?? error.message ?? '',
            retryAfterHeader: retryAfter,
          );

          if (appException.code == ErrorCode.unauthenticated) {
            _eventBus?.onUnauthorized(appException);
          } else if (appException.code == ErrorCode.maintenance) {
            _eventBus?.onMaintenance(appException);
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) async {
    return _execute(
      () => _dio.get(path, queryParameters: queryParameters, options: options),
      fromJson: fromJson,
    );
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) async {
    return _execute(
      () => _dio.post(path, data: body, queryParameters: queryParameters, options: options),
      fromJson: fromJson,
    );
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) async {
    return _execute(
      () => _dio.put(path, data: body, queryParameters: queryParameters, options: options),
      fromJson: fromJson,
    );
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) async {
    return _execute(
      () => _dio.delete(path, data: body, queryParameters: queryParameters, options: options),
      fromJson: fromJson,
    );
  }

  Future<ApiResult<T>> _execute<T>(
    Future<Response> Function() request, {
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final response = await request();
      final data = response.data;

      if (fromJson != null) {
        return ApiSuccess<T>(fromJson(data));
      }
      return ApiSuccess<T>(data as T);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.response == null) {
        final exception = AppException(
          code: ErrorCode.networkError,
          message:
              'Unable to reach the badrgo backend server. The sandbox server may be restarting or temporarily offline.',
          statusCode: 503,
        );
        return ApiFailure<T>(exception);
      }

      final statusCode = e.response?.statusCode ?? 500;
      final responseData = e.response?.data;

      int? retryAfter;
      final retryHeader = e.response?.headers.value('retry-after');
      if (retryHeader != null) {
        retryAfter = int.tryParse(retryHeader);
      }

      final exception = AppException.fromRestResponse(
        statusCode: statusCode,
        body: responseData ?? e.message ?? '',
        retryAfterHeader: retryAfter,
      );
      return ApiFailure<T>(exception);
    } catch (e) {
      return ApiFailure<T>(
        AppException(
          code: ErrorCode.networkError,
          message: e.toString(),
        ),
      );
    }
  }
}
