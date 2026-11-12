import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_sharing_mobile/core/auth/token_store.dart';
import 'package:recipe_sharing_mobile/core/network/api_client.dart';
import 'package:recipe_sharing_mobile/core/network/api_exception.dart';

class _TokenStore extends EmptyTokenStore {
  const _TokenStore(this.token);
  final String? token;
  @override
  Future<String?> readAccessToken() async => token;
}

class _MutableTokenStore implements TokenStore {
  _MutableTokenStore(this.token);
  String? token;

  @override
  Future<void> deleteAccessToken() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String token) async => this.token = token;
}

void main() {
  Dio dioWithHandler(
    void Function(RequestOptions, RequestInterceptorHandler) handler,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: handler));
    return dio;
  }

  test('returns JSON and adds Bearer token', () async {
    String? authorization;
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    final client = ApiClient(dio: dio, tokenStore: const _TokenStore('abc'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          authorization = options.headers['Authorization'] as String?;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'recipes': <Object>[]},
            ),
          );
        },
      ),
    );
    final result = await client.getJson('/api/recipes');
    expect(result['success'], isTrue);
    expect(authorization, 'Bearer abc');
  });

  test('maps HTTP status and backend message', () async {
    final dio = dioWithHandler((options, handler) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: {'success': false, 'error': 'Token hết hạn'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    });
    await expectLater(
      ApiClient(dio: dio).getJson('/private'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
            .having((e) => e.message, 'message', 'Token hết hạn'),
      ),
    );
  });

  test('401 clears the token and notifies the auth boundary', () async {
    final store = _MutableTokenStore('expired-token');
    var notified = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    final client = ApiClient(
      dio: dio,
      tokenStore: store,
      onUnauthorized: () async => notified = true,
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'success': false, 'error': 'Phiên đã hết hạn'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    await expectLater(
      client.getJson('/private'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(store.token, isNull);
    expect(notified, isTrue);
  });

  test('maps timeout', () async {
    final dio = dioWithHandler((options, handler) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
    });
    await expectLater(
      ApiClient(dio: dio).getJson('/slow'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
      ),
    );
  });

  test('maps connection failure', () async {
    final dio = dioWithHandler((options, handler) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );
    });
    await expectLater(
      ApiClient(dio: dio).getJson('/offline'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );
  });

  test('preserves AI error code and retry delay', () async {
    final dio = dioWithHandler((options, handler) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 429,
            data: {
              'success': false,
              'code': 'QUOTA_EXCEEDED',
              'error': 'Hạn mức nhận diện hình ảnh đã hết.',
              'retryAfterSeconds': 125,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    });

    await expectLater(
      ApiClient(dio: dio).getJson('/api/ai/scan-image'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having((error) => error.code, 'code', 'QUOTA_EXCEEDED')
            .having(
              (error) => error.retryAfterSeconds,
              'retryAfterSeconds',
              125,
            ),
      ),
    );
  });

  test(
    'carries an ephemeral Express session cookie between requests',
    () async {
      String? sentCookie;
      var requestCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            sentCookie = options.headers['Cookie'] as String?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                headers: requestCount == 1
                    ? Headers.fromMap({
                        'set-cookie': [
                          'connect.sid=signed-session; Path=/; HttpOnly',
                        ],
                      })
                    : Headers(),
                data: const {'success': true},
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);

      final first = await client.postJsonWithSession('/forgot-password');
      expect(first.cookie, 'connect.sid=signed-session');
      await client.postJsonWithSession('/otp', cookie: first.cookie);
      expect(sentCookie, 'connect.sid=signed-session');
    },
  );

  test('rejects non-object JSON response', () async {
    final dio = dioWithHandler((options, handler) {
      handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: <Object>[]),
      );
    });
    await expectLater(
      ApiClient(dio: dio).getJson('/invalid'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
