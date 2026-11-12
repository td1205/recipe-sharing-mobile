import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    this.tokenStore = const EmptyTokenStore(),
    this.onUnauthorized,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: _dio.options.baseUrl.isEmpty
          ? ApiConfig.baseUrl
          : _dio.options.baseUrl,
      connectTimeout:
          _dio.options.connectTimeout ?? const Duration(seconds: 10),
      receiveTimeout:
          _dio.options.receiveTimeout ?? const Duration(seconds: 15),
      sendTimeout: _dio.options.sendTimeout ?? const Duration(seconds: 10),
      headers: {
        ..._dio.options.headers,
        Headers.acceptHeader: Headers.jsonContentType,
      },
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore tokenStore;
  final Future<void> Function()? onUnauthorized;

  Future<Response<T>> _send<T>(
    Future<Response<T>> Function(Dio dio) action,
  ) async {
    try {
      return await action(_dio);
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      throw _mapDioError(error);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Không thể đọc phản hồi JSON từ máy chủ.',
      );
    }
  }

  Map<String, dynamic> _envelope(Object? data, {int? statusCode}) {
    if (data is! Map) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi từ máy chủ không phải JSON object hợp lệ.',
      );
    }
    final json = Map<String, dynamic>.from(data);
    if (json['success'] == false) {
      throw ApiException(
        ApiErrorKind.invalidResponse,
        _serverMessage(json) ?? 'Yêu cầu không thành công.',
        statusCode: statusCode,
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      (dio) => dio.post<Map<String, dynamic>>(
        path,
        // The backend validates body fields directly, so post raw JSON.
        data: data,
        queryParameters: queryParameters,
      ),
    );
    return _envelope(response.data, statusCode: response.statusCode);
  }

  /// Sends a JSON request while carrying an ephemeral Express session cookie.
  /// Used only by the password-reset flow; callers must keep the cookie in
  /// memory and never persist or log it.
  Future<({Map<String, dynamic> json, String? cookie})> postJsonWithSession(
    String path, {
    Object? data,
    String? cookie,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      (dio) => dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: cookie == null ? null : Options(headers: {'Cookie': cookie}),
      ),
    );
    final json = _envelope(response.data, statusCode: response.statusCode);
    final setCookie = response.headers.value('set-cookie');
    final nextCookie = setCookie?.split(';').first.trim();
    return (
      json: json,
      cookie: nextCookie?.isNotEmpty == true ? nextCookie : cookie,
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _send<Map<String, dynamic>>(
      (dio) => dio.delete<Map<String, dynamic>>(path),
    );
    return _envelope(response.data, statusCode: response.statusCode);
  }

  /// Uploads a single file as multipart/form-data alongside string fields.
  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required MultipartFile file,
    required String fileFieldName,
    Map<String, String?> fields = const {},
    Duration? receiveTimeout,
  }) async {
    final form = FormData();
    form.files.add(MapEntry(fileFieldName, file));
    fields.forEach((key, value) {
      if (value != null) form.fields.add(MapEntry(key, value));
    });
    final response = await _send<Map<String, dynamic>>(
      (dio) => dio.post<Map<String, dynamic>>(
        path,
        data: form,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      ),
    );
    return _envelope(response.data, statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
      if (response.data is! Map) {
        throw const ApiException(
          ApiErrorKind.invalidResponse,
          'Phản hồi từ máy chủ không phải JSON object hợp lệ.',
        );
      }
      final json = Map<String, dynamic>.from(response.data! as Map);
      if (json['success'] == false) {
        throw ApiException(
          ApiErrorKind.invalidResponse,
          _serverMessage(json) ?? 'Yêu cầu không thành công.',
          statusCode: response.statusCode,
        );
      }
      return json;
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      throw _mapDioError(error);
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Không thể đọc phản hồi JSON từ máy chủ.',
      );
    }
  }

  Future<void> _handleUnauthorized(DioException error) async {
    if (error.response?.statusCode != 401) return;
    await tokenStore.deleteAccessToken();
    await onUnauthorized?.call();
  }

  static ApiException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        ApiErrorKind.timeout,
        'Kết nối đã quá thời gian chờ.',
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(
        ApiErrorKind.network,
        'Không thể kết nối đến máy chủ.',
      );
    }
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final message = body is Map
        ? _serverMessage(Map<String, dynamic>.from(body))
        : null;
    final json = body is Map ? Map<String, dynamic>.from(body) : null;
    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      int value when value >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    return ApiException(
      kind,
      message ??
          (status == null
              ? 'Đã xảy ra lỗi không xác định.'
              : 'Máy chủ trả về lỗi HTTP $status.'),
      statusCode: status,
      code: json?['code'] is String ? json!['code'] as String : null,
      retryAfterSeconds: json?['retryAfterSeconds'] is num
          ? (json!['retryAfterSeconds'] as num).toInt()
          : null,
    );
  }

  static String? _serverMessage(Map<String, dynamic> json) {
    final value = json['message'] ?? json['error'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }
}
