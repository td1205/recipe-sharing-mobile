enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  const ApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.code,
    this.retryAfterSeconds,
  });
  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}
