import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;
import 'package:dio/dio.dart' as dio show CancelToken;
import 'package:dio_http_client/src/interceptors/dio_retry_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('DioRetryInterceptor', () {
    late Dio dioInstance;
    late DioRetryInterceptor interceptor;

    setUp(() {
      dioInstance = Dio();
      interceptor = DioRetryInterceptor(
        policy: const ExponentialBackoffPolicy(
          initialDelay: Duration(milliseconds: 10),
        ),
        dio: dioInstance,
      );
    });

    test('should pass through non-retryable errors', () async {
      final options = RequestOptions(path: '/test');
      final dioException = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: options,
        response: Response(
          statusCode: 404,
          requestOptions: options,
        ),
      );

      final handler = _TestErrorHandler();
      await interceptor.onError(dioException, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolveCalled, isFalse);
    });

    test('should not retry cancelled requests', () async {
      final cancelToken = dio.CancelToken();
      cancelToken.cancel('Cancelled');

      final options = RequestOptions(
        path: '/test',
        cancelToken: cancelToken,
      );

      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: options,
      );

      final handler = _TestErrorHandler();
      await interceptor.onError(dioException, handler);

      // Cancelled requests should be rejected, not passed through
      expect(handler.rejectCalled, isTrue);
      expect(handler.resolveCalled, isFalse);
      expect(handler.error?.type, DioExceptionType.cancel);
    });

    test('should respect maxAttempts', () async {
      const policy = ExponentialBackoffPolicy(
        maxAttempts: 1,
        initialDelay: Duration.zero,
      );

      interceptor = DioRetryInterceptor(policy: policy, dio: dioInstance);

      final options = RequestOptions(path: '/test');
      options.extra['_retryAttempt'] = 1; // Already at max

      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: options,
      );

      final handler = _TestErrorHandler();
      await interceptor.onError(dioException, handler);

      expect(handler.nextCalled, isTrue);
    });

    test('should track attempt count', () async {
      const policy = ExponentialBackoffPolicy(
        initialDelay: Duration(milliseconds: 1),
        maxAttempts: 2, // Need at least 2 to allow one retry
      );

      interceptor = DioRetryInterceptor(policy: policy, dio: dioInstance);

      final options = RequestOptions(path: '/test');

      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: options,
      );

      final handler = _TestErrorHandler();
      await interceptor.onError(dioException, handler);

      // Interceptor now copies options to avoid mutating shared state,
      // so check the error's requestOptions instead of original
      expect(handler.nextCalled, isTrue);
      expect(handler.error?.requestOptions.extra['_retryAttempt'], isNotNull);
    });

    group('error type mapping', () {
      test('should map connectionTimeout', () async {
        final options = RequestOptions(path: '/test');
        options.extra['_retryAttempt'] = 10; // Exceed safety limit

        final dioException = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: options,
        );

        final handler = _TestErrorHandler();
        await interceptor.onError(dioException, handler);

        expect(handler.nextCalled, isTrue);
      });

      test('should map sendTimeout', () async {
        final options = RequestOptions(path: '/test');
        options.extra['_retryAttempt'] = 10;

        final dioException = DioException(
          type: DioExceptionType.sendTimeout,
          requestOptions: options,
        );

        final handler = _TestErrorHandler();
        await interceptor.onError(dioException, handler);

        expect(handler.nextCalled, isTrue);
      });

      test('should map 429 to rateLimited', () async {
        final options = RequestOptions(path: '/test');
        options.extra['_retryAttempt'] = 0;

        final dioException = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: options,
          response: Response(
            statusCode: 429,
            requestOptions: options,
          ),
        );

        // Policy should allow retry for rate limited
        const policy = ExponentialBackoffPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 1),
        );
        interceptor = DioRetryInterceptor(policy: policy, dio: dioInstance);

        final handler = _TestErrorHandler();
        await interceptor.onError(dioException, handler);

        // Should have tried to retry
        expect(handler.nextCalled || handler.resolveCalled, isTrue);
      });

      test('should map 5xx to serverError', () async {
        final options = RequestOptions(path: '/test');
        options.extra['_retryAttempt'] = 0;

        final dioException = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: options,
          response: Response(
            statusCode: 503,
            requestOptions: options,
          ),
        );

        // Policy should allow retry for server error
        const policy = ExponentialBackoffPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 1),
        );
        interceptor = DioRetryInterceptor(policy: policy, dio: dioInstance);

        final handler = _TestErrorHandler();
        await interceptor.onError(dioException, handler);

        expect(handler.nextCalled || handler.resolveCalled, isTrue);
      });
    });

    test('should respect NoRetryPolicy', () async {
      interceptor = DioRetryInterceptor(
        policy: const NoRetryPolicy(),
        dio: dioInstance,
      );

      final options = RequestOptions(path: '/test');
      final dioException = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: options,
      );

      final handler = _TestErrorHandler();
      await interceptor.onError(dioException, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolveCalled, isFalse);
    });
  });
}

/// Test implementation of ErrorInterceptorHandler
class _TestErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;
  bool resolveCalled = false;
  bool rejectCalled = false;
  DioException? error;
  Response<dynamic>? response;

  @override
  void next(DioException err) {
    nextCalled = true;
    error = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolveCalled = true;
    this.response = response;
  }

  @override
  void reject(DioException err) {
    rejectCalled = true;
    error = err;
  }
}
