import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(
    method: HttpMethod.get,
    path: '/test',
  );

  group('ExponentialBackoffPolicy', () {
    test('should create with default parameters', () {
      const policy = ExponentialBackoffPolicy();

      expect(policy.maxAttempts, 3);
      expect(policy.initialDelay, const Duration(milliseconds: 500));
      expect(policy.maxDelay, const Duration(seconds: 30));
      expect(policy.multiplier, 2.0);
    });

    test('should create with custom parameters', () {
      const policy = ExponentialBackoffPolicy(
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 60),
        multiplier: 1.5,
      );

      expect(policy.maxAttempts, 5);
      expect(policy.initialDelay, const Duration(milliseconds: 100));
      expect(policy.maxDelay, const Duration(seconds: 60));
      expect(policy.multiplier, 1.5);
    });

    group('shouldRetry', () {
      test('should retry retryable errors within max attempts', () {
        const policy = ExponentialBackoffPolicy();

        const retryableError = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
        );

        expect(policy.shouldRetry(retryableError, 1), isTrue);
        expect(policy.shouldRetry(retryableError, 2), isTrue);
        expect(
            policy.shouldRetry(retryableError, 3), isFalse,); // >= maxAttempts
      });

      test('should not retry non-retryable errors', () {
        const policy = ExponentialBackoffPolicy();

        const nonRetryableError = HttpError(
          type: HttpErrorType.notFound,
          request: testRequest,
        );

        expect(policy.shouldRetry(nonRetryableError, 1), isFalse);
      });

      test('should retry all retryable error types', () {
        const policy = ExponentialBackoffPolicy();

        final retryableTypes = [
          HttpErrorType.connectionTimeout,
          HttpErrorType.sendTimeout,
          HttpErrorType.receiveTimeout,
          HttpErrorType.networkUnreachable,
          HttpErrorType.rateLimited,
          HttpErrorType.serverError,
        ];

        for (final type in retryableTypes) {
          final error = HttpError(type: type, request: testRequest);
          expect(policy.shouldRetry(error, 1), isTrue, reason: 'Type: $type');
        }
      });

      test('should not retry non-retryable error types', () {
        const policy = ExponentialBackoffPolicy();

        final nonRetryableTypes = [
          HttpErrorType.badCertificate,
          HttpErrorType.badResponse,
          HttpErrorType.cancelled,
          // dnsLookupFailed is now retryable (transient DNS failures)
          HttpErrorType.unauthorized,
          HttpErrorType.forbidden,
          HttpErrorType.notFound,
          HttpErrorType.unknown,
        ];

        for (final type in nonRetryableTypes) {
          final error = HttpError(type: type, request: testRequest);
          expect(policy.shouldRetry(error, 1), isFalse, reason: 'Type: $type');
        }
      });

      test('should use custom retryableErrorTypes', () {
        const policy = ExponentialBackoffPolicy(
          retryableErrorTypes: {HttpErrorType.serverError},
        );

        const serverError = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
        );

        const timeoutError = HttpError(
          type: HttpErrorType.connectionTimeout, // Normally retryable
          request: testRequest,
        );

        expect(policy.shouldRetry(serverError, 1), isTrue);
        expect(policy.shouldRetry(timeoutError, 1), isFalse);
      });
    });

    group('getDelay', () {
      test('should calculate exponential delays', () {
        const policy = ExponentialBackoffPolicy(
          initialDelay: Duration(seconds: 1),
        );

        expect(policy.getDelay(1), const Duration(seconds: 1));
        expect(policy.getDelay(2), const Duration(seconds: 2));
        expect(policy.getDelay(3), const Duration(seconds: 4));
        expect(policy.getDelay(4), const Duration(seconds: 8));
      });

      test('should cap delay at maxDelay', () {
        const policy = ExponentialBackoffPolicy(
          initialDelay: Duration(seconds: 10),
        );

        expect(policy.getDelay(1), const Duration(seconds: 10));
        expect(policy.getDelay(2), const Duration(seconds: 20));
        expect(policy.getDelay(3), const Duration(seconds: 30)); // Capped
        expect(policy.getDelay(4), const Duration(seconds: 30)); // Capped
      });

      test('should handle custom multiplier', () {
        const policy = ExponentialBackoffPolicy(
          initialDelay: Duration(seconds: 1),
          multiplier: 1.5,
        );

        // With multiplier 1.5:
        // attempt 1: 1 * 1.5^0 = 1
        // attempt 2: 1 * 1.5^1 = 1.5
        // attempt 3: 1 * 1.5^2 = 2.25
        expect(policy.getDelay(1), const Duration(seconds: 1));
        expect(
          policy.getDelay(2).inMilliseconds,
          closeTo(1500, 1),
        );
        expect(
          policy.getDelay(3).inMilliseconds,
          closeTo(2250, 1),
        );
      });
    });

    test('zero maxAttempts should never retry', () {
      const policy = ExponentialBackoffPolicy(maxAttempts: 0);

      const error = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
      );

      expect(policy.shouldRetry(error, 1), isFalse);
    });

    test('toString should include parameters', () {
      const policy = ExponentialBackoffPolicy();
      final str = policy.toString();

      expect(str, contains('ExponentialBackoffPolicy'));
      expect(str, contains('maxAttempts'));
      expect(str, contains('initialDelay'));
    });
  });

  group('ConstantDelayPolicy', () {
    test('should create with default parameters', () {
      const policy = ConstantDelayPolicy();

      expect(policy.maxAttempts, 3);
      expect(policy.delay, const Duration(seconds: 1));
    });

    test('should return constant delay', () {
      const policy = ConstantDelayPolicy(
        delay: Duration(milliseconds: 500),
      );

      expect(policy.getDelay(1), const Duration(milliseconds: 500));
      expect(policy.getDelay(2), const Duration(milliseconds: 500));
      expect(policy.getDelay(3), const Duration(milliseconds: 500));
    });

    test('should respect maxAttempts', () {
      const policy = ConstantDelayPolicy(maxAttempts: 2);

      const error = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
      );

      expect(policy.shouldRetry(error, 1), isTrue);
      expect(policy.shouldRetry(error, 2), isFalse);
    });
  });

  group('NoRetryPolicy', () {
    test('should never retry', () {
      const policy = NoRetryPolicy();

      const error = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
      );

      expect(policy.shouldRetry(error, 1), isFalse);
      expect(policy.shouldRetry(error, 2), isFalse);
    });

    test('should return zero delay', () {
      const policy = NoRetryPolicy();

      expect(policy.getDelay(1), Duration.zero);
    });
  });

  group('RetryPolicy.prepareRetry', () {
    test('default should return request unchanged', () {
      const policy = ExponentialBackoffPolicy();
      const request = HttpRequest(method: HttpMethod.get, path: '/test');

      final prepared = policy.prepareRetry(request, 1);

      expect(prepared, same(request));
    });
  });
}
