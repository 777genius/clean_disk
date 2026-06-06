import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(
    method: HttpMethod.get,
    path: '/test',
  );

  group('HttpResponse', () {
    test('should create with required parameters', () {
      const response = HttpResponse<String>(
        statusCode: 200,
        request: testRequest,
      );

      expect(response.statusCode, 200);
      expect(response.request, testRequest);
      expect(response.data, isNull);
      expect(response.headers, isEmpty);
      expect(response.statusMessage, isNull);
      expect(response.rawBody, isNull);
      expect(response.latency, isNull);
      expect(response.extra, isNull);
    });

    test('should create with all parameters', () {
      const response = HttpResponse<Map<String, dynamic>>(
        statusCode: 200,
        request: testRequest,
        data: {'key': 'value'},
        headers: {'content-type': 'application/json'},
        statusMessage: 'OK',
        rawBody: '{"key":"value"}',
        latency: Duration(milliseconds: 100),
        extra: {'cached': true},
      );

      expect(response.statusCode, 200);
      expect(response.data, {'key': 'value'});
      expect(response.headers, {'content-type': 'application/json'});
      expect(response.statusMessage, 'OK');
      expect(response.rawBody, '{"key":"value"}');
      expect(response.latency, const Duration(milliseconds: 100));
      expect(response.extra, {'cached': true});
    });

    group('status code helpers', () {
      test('isSuccess should return true for 2xx', () {
        for (final code in [200, 201, 204, 299]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isSuccess, isTrue, reason: 'Status $code');
        }
      });

      test('isSuccess should return false for non-2xx', () {
        for (final code in [100, 199, 300, 400, 500]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isSuccess, isFalse, reason: 'Status $code');
        }
      });

      test('isRedirect should return true for 3xx', () {
        for (final code in [300, 301, 302, 304, 307, 399]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isRedirect, isTrue, reason: 'Status $code');
        }
      });

      test('isClientError should return true for 4xx', () {
        for (final code in [400, 401, 403, 404, 499]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isClientError, isTrue, reason: 'Status $code');
        }
      });

      test('isServerError should return true for 5xx', () {
        for (final code in [500, 502, 503, 504, 599]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isServerError, isTrue, reason: 'Status $code');
        }
      });

      test('isError should return true for 4xx and 5xx', () {
        for (final code in [400, 404, 500, 503]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isError, isTrue, reason: 'Status $code');
        }

        for (final code in [200, 204, 301, 304]) {
          final response = HttpResponse<void>(
            statusCode: code,
            request: testRequest,
          );
          expect(response.isError, isFalse, reason: 'Status $code');
        }
      });
    });

    group('header method', () {
      test('should return header value case-insensitively', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.header('content-type'), 'application/json');
        expect(response.header('Content-Type'), 'application/json');
        expect(response.header('CONTENT-TYPE'), 'application/json');
      });

      test('should return null for missing header', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.header('X-Missing'), isNull);
      });
    });

    group('contentType getter', () {
      test('should return Content-Type header', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
          headers: {'content-type': 'application/json'},
        );

        expect(response.contentType, 'application/json');
      });

      test('should return null when not present', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
        );

        expect(response.contentType, isNull);
      });
    });

    group('contentLength getter', () {
      test('should parse Content-Length header', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
          headers: {'content-length': '1234'},
        );

        expect(response.contentLength, 1234);
      });

      test('should return null when not present', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
        );

        expect(response.contentLength, isNull);
      });

      test('should return null for invalid value', () {
        const response = HttpResponse<void>(
          statusCode: 200,
          request: testRequest,
          headers: {'content-length': 'invalid'},
        );

        expect(response.contentLength, isNull);
      });
    });

    group('copyWith', () {
      test('should create copy with changed values', () {
        const original = HttpResponse<String>(
          statusCode: 200,
          request: testRequest,
          data: 'original',
        );

        final copy = original.copyWith(
          statusCode: 201,
          data: 'modified',
        );

        expect(copy.statusCode, 201);
        expect(copy.data, 'modified');
        expect(copy.request, testRequest);
      });

      test('should preserve unchanged values', () {
        const original = HttpResponse<String>(
          statusCode: 200,
          request: testRequest,
          headers: {'X-Custom': 'value'},
        );

        final copy = original.copyWith(statusCode: 201);

        expect(copy.headers, {'X-Custom': 'value'});
      });
    });

    group('transform', () {
      test('should transform data with different type', () {
        const response = HttpResponse<Map<String, dynamic>>(
          statusCode: 200,
          request: testRequest,
          data: {'name': 'John', 'age': 30},
        );

        final transformed = response.transform<String>(
          (data) => data?['name'] as String? ?? '',
        );

        expect(transformed.data, 'John');
        expect(transformed.statusCode, 200);
        expect(transformed.request, testRequest);
      });

      test('should preserve other properties', () {
        const response = HttpResponse<int>(
          statusCode: 200,
          request: testRequest,
          data: 42,
          headers: {'X-Custom': 'value'},
          statusMessage: 'OK',
          latency: Duration(milliseconds: 100),
        );

        final transformed = response.transform<String>((data) => '$data');

        expect(transformed.data, '42');
        expect(transformed.headers, {'X-Custom': 'value'});
        expect(transformed.statusMessage, 'OK');
        expect(transformed.latency, const Duration(milliseconds: 100));
      });
    });

    test('toString should include status and data', () {
      const response = HttpResponse<String>(
        statusCode: 200,
        request: testRequest,
        data: 'test data',
        statusMessage: 'OK',
      );

      final str = response.toString();
      expect(str, contains('200'));
      expect(str, contains('OK'));
      expect(str, contains('test data'));
    });

    test('equality should be based on all fields', () {
      const a = HttpResponse<String>(
        statusCode: 200,
        request: testRequest,
        data: 'test',
      );

      const b = HttpResponse<String>(
        statusCode: 200,
        request: testRequest,
        data: 'test',
      );

      const c = HttpResponse<String>(
        statusCode: 201,
        request: testRequest,
        data: 'test',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
