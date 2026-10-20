import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../errors/error_code.dart';
import 'api_result.dart';
import 'network_event_bus.dart';

/// Lightweight and reliable GraphQL Client powered by Dio.
///
/// Adhering to:
/// "GraphQL: Dashboard KPIs and charts, the trip list and trip detail
/// (nested rider, driver and city in one query)"
/// "GraphQL errors carry extensions.code. Handle UNAUTHENTICATED,
/// FORBIDDEN, NOT_FOUND, INVALID_STATE and VALIDATION_FAILED."
class GraphQLClient {
  final Dio _dio;
  final NetworkEventBus? _eventBus;
  String? _authToken;

  GraphQLClient({
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
        _eventBus = eventBus;

  void updateToken(String? token) {
    _authToken = token;
  }

  Future<ApiResult<T>> query<T>({
    required String document,
    Map<String, dynamic>? variables,
    required T Function(Map<String, dynamic> data) fromData,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final payload = {
        'query': document,
        if (variables != null) ...{'variables': variables},
      };

      final response = await _dio.post(
        AppConfig.graphqlEndpoint,
        data: payload,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final statusCode = response.statusCode ?? 500;
      final dynamic responseData = response.data;

      if (statusCode == 503) {
        int? retryAfter;
        final retryHeader = response.headers.value('retry-after');
        if (retryHeader != null) {
          retryAfter = int.tryParse(retryHeader);
        }
        final exception = AppException.fromRestResponse(
          statusCode: statusCode,
          body: responseData,
          retryAfterHeader: retryAfter,
        );
        _eventBus?.onMaintenance(exception);
        return ApiFailure<T>(exception);
      }

      if (statusCode == 401) {
        final exception = AppException(
          code: ErrorCode.unauthenticated,
          message: 'Session expired or invalid',
          statusCode: 401,
        );
        _eventBus?.onUnauthorized(exception);
        return ApiFailure<T>(exception);
      }

      if (responseData is! Map<String, dynamic>) {
        final exception = AppException(
          code: ErrorCode.unknown,
          message: 'Invalid GraphQL response format',
          statusCode: statusCode,
        );
        return ApiFailure<T>(exception);
      }

      // Check for GraphQL errors
      if (responseData.containsKey('errors') && responseData['errors'] is List) {
        final errorsList = responseData['errors'] as List;
        if (errorsList.isNotEmpty) {
          final firstError = errorsList.first as Map<String, dynamic>;
          final exception = AppException.fromGraphQLError(firstError);

          if (exception.code == ErrorCode.unauthenticated) {
            _eventBus?.onUnauthorized(exception);
          } else if (exception.code == ErrorCode.maintenance) {
            _eventBus?.onMaintenance(exception);
          }

          return ApiFailure<T>(exception);
        }
      }

      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return ApiSuccess<T>(fromData(data));
      }

      return ApiSuccess<T>(fromData({}));
    } on AppException catch (e) {
      return ApiFailure<T>(e);
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
