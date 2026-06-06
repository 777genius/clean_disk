import 'package:dio/dio.dart';
import 'package:dio_http_client/src/interceptors/dio_logging_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('DioLoggingInterceptor', () {
    late List<String> logOutput;
    late DioLoggingInterceptor interceptor;

    void testLogger(String message) {
      logOutput.add(message);
    }

    setUp(() {
      logOutput = [];
      interceptor = DioLoggingInterceptor(logger: testLogger);
    });

    group('constructor', () {
      test('should have correct default values', () {
        final defaultInterceptor = DioLoggingInterceptor();
        expect(defaultInterceptor.logRequest, isTrue);
        expect(defaultInterceptor.logRequestHeaders, isTrue);
        expect(defaultInterceptor.logRequestBody, isTrue);
        expect(defaultInterceptor.logResponse, isTrue);
        expect(defaultInterceptor.logResponseHeaders, isTrue);
        expect(defaultInterceptor.logResponseBody, isTrue);
        expect(defaultInterceptor.logError, isTrue);
        expect(defaultInterceptor.maxBodyLength, 1024);
        expect(defaultInterceptor.sampleRate, 1);
      });

      test('should throw assertion error for sampleRate < 1', () {
        expect(
          () => DioLoggingInterceptor(sampleRate: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should accept custom parameters', () {
        final customInterceptor = DioLoggingInterceptor(
          logRequest: false,
          logRequestHeaders: false,
          logRequestBody: false,
          logResponse: false,
          logResponseHeaders: false,
          logResponseBody: false,
          logError: false,
          maxBodyLength: 500,
          sampleRate: 10,
        );
        expect(customInterceptor.logRequest, isFalse);
        expect(customInterceptor.logRequestHeaders, isFalse);
        expect(customInterceptor.logRequestBody, isFalse);
        expect(customInterceptor.logResponse, isFalse);
        expect(customInterceptor.logResponseHeaders, isFalse);
        expect(customInterceptor.logResponseBody, isFalse);
        expect(customInterceptor.logError, isFalse);
        expect(customInterceptor.maxBodyLength, 500);
        expect(customInterceptor.sampleRate, 10);
      });
    });

    group('onRequest', () {
      test('should log request method and URI', () {
        final options = RequestOptions(
          path: '/users',
          method: 'GET',
          baseUrl: 'https://api.example.com',
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.length, 1);
        expect(logOutput.first, contains('REQUEST'));
        expect(logOutput.first, contains('GET'));
        expect(logOutput.first, contains('/users'));
      });

      test('should log request headers when enabled', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Content-Type': 'application/json', 'Accept': 'text/plain'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('Headers:'));
        expect(logOutput.first, contains('Content-Type: application/json'));
        expect(logOutput.first, contains('Accept: text/plain'));
      });

      test('should not log headers when disabled', () {
        interceptor = DioLoggingInterceptor(
          logRequestHeaders: false,
          logger: testLogger,
        );
        final options = RequestOptions(
          path: '/test',
          headers: {'Content-Type': 'application/json'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, isNot(contains('Headers:')));
      });

      test('should log request body when provided', () {
        final options = RequestOptions(
          path: '/test',
          data: {'name': 'John', 'age': 30},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('Body:'));
        expect(logOutput.first, contains('name'));
        expect(logOutput.first, contains('John'));
      });

      test('should not log body when disabled', () {
        interceptor = DioLoggingInterceptor(
          logRequestBody: false,
          logger: testLogger,
        );
        final options = RequestOptions(path: '/test', data: {'key': 'value'});
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, isNot(contains('Body:')));
      });

      test('should not log when logRequest is disabled', () {
        interceptor = DioLoggingInterceptor(
          logRequest: false,
          logger: testLogger,
        );
        final options = RequestOptions(path: '/test');
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput, isEmpty);
        expect(handler.nextCalled, isTrue);
      });

      test('should mark request for logging based on sample rate', () {
        final options = RequestOptions(path: '/test');
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(options.extra['_dioLoggingShouldLog'], isTrue);
      });
    });

    group('onResponse', () {
      test('should log response status and method', () {
        final response = Response(
          requestOptions: RequestOptions(
            path: '/users',
            method: 'POST',
            extra: {'_dioLoggingShouldLog': true},
          ),
          statusCode: 201,
          statusMessage: 'Created',
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('RESPONSE'));
        expect(logOutput.first, contains('201'));
        expect(logOutput.first, contains('Created'));
        expect(logOutput.first, contains('POST'));
      });

      test('should log response headers when enabled', () {
        final response = Response(
          requestOptions: RequestOptions(
            path: '/test',
            extra: {'_dioLoggingShouldLog': true},
          ),
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
            'cache-control': ['no-cache'],
          }),
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(logOutput.first, contains('Headers:'));
        expect(logOutput.first, contains('content-type'));
        expect(logOutput.first, contains('application/json'));
      });

      test('should log response body when provided', () {
        final response = Response(
          requestOptions: RequestOptions(
            path: '/test',
            extra: {'_dioLoggingShouldLog': true},
          ),
          statusCode: 200,
          data: {'result': 'success', 'count': 42},
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(logOutput.first, contains('Body:'));
        expect(logOutput.first, contains('result'));
        expect(logOutput.first, contains('success'));
      });

      test('should not log response when logResponse is disabled', () {
        interceptor = DioLoggingInterceptor(
          logResponse: false,
          logger: testLogger,
        );
        final response = Response(
          requestOptions: RequestOptions(
            path: '/test',
            extra: {'_dioLoggingShouldLog': true},
          ),
          statusCode: 200,
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(logOutput, isEmpty);
        expect(handler.nextCalled, isTrue);
      });

      test('should not log response when request was not sampled', () {
        final response = Response(
          requestOptions: RequestOptions(
            path: '/test',
            extra: {'_dioLoggingShouldLog': false},
          ),
          statusCode: 200,
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(logOutput, isEmpty);
        expect(handler.nextCalled, isTrue);
      });
    });

    group('onError', () {
      test('should log error type and message', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test', method: 'DELETE'),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('ERROR'));
        expect(logOutput.first, contains('connectionTimeout'));
        expect(logOutput.first, contains('Connection timed out'));
        expect(logOutput.first, contains('DELETE'));
      });

      test('should log error response when available', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 404,
            statusMessage: 'Not Found',
            data: {'error': 'Resource not found'},
          ),
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(logOutput.first, contains('Status: 404'));
        expect(logOutput.first, contains('Not Found'));
        expect(logOutput.first, contains('Response Body:'));
        expect(logOutput.first, contains('Resource not found'));
      });

      test('should handle error without response safely', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: 'Network unreachable',
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('connectionError'));
        expect(logOutput.first, contains('Network unreachable'));
        expect(logOutput.first, isNot(contains('Status:')));
      });

      test('should not log error when logError is disabled', () {
        interceptor = DioLoggingInterceptor(
          logError: false,
          logger: testLogger,
        );
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(logOutput, isEmpty);
        expect(handler.nextCalled, isTrue);
      });

      test('should always log errors regardless of sample rate', () {
        interceptor = DioLoggingInterceptor(
          sampleRate: 100,
          logger: testLogger,
        );
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.unknown,
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(logOutput.length, 1);
        expect(logOutput.first, contains('ERROR'));
      });
    });

    group('sample rate', () {
      test('should log all requests when sampleRate is 1', () {
        interceptor = DioLoggingInterceptor(sampleRate: 1, logger: testLogger);

        for (var i = 0; i < 5; i++) {
          final options = RequestOptions(path: '/test$i');
          final handler = _TestRequestHandler();
          interceptor.onRequest(options, handler);
        }

        expect(logOutput.length, 5);
      });

      test('should log every Nth request when sampleRate > 1', () {
        interceptor = DioLoggingInterceptor(sampleRate: 3, logger: testLogger);

        for (var i = 0; i < 9; i++) {
          final options = RequestOptions(path: '/test$i');
          final handler = _TestRequestHandler();
          interceptor.onRequest(options, handler);
        }

        // sampleRate 3 means log every 3rd request (3rd, 6th, 9th)
        expect(logOutput.length, 3);
      });

      test('should use modulo to prevent counter overflow', () {
        interceptor = DioLoggingInterceptor(sampleRate: 5, logger: testLogger);

        // Simulate many requests to ensure counter wraps around
        for (var i = 0; i < 25; i++) {
          final options = RequestOptions(path: '/test$i');
          final handler = _TestRequestHandler();
          interceptor.onRequest(options, handler);
        }

        // Every 5th request should be logged: 5, 10, 15, 20, 25
        expect(logOutput.length, 5);
      });

      test('should persist sample decision in response handler', () {
        interceptor = DioLoggingInterceptor(sampleRate: 2, logger: testLogger);

        // First request - not logged
        final options1 = RequestOptions(path: '/test1');
        final handler1 = _TestRequestHandler();
        interceptor.onRequest(options1, handler1);
        expect(options1.extra['_dioLoggingShouldLog'], isFalse);

        // Second request - logged
        final options2 = RequestOptions(path: '/test2');
        final handler2 = _TestRequestHandler();
        interceptor.onRequest(options2, handler2);
        expect(options2.extra['_dioLoggingShouldLog'], isTrue);

        // Now responses should respect the markers
        final response1 = Response(
          requestOptions: options1,
          statusCode: 200,
        );
        final response2 = Response(
          requestOptions: options2,
          statusCode: 200,
        );

        logOutput.clear();
        interceptor.onResponse(response1, _TestResponseHandler());
        interceptor.onResponse(response2, _TestResponseHandler());

        // Only one response should be logged (the sampled one)
        expect(logOutput.length, 1);
      });
    });

    group('body formatting', () {
      test('should format Map as JSON', () {
        final options = RequestOptions(
          path: '/test',
          data: {'key': 'value', 'nested': {'a': 1, 'b': 2}},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('"key": "value"'));
        expect(logOutput.first, contains('"nested"'));
      });

      test('should format List as JSON', () {
        final options = RequestOptions(
          path: '/test',
          data: [1, 2, 3, 'four'],
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('1'));
        expect(logOutput.first, contains('2'));
        expect(logOutput.first, contains('3'));
        expect(logOutput.first, contains('four'));
      });

      test('should format String body as-is', () {
        final options = RequestOptions(
          path: '/test',
          data: 'plain text body',
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('plain text body'));
      });

      test('should format FormData with fields and files', () {
        final formData = FormData.fromMap({
          'field1': 'value1',
          'field2': 'value2',
        });
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromString('content', filename: 'test.txt'),
        ));

        final options = RequestOptions(path: '/test', data: formData);
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('FormData'));
        expect(logOutput.first, contains('field1'));
        expect(logOutput.first, contains('value1'));
        expect(logOutput.first, contains('test.txt'));
      });

      test('should handle null body gracefully', () {
        final options = RequestOptions(path: '/test', data: null);
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, isNot(contains('Body:')));
      });

      test('should truncate long bodies', () {
        interceptor = DioLoggingInterceptor(
          maxBodyLength: 50,
          logger: testLogger,
        );
        final longData = {'key': 'a' * 100};
        final options = RequestOptions(path: '/test', data: longData);
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('(truncated)'));
      });

      test('should not truncate short bodies', () {
        interceptor = DioLoggingInterceptor(
          maxBodyLength: 1000,
          logger: testLogger,
        );
        final shortData = {'key': 'short'};
        final options = RequestOptions(path: '/test', data: shortData);
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, isNot(contains('(truncated)')));
      });
    });

    group('sensitive header masking', () {
      test('should mask Authorization header', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Authorization': 'Bearer secret-token-12345'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('Authorization: ***'));
        expect(logOutput.first, isNot(contains('secret-token-12345')));
      });

      test('should mask Cookie header', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Cookie': 'session=abc123; user=admin'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('Cookie: ***'));
        expect(logOutput.first, isNot(contains('abc123')));
      });

      test('should mask headers containing "token"', () {
        final options = RequestOptions(
          path: '/test',
          headers: {
            'X-API-Token': 'sensitive-value',
            'Refresh-Token': 'another-secret',
          },
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('X-API-Token: ***'));
        expect(logOutput.first, contains('Refresh-Token: ***'));
        expect(logOutput.first, isNot(contains('sensitive-value')));
      });

      test('should mask headers containing "secret"', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'X-Secret-Key': 'my-secret'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('X-Secret-Key: ***'));
      });

      test('should mask headers containing "password"', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'X-Password': 'pass123'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('X-Password: ***'));
      });

      test('should mask headers containing "key"', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'X-API-Key': 'api-key-value'},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('X-API-Key: ***'));
      });

      test('should not mask non-sensitive headers', () {
        final options = RequestOptions(
          path: '/test',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/html',
            'User-Agent': 'TestClient/1.0',
          },
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(logOutput.first, contains('Content-Type: application/json'));
        expect(logOutput.first, contains('Accept: text/html'));
        expect(logOutput.first, contains('User-Agent: TestClient/1.0'));
      });

      test('should handle null header values safely', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Nullable-Header': null},
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('Nullable-Header: null'));
      });

      test('should handle non-string header values', () {
        final options = RequestOptions(
          path: '/test',
          headers: {
            'Int-Header': 123,
            'Bool-Header': true,
            'List-Header': [1, 2, 3],
          },
        );
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('Int-Header: 123'));
        expect(logOutput.first, contains('Bool-Header: true'));
        expect(logOutput.first, contains('List-Header:'));
      });
    });

    group('custom logger', () {
      test('should use custom logger when provided', () {
        final customLogs = <String>[];
        interceptor = DioLoggingInterceptor(
          logger: (msg) => customLogs.add('CUSTOM: $msg'),
        );

        final options = RequestOptions(path: '/test');
        final handler = _TestRequestHandler();
        interceptor.onRequest(options, handler);

        expect(customLogs.length, 1);
        expect(customLogs.first, startsWith('CUSTOM:'));
      });

      test('should use print when no custom logger', () {
        // This test just verifies the interceptor doesn't throw
        // when using the default print logger
        final defaultInterceptor = DioLoggingInterceptor();
        final options = RequestOptions(path: '/test');
        final handler = _TestRequestHandler();

        expect(
          () => defaultInterceptor.onRequest(options, handler),
          returnsNormally,
        );
      });
    });

    group('edge cases', () {
      test('should handle empty headers map', () {
        final options = RequestOptions(path: '/test', headers: {});
        final handler = _TestRequestHandler();

        interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        // Should not show Headers section when empty
        expect(logOutput.first, isNot(contains('Headers:')));
      });

      test('should handle empty response headers', () {
        final response = Response(
          requestOptions: RequestOptions(
            path: '/test',
            extra: {'_dioLoggingShouldLog': true},
          ),
          statusCode: 204,
          headers: Headers(),
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        expect(handler.nextCalled, isTrue);
      });

      test('should handle error with null message', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.unknown,
          message: null,
        );
        final handler = _TestErrorHandler();

        interceptor.onError(error, handler);

        expect(handler.nextCalled, isTrue);
        expect(logOutput.first, contains('Unknown error'));
      });

      test('should handle missing _shouldLogKey in response', () {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
        );
        final handler = _TestResponseHandler();

        interceptor.onResponse(response, handler);

        // Default behavior should log when key is missing
        expect(logOutput.length, 1);
        expect(handler.nextCalled, isTrue);
      });
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

/// Test implementation of ResponseInterceptorHandler
class _TestResponseHandler extends ResponseInterceptorHandler {
  bool nextCalled = false;
  Response<dynamic>? response;

  @override
  void next(Response<dynamic> resp) {
    nextCalled = true;
    response = resp;
  }
}

/// Test implementation of ErrorInterceptorHandler
class _TestErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;
  DioException? error;

  @override
  void next(DioException err) {
    nextCalled = true;
    error = err;
  }
}
