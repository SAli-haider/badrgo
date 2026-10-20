import '../errors/app_exception.dart';

/// Lightweight and type-safe Result wrapper for network and repository calls.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get dataOrNull => switch (this) {
        ApiSuccess<T>(data: final d) => d,
        ApiFailure<T>() => null,
      };

  AppException? get exceptionOrNull => switch (this) {
        ApiSuccess<T>() => null,
        ApiFailure<T>(exception: final e) => e,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(data: final d) => success(d),
      ApiFailure<T>(exception: final e) => failure(e),
    };
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final AppException exception;
  const ApiFailure(this.exception);
}
