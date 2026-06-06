import 'dart:io';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio_http_client/dio_http_client.dart';
import 'package:test/test.dart';

import 'test_http_server.dart';

void main() {
  late TestHttpServer server;
  late DioHttpClient client;

  setUp(() async {
    server = TestHttpServer();
    await server.start();

    client = DioHttpClient(
      config: DioHttpClientConfig(
        baseUrl: server.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    await client.initialize();
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('Error Handling E2E', () {
    group('HTTP 4xx errors', () {
      test('should handle 400 Bad Request', () async {
        server.addHandler(
          '/bad',
          TestHttpServer.errorResponse(
            HttpStatus.badRequest,
            body: {'error': 'Bad Request', 'message': 'Invalid input'},
          ),
        );

        expect(
          () => client.get<void>('/bad'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.badResponse)
                .having((e) => e.response?.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('should handle 401 Unauthorized', () async {
        server.addHandler(
          '/protected',
          TestHttpServer.errorResponse(
            HttpStatus.unauthorized,
            body: {'error': 'Unauthorized'},
          ),
        );

        expect(
          () => client.get<void>('/protected'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.unauthorized)
                .having((e) => e.response?.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('should handle 403 Forbidden', () async {
        server.addHandler(
          '/forbidden',
          TestHttpServer.errorResponse(
            HttpStatus.forbidden,
            body: {'error': 'Forbidden'},
          ),
        );

        expect(
          () => client.get<void>('/forbidden'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.forbidden)
                .having((e) => e.response?.statusCode, 'statusCode', 403),
          ),
        );
      });

      test('should handle 404 Not Found', () async {
        server.addHandler(
          '/missing',
          TestHttpServer.errorResponse(
            HttpStatus.notFound,
            body: {'error': 'Not Found'},
          ),
        );

        expect(
          () => client.get<void>('/missing'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.notFound)
                .having((e) => e.response?.statusCode, 'statusCode', 404),
          ),
        );
      });

      test('should handle 429 Too Many Requests', () async {
        server.addHandler('/rate-limited', (request) async {
          request.response
            ..statusCode = HttpStatus.tooManyRequests
            ..headers.add('Retry-After', '60')
            ..headers.contentType = ContentType.json;
          await request.response.json(
            {'error': 'Rate limited'},
            statusCode: HttpStatus.tooManyRequests,
          );
        });

        expect(
          () => client.get<void>('/rate-limited'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.rateLimited)
                .having((e) => e.response?.statusCode, 'statusCode', 429),
          ),
        );
      });
    });

    group('HTTP 5xx errors', () {
      test('should handle 500 Internal Server Error', () async {
        server.addHandler(
          '/error',
          TestHttpServer.errorResponse(
            HttpStatus.internalServerError,
            body: {'error': 'Internal Server Error'},
          ),
        );

        expect(
          () => client.get<void>('/error'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.serverError)
                .having((e) => e.response?.statusCode, 'statusCode', 500),
          ),
        );
      });

      test('should handle 502 Bad Gateway', () async {
        server.addHandler(
          '/gateway',
          TestHttpServer.errorResponse(
            HttpStatus.badGateway,
            message: 'Bad Gateway',
          ),
        );

        expect(
          () => client.get<void>('/gateway'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.serverError)
                .having((e) => e.response?.statusCode, 'statusCode', 502),
          ),
        );
      });

      test('should handle 503 Service Unavailable', () async {
        server.addHandler(
          '/unavailable',
          TestHttpServer.errorResponse(
            HttpStatus.serviceUnavailable,
            body: {'error': 'Service Unavailable'},
          ),
        );

        expect(
          () => client.get<void>('/unavailable'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.serverError)
                .having((e) => e.response?.statusCode, 'statusCode', 503),
          ),
        );
      });

      test('should handle 504 Gateway Timeout', () async {
        server.addHandler(
          '/timeout-gateway',
          TestHttpServer.errorResponse(
            HttpStatus.gatewayTimeout,
            message: 'Gateway Timeout',
          ),
        );

        expect(
          () => client.get<void>('/timeout-gateway'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.serverError)
                .having((e) => e.response?.statusCode, 'statusCode', 504),
          ),
        );
      });
    });

    group('Timeout errors', () {
      test('should handle receive timeout', () async {
        // Create client with short timeout
        final shortTimeoutClient = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            receiveTimeout: const Duration(milliseconds: 100),
          ),
        );
        await shortTimeoutClient.initialize();

        server.addHandler(
          '/slow',
          TestHttpServer.delayedResponse(const Duration(seconds: 2)),
        );

        try {
          expect(
            () => shortTimeoutClient.get<void>('/slow'),
            throwsA(
              isA<HttpError>().having(
                (e) => e.type,
                'type',
                HttpErrorType.receiveTimeout,
              ),
            ),
          );
        } finally {
          await shortTimeoutClient.dispose();
        }
      });
    });

    group('Error response body', () {
      test('should include error response body in HttpError', () async {
        server.addHandler(
          '/validation-error',
          TestHttpServer.errorResponse(
            HttpStatus.badRequest,
            body: {
              'errors': [
                {'field': 'email', 'message': 'Invalid email format'},
                {'field': 'password', 'message': 'Too short'},
              ],
            },
          ),
        );

        try {
          await client.get<void>('/validation-error');
          fail('Should have thrown');
        } on HttpError catch (e) {
          expect(e.response, isNotNull);
          expect(e.response?.statusCode, equals(400));

          final body = e.response?.rawBody as Map<String, dynamic>?;
          expect(body?['errors'], isA<List>());
          expect((body?['errors'] as List).length, equals(2));
        }
      });

      test('should handle non-JSON error response', () async {
        server.addHandler('/html-error', (request) async {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..headers.contentType = ContentType.html
            ..write('<html><body><h1>Error</h1></body></html>');
          await request.response.close();
        });

        expect(
          () => client.get<void>('/html-error'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.serverError),
          ),
        );
      });
    });

    group('HttpError properties', () {
      test('should preserve original request in error', () async {
        server.addHandler(
          '/error-with-request',
          TestHttpServer.errorResponse(HttpStatus.badRequest),
        );

        try {
          await client.get<void>(
            '/error-with-request',
            queryParameters: {'foo': 'bar'},
            headers: {'X-Custom': 'value'},
          );
          fail('Should have thrown');
        } on HttpError catch (e) {
          expect(e.request, isNotNull);
          expect(e.request.path, equals('/error-with-request'));
          expect(e.request.method, equals(HttpMethod.get));
        }
      });

      test('should have stack trace', () async {
        server.addHandler(
          '/error-stack',
          TestHttpServer.errorResponse(HttpStatus.badRequest),
        );

        try {
          await client.get<void>('/error-stack');
          fail('Should have thrown');
        } on HttpError catch (e) {
          expect(e.stackTrace, isNotNull);
        }
      });

      test('should have cause (original Dio exception)', () async {
        server.addHandler(
          '/error-cause',
          TestHttpServer.errorResponse(HttpStatus.badRequest),
        );

        try {
          await client.get<void>('/error-cause');
          fail('Should have thrown');
        } on HttpError catch (e) {
          expect(e.cause, isNotNull);
        }
      });
    });

    group('Connection errors', () {
      test('should handle connection to non-existent server', () async {
        final badClient = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: Uri.parse('http://127.0.0.1:59999'), // Non-existent port
            connectTimeout: const Duration(seconds: 1),
          ),
        );
        await badClient.initialize();

        try {
          expect(
            () => badClient.get<void>('/test'),
            throwsA(isA<HttpError>()),
          );
        } finally {
          await badClient.dispose();
        }
      });
    });

    group('Custom validateStatus', () {
      test('should treat 201 as error when validateStatus returns false',
          () async {
        final strictClient = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            validateStatus: (status) => status == 200, // Only 200 is success
          ),
        );
        await strictClient.initialize();

        server.addHandler(
          '/created',
          TestHttpServer.jsonResponse({'id': 1}, statusCode: HttpStatus.created),
        );

        try {
          expect(
            () => strictClient.get<void>('/created'),
            throwsA(
              isA<HttpError>()
                  .having((e) => e.response?.statusCode, 'statusCode', 201),
            ),
          );
        } finally {
          await strictClient.dispose();
        }
      });

      test('should treat 404 as success when validateStatus returns true',
          () async {
        final lenientClient = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            validateStatus: (status) => status < 500, // All non-5xx is success
          ),
        );
        await lenientClient.initialize();

        server.addHandler(
          '/not-found',
          TestHttpServer.jsonResponse(
            {'error': 'Not Found'},
            statusCode: HttpStatus.notFound,
          ),
        );

        try {
          final response = await lenientClient.get<Map<String, dynamic>>(
            '/not-found',
            decoder: (data) => data as Map<String, dynamic>,
          );

          expect(response.statusCode, equals(404));
          expect(response.data?['error'], equals('Not Found'));
        } finally {
          await lenientClient.dispose();
        }
      });
    });
  });
}
