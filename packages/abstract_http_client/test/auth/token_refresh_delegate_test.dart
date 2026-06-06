import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(method: HttpMethod.get, path: '/test');

  group('TokenRefreshMode', () {
    test('should have two modes', () {
      expect(TokenRefreshMode.values.length, 2);
      expect(TokenRefreshMode.reusePrimaryClient, isNotNull);
      expect(TokenRefreshMode.separateClient, isNotNull);
    });
  });

  group('TokenRefreshConfig', () {
    test('should create with default values', () {
      const config = TokenRefreshConfig(refreshEndpoint: '/auth/refresh');

      expect(config.refreshEndpoint, '/auth/refresh');
      expect(config.mode, TokenRefreshMode.reusePrimaryClient);
      expect(config.refreshClientBuilder, isNull);
      expect(config.shouldRefresh, isNotNull);
      expect(config.onTokenRefreshed, isNull);
      expect(config.onForceLogout, isNull);
      expect(config.accessTokenKey, 'access_token');
      expect(config.refreshTokenKey, 'refresh_token');
      expect(config.refreshBeforeExpiry, const Duration(minutes: 1));
    });

    test('should create with custom values', () {
      void onRefreshed(TokenPair tokens) {}
      void onLogout() {}

      final config = TokenRefreshConfig(
        refreshEndpoint: '/api/v2/refresh',
        mode: TokenRefreshMode.separateClient,
        shouldRefresh: TokenRefreshConfig.shouldRefreshOn401Or403,
        onTokenRefreshed: onRefreshed,
        onForceLogout: onLogout,
        accessTokenKey: 'token',
        refreshTokenKey: 'refresh',
        refreshBeforeExpiry: const Duration(minutes: 5),
      );

      expect(config.refreshEndpoint, '/api/v2/refresh');
      expect(config.mode, TokenRefreshMode.separateClient);
      expect(config.accessTokenKey, 'token');
      expect(config.refreshTokenKey, 'refresh');
      expect(config.refreshBeforeExpiry, const Duration(minutes: 5));
    });

    group('copyWith', () {
      test('should create copy with no changes', () {
        const original = TokenRefreshConfig(
          refreshEndpoint: '/auth/refresh',
          accessTokenKey: 'token',
        );

        final copy = original.copyWith();

        expect(copy.refreshEndpoint, original.refreshEndpoint);
        expect(copy.accessTokenKey, original.accessTokenKey);
        expect(copy.mode, original.mode);
      });

      test('should create copy with changed values', () {
        const original = TokenRefreshConfig(
          refreshEndpoint: '/auth/refresh',
        );

        final copy = original.copyWith(
          refreshEndpoint: '/api/refresh',
          mode: TokenRefreshMode.separateClient,
        );

        expect(copy.refreshEndpoint, '/api/refresh');
        expect(copy.mode, TokenRefreshMode.separateClient);
        expect(copy.accessTokenKey, original.accessTokenKey);
      });
    });

    group('shouldRefresh strategies', () {
      test('shouldRefreshOn401 should trigger on 401', () {
        final error401 = HttpError(
          type: HttpErrorType.unauthorized,
          request: testRequest,
          response: const HttpResponse(statusCode: 401, request: testRequest),
        );

        final error403 = HttpError(
          type: HttpErrorType.forbidden,
          request: testRequest,
          response: const HttpResponse(statusCode: 403, request: testRequest),
        );

        expect(TokenRefreshConfig.shouldRefreshOn401(error401), isTrue);
        expect(TokenRefreshConfig.shouldRefreshOn401(error403), isFalse);
      });

      test('shouldRefreshOn401Or403 should trigger on 401 or 403', () {
        final error401 = HttpError(
          type: HttpErrorType.unauthorized,
          request: testRequest,
          response: const HttpResponse(statusCode: 401, request: testRequest),
        );

        final error403 = HttpError(
          type: HttpErrorType.forbidden,
          request: testRequest,
          response: const HttpResponse(statusCode: 403, request: testRequest),
        );

        final error500 = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
          response: const HttpResponse(statusCode: 500, request: testRequest),
        );

        expect(TokenRefreshConfig.shouldRefreshOn401Or403(error401), isTrue);
        expect(TokenRefreshConfig.shouldRefreshOn401Or403(error403), isTrue);
        expect(TokenRefreshConfig.shouldRefreshOn401Or403(error500), isFalse);
      });

      test('shouldRefreshOnStatusCodes should trigger on specified codes', () {
        final strategy =
            TokenRefreshConfig.shouldRefreshOnStatusCodes({401, 403, 419});

        final error401 = HttpError(
          type: HttpErrorType.unauthorized,
          request: testRequest,
          response: const HttpResponse(statusCode: 401, request: testRequest),
        );

        final error419 = HttpError(
          type: HttpErrorType.badResponse,
          request: testRequest,
          response: const HttpResponse(statusCode: 419, request: testRequest),
        );

        final error500 = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
          response: const HttpResponse(statusCode: 500, request: testRequest),
        );

        expect(strategy(error401), isTrue);
        expect(strategy(error419), isTrue);
        expect(strategy(error500), isFalse);
      });

      test('shouldRefreshOnErrorTypes should trigger on specified types', () {
        final strategy = TokenRefreshConfig.shouldRefreshOnErrorTypes({
          HttpErrorType.unauthorized,
          HttpErrorType.forbidden,
        });

        final errorUnauth = HttpError(
          type: HttpErrorType.unauthorized,
          request: testRequest,
        );

        final errorForbidden = HttpError(
          type: HttpErrorType.forbidden,
          request: testRequest,
        );

        final errorServer = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
        );

        expect(strategy(errorUnauth), isTrue);
        expect(strategy(errorForbidden), isTrue);
        expect(strategy(errorServer), isFalse);
      });
    });

    test('default shouldRefresh should trigger on 401', () {
      const config = TokenRefreshConfig(refreshEndpoint: '/auth/refresh');

      final error401 = HttpError(
        type: HttpErrorType.unauthorized,
        request: testRequest,
        response: const HttpResponse(statusCode: 401, request: testRequest),
      );

      final error500 = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
        response: const HttpResponse(statusCode: 500, request: testRequest),
      );

      expect(config.shouldRefresh(error401), isTrue);
      expect(config.shouldRefresh(error500), isFalse);
    });
  });

  group('TokenRefreshContext', () {
    test('should create with required fields', () {
      final tokens = TokenPair(accessToken: 'access', refreshToken: 'refresh');
      final client = _MockHttpClient();

      final context = TokenRefreshContext(
        currentTokens: tokens,
        client: client,
      );

      expect(context.currentTokens, tokens);
      expect(context.client, client);
      expect(context.cancelToken, isNull);
    });

    test('should create with cancel token', () {
      final tokens = TokenPair(accessToken: 'access');
      final client = _MockHttpClient();
      final cancelToken = CancelToken();

      final context = TokenRefreshContext(
        currentTokens: tokens,
        client: client,
        cancelToken: cancelToken,
      );

      expect(context.cancelToken, cancelToken);
    });

    test('should allow null currentTokens', () {
      final client = _MockHttpClient();

      final context = TokenRefreshContext(
        currentTokens: null,
        client: client,
      );

      expect(context.currentTokens, isNull);
    });
  });
}

class _MockHttpClient implements HttpClient {
  @override
  HttpClientConfig get config => const HttpClientConfig();

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> post<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> put<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> patch<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> delete<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> head<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse<T>> options<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }
}
