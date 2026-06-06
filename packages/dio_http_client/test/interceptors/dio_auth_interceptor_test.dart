import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_client/src/interceptors/dio_auth_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('DioAuthInterceptor', () {
    late InMemoryTokenStore tokenStore;
    late DioAuthInterceptor interceptor;

    setUp(() {
      tokenStore = InMemoryTokenStore();
      interceptor = DioAuthInterceptor(tokenStore: tokenStore);
    });

    test('should add Authorization header when tokens exist', () async {
      await tokenStore.saveTokens(const TokenPair(accessToken: 'test_token'));

      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.options!.headers['Authorization'], 'Bearer test_token');
    });

    test('should not add header when no tokens', () async {
      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.options!.headers['Authorization'], isNull);
    });

    test('should not add header when token is empty', () async {
      await tokenStore.saveTokens(const TokenPair(accessToken: ''));

      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.options!.headers['Authorization'], isNull);
    });

    test('should not overwrite existing Authorization header', () async {
      await tokenStore.saveTokens(const TokenPair(accessToken: 'new_token'));

      final options = RequestOptions(
        path: '/test',
        headers: {'Authorization': 'Bearer existing_token'},
      );
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
      expect(
          handler.options!.headers['Authorization'], 'Bearer existing_token',);
    });

    test('should use custom header name', () async {
      interceptor = DioAuthInterceptor(
        tokenStore: tokenStore,
        headerName: 'X-Auth-Token',
      );
      await tokenStore.saveTokens(const TokenPair(accessToken: 'test_token'));

      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.options!.headers['X-Auth-Token'], 'Bearer test_token');
    });

    test('should use custom token prefix', () async {
      interceptor = DioAuthInterceptor(
        tokenStore: tokenStore,
        tokenPrefix: 'Token',
      );
      await tokenStore.saveTokens(const TokenPair(accessToken: 'test_token'));

      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.options!.headers['Authorization'], 'Token test_token');
    });

    test('should respect shouldAddToken predicate', () async {
      interceptor = DioAuthInterceptor(
        tokenStore: tokenStore,
        shouldAddToken: (options) => options.path.startsWith('/api'),
      );
      await tokenStore.saveTokens(const TokenPair(accessToken: 'test_token'));

      // Should add token for /api paths
      final apiOptions = RequestOptions(path: '/api/users');
      final apiHandler = _TestRequestHandler();
      await interceptor.onRequest(apiOptions, apiHandler);
      expect(apiHandler.options!.headers['Authorization'], 'Bearer test_token');

      // Should not add token for other paths
      final otherOptions = RequestOptions(path: '/public');
      final otherHandler = _TestRequestHandler();
      await interceptor.onRequest(otherOptions, otherHandler);
      expect(otherHandler.options!.headers['Authorization'], isNull);
    });

    test('should continue without token on error', () async {
      final failingStore = _FailingTokenStore();
      interceptor = DioAuthInterceptor(tokenStore: failingStore);

      final options = RequestOptions(path: '/test');
      final handler = _TestRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.options!.headers['Authorization'], isNull);
    });
  });
}

/// Test implementation of RequestInterceptorHandler
class _TestRequestHandler extends RequestInterceptorHandler {
  bool nextCalled = false;
  RequestOptions? options;

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
    options = requestOptions;
  }
}

/// Token store that always fails
class _FailingTokenStore implements TokenStore {
  @override
  Future<TokenPair?> getTokens() => throw Exception('Store failed');

  @override
  Future<void> saveTokens(TokenPair tokens) async {}

  @override
  Future<void> clearTokens() async {}

  @override
  Stream<TokenPair?> get tokenChanges => const Stream.empty();
}
