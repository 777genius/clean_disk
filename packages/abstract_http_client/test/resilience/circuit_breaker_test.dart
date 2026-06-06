import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(method: HttpMethod.get, path: '/test');

  group('CircuitBreakerState', () {
    test('should have three states', () {
      expect(CircuitBreakerState.values.length, 3);
      expect(CircuitBreakerState.closed, isNotNull);
      expect(CircuitBreakerState.open, isNotNull);
      expect(CircuitBreakerState.halfOpen, isNotNull);
    });
  });

  group('CircuitBreakerConfig', () {
    test('should create with default values', () {
      const config = CircuitBreakerConfig();

      expect(config.failureThreshold, 5);
      expect(config.successThreshold, 2);
      expect(config.openDuration, const Duration(seconds: 30));
      expect(config.halfOpenMaxRequests, 1);
      expect(config.failureCountingWindow, const Duration(minutes: 1));
      expect(config.errorFilter, isNull);
    });

    test('should create with custom values', () {
      bool errorFilter(HttpError e) => e.isRetryable;

      final config = CircuitBreakerConfig(
        failureThreshold: 10,
        successThreshold: 3,
        openDuration: const Duration(seconds: 60),
        halfOpenMaxRequests: 2,
        failureCountingWindow: const Duration(minutes: 5),
        errorFilter: errorFilter,
      );

      expect(config.failureThreshold, 10);
      expect(config.successThreshold, 3);
      expect(config.openDuration, const Duration(seconds: 60));
      expect(config.halfOpenMaxRequests, 2);
      expect(config.failureCountingWindow, const Duration(minutes: 5));
      expect(config.errorFilter, isNotNull);
    });

    group('copyWith', () {
      test('should create copy with no changes when no args', () {
        const original = CircuitBreakerConfig(
          failureThreshold: 10,
          successThreshold: 3,
        );

        final copy = original.copyWith();

        expect(copy.failureThreshold, original.failureThreshold);
        expect(copy.successThreshold, original.successThreshold);
        expect(copy.openDuration, original.openDuration);
      });

      test('should create copy with changed values', () {
        const original = CircuitBreakerConfig(
          failureThreshold: 5,
          successThreshold: 2,
        );

        final copy = original.copyWith(
          failureThreshold: 10,
          openDuration: const Duration(minutes: 1),
        );

        expect(copy.failureThreshold, 10);
        expect(copy.successThreshold, 2);
        expect(copy.openDuration, const Duration(minutes: 1));
      });
    });

    group('errorFilter', () {
      test('should filter retryable errors only', () {
        final config = CircuitBreakerConfig(
          errorFilter: (e) => e.isRetryable,
        );

        final retryableError = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
        );

        final nonRetryableError = HttpError(
          type: HttpErrorType.badResponse,
          request: testRequest,
        );

        expect(config.errorFilter!(retryableError), isTrue);
        expect(config.errorFilter!(nonRetryableError), isFalse);
      });

      test('should filter by status code', () {
        final config = CircuitBreakerConfig(
          errorFilter: (e) => e.statusCode == 503,
        );

        final error503 = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
          response: const HttpResponse(statusCode: 503, request: testRequest),
        );

        final error500 = HttpError(
          type: HttpErrorType.serverError,
          request: testRequest,
          response: const HttpResponse(statusCode: 500, request: testRequest),
        );

        expect(config.errorFilter!(error503), isTrue);
        expect(config.errorFilter!(error500), isFalse);
      });
    });

    test('toString should include relevant information', () {
      const config = CircuitBreakerConfig(
        failureThreshold: 10,
        successThreshold: 3,
      );

      final str = config.toString();

      expect(str, contains('CircuitBreakerConfig'));
      expect(str, contains('failureThreshold: 10'));
      expect(str, contains('successThreshold: 3'));
    });
  });

  group('CircuitBreakerOpenException', () {
    test('should create with message', () {
      const exception = CircuitBreakerOpenException('Service unavailable');

      expect(exception.message, 'Service unavailable');
    });

    test('should create without message', () {
      const exception = CircuitBreakerOpenException();

      expect(exception.message, isNull);
    });

    test('toString should include message', () {
      const exception = CircuitBreakerOpenException('Service unavailable');

      expect(exception.toString(), contains('CircuitBreakerOpenException'));
      expect(exception.toString(), contains('Service unavailable'));
    });

    test('toString should use default message when null', () {
      const exception = CircuitBreakerOpenException();

      expect(exception.toString(), contains('Circuit breaker is open'));
    });
  });
}
