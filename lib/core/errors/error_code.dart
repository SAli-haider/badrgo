/// Standardized error codes explicitly specified in requirements:
/// `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `INVALID_STATE`,
/// `VALIDATION_FAILED`, and `MAINTENANCE`.
enum ErrorCode {
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  invalidState('INVALID_STATE'),
  validationFailed('VALIDATION_FAILED'),
  maintenance('MAINTENANCE'),
  networkError('NETWORK_ERROR'),
  unknown('UNKNOWN');

  final String raw;
  const ErrorCode(this.raw);

  static ErrorCode fromString(String? code) {
    if (code == null) return ErrorCode.unknown;
    final upper = code.trim().toUpperCase();
    for (final value in ErrorCode.values) {
      if (value.raw == upper) {
        return value;
      }
    }
    return ErrorCode.unknown;
  }
}
