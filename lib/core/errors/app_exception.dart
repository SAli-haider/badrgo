import 'dart:convert';
import 'error_code.dart';

/// Unified application exception for badrgo Ops Console.
///
/// Automatically parses:
/// - REST standard error envelope:
///   `{ "error": { "code": "...", "message": "...", "details": ... } }`
/// - 503 Maintenance envelope:
///   `{ "error": { "code": "MAINTENANCE", "message": "...", "details": { "reason", "retryAfterSeconds", "since" } } }`
/// - GraphQL error payload with `extensions.code`.
class AppException implements Exception {
  final ErrorCode code;
  final String message;
  final int? statusCode;
  final dynamic details;
  final int? retryAfterSeconds;

  const AppException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
    this.retryAfterSeconds,
  });

  /// Factory to parse standard badrgo REST responses
  factory AppException.fromRestResponse({
    required int statusCode,
    required dynamic body,
    int? retryAfterHeader,
  }) {
    ErrorCode detectedCode = ErrorCode.unknown;
    String detectedMessage = 'An unexpected error occurred ($statusCode)';
    dynamic detectedDetails;
    int? detectedRetryAfter = retryAfterHeader;

    try {
      dynamic decoded = body;
      if (body is String && body.isNotEmpty) {
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          if (body.contains('XMLHttpRequest') ||
              body.contains('network layer') ||
              body.contains('cross-origin')) {
            detectedCode = ErrorCode.networkError;
            detectedMessage =
                'Unable to reach the badrgo backend server. The sandbox server may be restarting or temporarily offline.';
          } else {
            detectedMessage = body;
          }
        }
      }

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          final errObj = decoded['error'];
          if (errObj is Map<String, dynamic>) {
            detectedCode = ErrorCode.fromString(errObj['code']?.toString());
            detectedMessage = errObj['message']?.toString() ?? detectedMessage;
            detectedDetails = errObj['details'];

            if (detectedDetails is Map<String, dynamic>) {
              if (detectedDetails['retryAfterSeconds'] != null) {
                detectedRetryAfter = int.tryParse(
                      detectedDetails['retryAfterSeconds'].toString(),
                    ) ??
                    detectedRetryAfter;
              }
            }
          } else if (errObj is String) {
            detectedMessage = errObj;
          }
        } else if (decoded.containsKey('message') || decoded.containsKey('code')) {
          detectedCode = ErrorCode.fromString(decoded['code']?.toString());
          detectedMessage = decoded['message']?.toString() ?? detectedMessage;
          detectedDetails = decoded['details'];
        }
      }
    } catch (_) {
      // Body handling fallback
    }

    // Fallback status code mapping if code was not explicitly in JSON body
    if (detectedCode == ErrorCode.unknown) {
      switch (statusCode) {
        case 401:
          detectedCode = ErrorCode.unauthenticated;
          break;
        case 403:
          detectedCode = ErrorCode.forbidden;
          break;
        case 404:
          detectedCode = ErrorCode.notFound;
          break;
        case 409:
          detectedCode = ErrorCode.invalidState;
          break;
        case 422:
          detectedCode = ErrorCode.validationFailed;
          break;
        case 503:
          detectedCode = ErrorCode.maintenance;
          break;
        default:
          detectedCode = ErrorCode.unknown;
      }
    }

    return AppException(
      code: detectedCode,
      message: detectedMessage,
      statusCode: statusCode,
      details: detectedDetails,
      retryAfterSeconds: detectedRetryAfter,
    );
  }

  /// Factory to parse GraphQL error objects
  factory AppException.fromGraphQLError(Map<String, dynamic> error) {
    final message = error['message']?.toString() ?? 'GraphQL query error';
    String? rawCode;
    final extensions = error['extensions'];
    if (extensions is Map<String, dynamic>) {
      rawCode = extensions['code']?.toString();
    }

    return AppException(
      code: ErrorCode.fromString(rawCode),
      message: message,
      details: extensions,
    );
  }

  @override
  String toString() => 'AppException(code: ${code.raw}, message: $message, statusCode: $statusCode)';
}
