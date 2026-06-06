import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(
    method: HttpMethod.get,
    path: '/test',
  );

  group('HttpErrorType', () {
    test('isRetryable should return true for retryable errors', () {
      expect(HttpErrorType.connectionTimeout.isRetryable, isTrue);
      expect(HttpErrorType.sendTimeout.isRetryable, isTrue);
      expect(HttpErrorType.receiveTimeout.isRetryable, isTrue);
      expect(HttpErrorType.networkUnreachable.isRetryable, isTrue);
      expect(HttpErrorType.dnsLookupFailed.isRetryable, isTrue);
      expect(HttpErrorType.rateLimited.isRetryable, isTrue);
      expect(HttpErrorType.serverError.isRetryable, isTrue);
    });

    test('isRetryable should return false for non-retryable errors', () {
      expect(HttpErrorType.badCertificate.isRetryable, isFalse);
      expect(HttpErrorType.badResponse.isRetryable, isFalse);
      expect(HttpErrorType.cancelled.isRetryable, isFalse);
      // dnsLookupFailed is now retryable (transient DNS failures)
      expect(HttpErrorType.unauthorized.isRetryable, isFalse);
      expect(HttpErrorType.forbidden.isRetryable, isFalse);
      expect(HttpErrorType.notFound.isRetryable, isFalse);
      expect(HttpErrorType.unknown.isRetryable, isFalse);
    });

    test('isAuthError should return true for auth errors', () {
      expect(HttpErrorType.unauthorized.isAuthError, isTrue);
      expect(HttpErrorType.forbidden.isAuthError, isTrue);
    });

    test('isAuthError should return false for non-auth errors', () {
      expect(HttpErrorType.badResponse.isAuthError, isFalse);
      expect(HttpErrorType.serverError.isAuthError, isFalse);
      expect(HttpErrorType.notFound.isAuthError, isFalse);
    });

    test('isTimeout should return true for timeout errors', () {
      expect(HttpErrorType.connectionTimeout.isTimeout, isTrue);
      expect(HttpErrorType.sendTimeout.isTimeout, isTrue);
      expect(HttpErrorType.receiveTimeout.isTimeout, isTrue);
    });

    test('isTimeout should return false for non-timeout errors', () {
      expect(HttpErrorType.networkUnreachable.isTimeout, isFalse);
      expect(HttpErrorType.serverError.isTimeout, isFalse);
      expect(HttpErrorType.cancelled.isTimeout, isFalse);
    });

    test('isNetworkError should return true for network errors', () {
      expect(HttpErrorType.connectionTimeout.isNetworkError, isTrue);
      expect(HttpErrorType.networkUnreachable.isNetworkError, isTrue);
      expect(HttpErrorType.dnsLookupFailed.isNetworkError, isTrue);
    });

    test('isNetworkError should return false for non-network errors', () {
      expect(HttpErrorType.sendTimeout.isNetworkError, isFalse);
      expect(HttpErrorType.serverError.isNetworkError, isFalse);
      expect(HttpErrorType.unauthorized.isNetworkError, isFalse);
    });
  });

  group('HttpError', () {
    test('should create with required parameters', () {
      const error = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
      );

      expect(error.type, HttpErrorType.badResponse);
      expect(error.request, testRequest);
      expect(error.response, isNull);
      expect(error.cause, isNull);
      expect(error.stackTrace, isNull);
      expect(error.message, isNull);
    });

    test('should create with all parameters', () {
      const response = HttpResponse<dynamic>(
        statusCode: 500,
        request: testRequest,
      );

      final error = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
        response: response,
        cause: Exception('test'),
        stackTrace: StackTrace.current,
        message: 'Test error',
      );

      expect(error.type, HttpErrorType.serverError);
      expect(error.response, response);
      expect(error.cause, isA<Exception>());
      expect(error.stackTrace, isNotNull);
      expect(error.message, 'Test error');
    });

    test('statusCode should return response status code', () {
      const response = HttpResponse<dynamic>(
        statusCode: 404,
        request: testRequest,
      );

      const error = HttpError(
        type: HttpErrorType.notFound,
        request: testRequest,
        response: response,
      );

      expect(error.statusCode, 404);
    });

    test('statusCode should return null when no response', () {
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      expect(error.statusCode, isNull);
    });

    test('isRetryable should delegate to type', () {
      const retryable = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
      );

      const nonRetryable = HttpError(
        type: HttpErrorType.notFound,
        request: testRequest,
      );

      expect(retryable.isRetryable, isTrue);
      expect(nonRetryable.isRetryable, isFalse);
    });

    test('isAuthError should delegate to type', () {
      const authError = HttpError(
        type: HttpErrorType.unauthorized,
        request: testRequest,
      );

      const nonAuthError = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
      );

      expect(authError.isAuthError, isTrue);
      expect(nonAuthError.isAuthError, isFalse);
    });

    test('isTimeout should delegate to type', () {
      const timeout = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      const nonTimeout = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
      );

      expect(timeout.isTimeout, isTrue);
      expect(nonTimeout.isTimeout, isFalse);
    });

    test('isNetworkError should delegate to type', () {
      const network = HttpError(
        type: HttpErrorType.networkUnreachable,
        request: testRequest,
      );

      const nonNetwork = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
      );

      expect(network.isNetworkError, isTrue);
      expect(nonNetwork.isNetworkError, isFalse);
    });

    group('named constructors', () {
      test('connectionTimeout should set correct type', () {
        const error = HttpError.connectionTimeout(request: testRequest);
        expect(error.type, HttpErrorType.connectionTimeout);
        expect(error.response, isNull);
      });

      test('unauthorized should set correct type', () {
        const error = HttpError.unauthorized(request: testRequest);
        expect(error.type, HttpErrorType.unauthorized);
      });

      test('cancelled should set correct type', () {
        const error = HttpError.cancelled(request: testRequest);
        expect(error.type, HttpErrorType.cancelled);
        expect(error.response, isNull);
      });
    });

    group('fromStatusCode factory', () {
      test('should map 401 to unauthorized', () {
        final error = HttpError.fromStatusCode(
          statusCode: 401,
          request: testRequest,
        );
        expect(error.type, HttpErrorType.unauthorized);
      });

      test('should map 403 to forbidden', () {
        final error = HttpError.fromStatusCode(
          statusCode: 403,
          request: testRequest,
        );
        expect(error.type, HttpErrorType.forbidden);
      });

      test('should map 404 to notFound', () {
        final error = HttpError.fromStatusCode(
          statusCode: 404,
          request: testRequest,
        );
        expect(error.type, HttpErrorType.notFound);
      });

      test('should map 429 to rateLimited', () {
        final error = HttpError.fromStatusCode(
          statusCode: 429,
          request: testRequest,
        );
        expect(error.type, HttpErrorType.rateLimited);
      });

      test('should map 5xx to serverError', () {
        for (final code in [500, 501, 502, 503, 504, 599]) {
          final error = HttpError.fromStatusCode(
            statusCode: code,
            request: testRequest,
          );
          expect(error.type, HttpErrorType.serverError);
        }
      });

      test('should map other 4xx to badResponse', () {
        for (final code in [400, 405, 406, 408, 409]) {
          final error = HttpError.fromStatusCode(
            statusCode: code,
            request: testRequest,
          );
          expect(error.type, HttpErrorType.badResponse);
        }
      });
    });

    test('copyWith should create modified copy', () {
      const original = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
        message: 'original',
      );

      final copy = original.copyWith(
        type: HttpErrorType.serverError,
        message: 'modified',
      );

      expect(copy.type, HttpErrorType.serverError);
      expect(copy.message, 'modified');
      expect(copy.request, testRequest);
    });

    test('toString should include type and status code', () {
      const response = HttpResponse<dynamic>(
        statusCode: 404,
        request: testRequest,
      );

      const error = HttpError(
        type: HttpErrorType.notFound,
        request: testRequest,
        response: response,
        message: 'Not found',
      );

      final str = error.toString();
      expect(str, contains('notFound'));
      expect(str, contains('404'));
      expect(str, contains('Not found'));
    });

    test('equality should be based on all fields', () {
      const a = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
        message: 'test',
      );

      const b = HttpError(
        type: HttpErrorType.badResponse,
        request: testRequest,
        message: 'test',
      );

      const c = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
        message: 'test',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
