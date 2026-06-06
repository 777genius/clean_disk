import 'dart:async';
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
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    await client.initialize();
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('Cancel Token E2E', () {
    group('Basic cancellation', () {
      test('should cancel request before it completes', () async {
        final cancelToken = CancelToken();

        server.addHandler(
          '/slow',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );

        final future = client.get<void>('/slow', cancelToken: cancelToken);

        // Give the request a moment to start
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Cancel the request
        cancelToken.cancel('User cancelled');

        expect(
          future,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });

      test('should cancel request immediately if token already cancelled',
          () async {
        final cancelToken = CancelToken();
        cancelToken.cancel('Pre-cancelled');

        server.addHandler('/test', TestHttpServer.jsonResponse({'ok': true}));

        expect(
          () => client.get<void>('/test', cancelToken: cancelToken),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });

      test('should include cancel reason in error', () async {
        final cancelToken = CancelToken();

        server.addHandler(
          '/slow',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );

        final future = client.get<void>('/slow', cancelToken: cancelToken);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        cancelToken.cancel('Network changed');

        try {
          await future;
          fail('Should have thrown');
        } on HttpError catch (e) {
          expect(e.type, equals(HttpErrorType.cancelled));
          // The cancel reason may be in message or cause
          expect(
            e.message?.contains('Network changed') == true ||
                e.cause.toString().contains('Network changed'),
            isTrue,
          );
        }
      });
    });

    group('Multiple requests with same token', () {
      test('should cancel all requests using the same token', () async {
        final cancelToken = CancelToken();

        server.addHandler(
          '/slow1',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );
        server.addHandler(
          '/slow2',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );
        server.addHandler(
          '/slow3',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );

        final futures = [
          client.get<void>('/slow1', cancelToken: cancelToken),
          client.get<void>('/slow2', cancelToken: cancelToken),
          client.get<void>('/slow3', cancelToken: cancelToken),
        ];

        await Future<void>.delayed(const Duration(milliseconds: 50));
        cancelToken.cancel();

        for (final future in futures) {
          expect(
            future,
            throwsA(
              isA<HttpError>()
                  .having((e) => e.type, 'type', HttpErrorType.cancelled),
            ),
          );
        }
      });
    });

    group('Cancellation timing', () {
      test('should not affect completed request', () async {
        final cancelToken = CancelToken();

        server.addHandler('/fast', TestHttpServer.jsonResponse({'ok': true}));

        // Complete the request first
        final response = await client.get<Map<String, dynamic>>(
          '/fast',
          cancelToken: cancelToken,
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['ok'], isTrue);

        // Cancel after completion (should have no effect)
        cancelToken.cancel();

        // Token is cancelled but request already completed
        expect(cancelToken.isCancelled, isTrue);
      });

      test('should cancel request during response transfer', () async {
        final cancelToken = CancelToken();
        final requestStarted = Completer<void>();

        server.addHandler('/streaming', (request) async {
          requestStarted.complete();
          // Start sending response but delay
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"data": "');

          // Wait before completing (simulating slow transfer)
          await Future<void>.delayed(const Duration(seconds: 2));

          request.response.write('value"}');
          await request.response.close();
        });

        final future = client.get<void>('/streaming', cancelToken: cancelToken);

        // Wait for request to start
        await requestStarted.future;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Cancel during transfer
        cancelToken.cancel();

        expect(
          future,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });
    });

    group('Token state', () {
      test('should report isCancelled correctly', () async {
        final cancelToken = CancelToken();

        expect(cancelToken.isCancelled, isFalse);

        cancelToken.cancel();

        expect(cancelToken.isCancelled, isTrue);
      });

      test('should report cancelException after cancellation', () async {
        final cancelToken = CancelToken();

        expect(cancelToken.cancelException, isNull);

        cancelToken.cancel('Test reason');

        expect(cancelToken.cancelException, isNotNull);
        expect(cancelToken.cancelException?.message, equals('Test reason'));
      });

      test('should ignore multiple cancel calls', () async {
        final cancelToken = CancelToken();

        cancelToken.cancel('First');
        cancelToken.cancel('Second');
        cancelToken.cancel('Third');

        // First cancel reason should be preserved
        expect(cancelToken.cancelException?.message, equals('First'));
      });
    });

    group('Concurrent operations', () {
      test('should handle rapid cancel during request start', () async {
        final cancelToken = CancelToken();

        server.addHandler('/test', TestHttpServer.jsonResponse({'ok': true}));

        // Start request and cancel immediately
        final future = client.get<void>('/test', cancelToken: cancelToken);
        cancelToken.cancel();

        expect(
          future,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });

      test('should handle different tokens for different requests', () async {
        final token1 = CancelToken();
        final token2 = CancelToken();

        server.addHandler(
          '/slow1',
          TestHttpServer.delayedResponse(const Duration(seconds: 5)),
        );
        server.addHandler('/fast', TestHttpServer.jsonResponse({'ok': true}));

        final slowFuture = client.get<void>('/slow1', cancelToken: token1);
        final fastFuture = client.get<Map<String, dynamic>>(
          '/fast',
          cancelToken: token2,
          decoder: (data) => data as Map<String, dynamic>,
        );

        // Cancel only the slow request
        await Future<void>.delayed(const Duration(milliseconds: 50));
        token1.cancel();

        // Slow request should be cancelled
        expect(
          slowFuture,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );

        // Fast request should complete normally
        final response = await fastFuture;
        expect(response.data?['ok'], isTrue);
      });
    });

    group('Cancel with listeners', () {
      test('should notify listeners on cancellation', () async {
        final cancelToken = CancelToken();
        var listenerCalled = false;

        cancelToken.addListener(() {
          listenerCalled = true;
        });

        cancelToken.cancel();

        expect(listenerCalled, isTrue);
      });

      test('should call listener immediately if already cancelled', () async {
        final cancelToken = CancelToken();
        cancelToken.cancel();

        var listenerCalled = false;
        cancelToken.addListener(() {
          listenerCalled = true;
        });

        // Listener should be called immediately since token is already cancelled
        expect(listenerCalled, isTrue);
      });

      test('should support multiple listeners', () async {
        final cancelToken = CancelToken();
        var count = 0;

        cancelToken.addListener(() => count++);
        cancelToken.addListener(() => count++);
        cancelToken.addListener(() => count++);

        cancelToken.cancel();

        expect(count, equals(3));
      });

      test('should allow removing listeners', () async {
        final cancelToken = CancelToken();
        var called = false;

        void listener() {
          called = true;
        }

        cancelToken.addListener(listener);
        cancelToken.removeListener(listener);

        cancelToken.cancel();

        expect(called, isFalse);
      });
    });

    group('POST/PUT with cancel', () {
      test('should cancel POST request during body upload', () async {
        final cancelToken = CancelToken();
        final requestReceived = Completer<void>();

        server.addHandler('/upload', (request) async {
          requestReceived.complete();
          // Delay response to allow cancellation
          await Future<void>.delayed(const Duration(seconds: 5));
          await request.response.json({'uploaded': true});
        });

        final future = client.post<void>(
          '/upload',
          body: JsonBody({'large': 'data' * 1000}),
          cancelToken: cancelToken,
        );

        await requestReceived.future;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        cancelToken.cancel();

        expect(
          future,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });
    });
  });
}
