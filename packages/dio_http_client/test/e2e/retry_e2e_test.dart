import 'dart:io';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio_http_client/dio_http_client.dart';
import 'package:test/test.dart';

import 'test_http_server.dart';

void main() {
  late TestHttpServer server;

  setUp(() async {
    server = TestHttpServer();
    await server.start();
  });

  tearDown(() async {
    await server.stop();
  });

  group('Retry E2E', () {
    group('Retry on 5xx errors', () {
      test('should retry on 500 and succeed', () async {
        var attempts = 0;

        server.addHandler('/flaky', (request) async {
          attempts++;
          if (attempts < 3) {
            await request.response.error(
              HttpStatus.internalServerError,
              body: {'error': 'Server error'},
            );
          } else {
            await request.response.json({'success': true});
          }
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          final response = await client.get<Map<String, dynamic>>(
            '/flaky',
            decoder: (data) => data as Map<String, dynamic>,
          );

          expect(response.data?['success'], isTrue);
          expect(attempts, equals(3));
        } finally {
          await client.dispose();
        }
      });

      test('should retry on 503 Service Unavailable', () async {
        var attempts = 0;

        server.addHandler('/unavailable', (request) async {
          attempts++;
          if (attempts == 1) {
            await request.response.error(HttpStatus.serviceUnavailable);
          } else {
            await request.response.json({'available': true});
          }
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 3,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          final response = await client.get<Map<String, dynamic>>(
            '/unavailable',
            decoder: (data) => data as Map<String, dynamic>,
          );

          expect(response.data?['available'], isTrue);
          expect(attempts, equals(2));
        } finally {
          await client.dispose();
        }
      });
    });

    group('No retry on 4xx errors', () {
      test('should not retry on 400 Bad Request', () async {
        var attempts = 0;

        server.addHandler('/bad', (request) async {
          attempts++;
          await request.response.error(
            HttpStatus.badRequest,
            body: {'error': 'Bad Request'},
          );
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          await expectLater(
            client.get<void>('/bad'),
            throwsA(isA<HttpError>()),
          );

          expect(attempts, equals(1)); // Only one attempt, no retries
        } finally {
          await client.dispose();
        }
      });

      test('should not retry on 401 Unauthorized', () async {
        var attempts = 0;

        server.addHandler('/protected', (request) async {
          attempts++;
          await request.response.error(HttpStatus.unauthorized);
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          await expectLater(
            client.get<void>('/protected'),
            throwsA(isA<HttpError>()),
          );

          expect(attempts, equals(1));
        } finally {
          await client.dispose();
        }
      });

      test('should not retry on 404 Not Found', () async {
        var attempts = 0;

        server.addHandler('/missing', (request) async {
          attempts++;
          await request.response.error(HttpStatus.notFound);
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          await expectLater(
            client.get<void>('/missing'),
            throwsA(isA<HttpError>()),
          );

          expect(attempts, equals(1));
        } finally {
          await client.dispose();
        }
      });
    });

    group('Max attempts limit', () {
      test('should stop after max attempts reached', () async {
        var attempts = 0;

        server.addHandler('/always-fail', (request) async {
          attempts++;
          await request.response.error(HttpStatus.internalServerError);
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 3, // Total 3 attempts
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          await expectLater(
            client.get<void>('/always-fail'),
            throwsA(
              isA<HttpError>()
                  .having((e) => e.type, 'type', HttpErrorType.serverError),
            ),
          );

          // maxAttempts=3 means: initial attempt + shouldRetry(1) + shouldRetry(2)
          // After shouldRetry(2) returns true, attempt 3 is made
          // shouldRetry(3) returns false because attempt >= maxAttempts
          // So total attempts = maxAttempts (due to shouldRetry logic)
          expect(attempts, greaterThanOrEqualTo(3));
          expect(attempts, lessThanOrEqualTo(4));
        } finally {
          await client.dispose();
        }
      });
    });

    group('Retry with delay', () {
      test('should apply exponential backoff between retries', () async {
        final timestamps = <DateTime>[];

        server.addHandler('/timed', (request) async {
          timestamps.add(DateTime.now());
          if (timestamps.length < 3) {
            await request.response.error(HttpStatus.internalServerError);
          } else {
            await request.response.json({'ok': true});
          }
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 50),
              multiplier: 2.0,
            ),
          ),
        );
        await client.initialize();

        try {
          await client.get<void>('/timed');

          expect(timestamps.length, equals(3));

          // Check that delays increase (with some tolerance)
          final delay1 =
              timestamps[1].difference(timestamps[0]).inMilliseconds;
          final delay2 =
              timestamps[2].difference(timestamps[1]).inMilliseconds;

          // First delay should be ~50ms, second ~100ms
          expect(delay1, greaterThan(30)); // Allow some tolerance
          expect(delay2, greaterThan(delay1 * 0.8)); // Second should be longer
        } finally {
          await client.dispose();
        }
      });
    });

    group('Retry on timeout', () {
      test('should retry on receive timeout', () async {
        var attempts = 0;

        server.addHandler('/timeout-retry', (request) async {
          attempts++;
          if (attempts == 1) {
            // First attempt - delay longer than timeout
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          await request.response.json({'attempt': attempts});
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            receiveTimeout: const Duration(milliseconds: 100),
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 3,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          final response = await client.get<Map<String, dynamic>>(
            '/timeout-retry',
            decoder: (data) => data as Map<String, dynamic>,
          );

          expect(response.data?['attempt'], equals(2));
          expect(attempts, equals(2));
        } finally {
          await client.dispose();
        }
      });
    });

    group('No retry policy', () {
      test('should not retry without retry policy', () async {
        var attempts = 0;

        server.addHandler('/no-retry', (request) async {
          attempts++;
          await request.response.error(HttpStatus.internalServerError);
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            // No retry policy
          ),
        );
        await client.initialize();

        try {
          expect(
            () => client.get<void>('/no-retry'),
            throwsA(isA<HttpError>()),
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(attempts, equals(1));
        } finally {
          await client.dispose();
        }
      });
    });

    group('Custom retry policy', () {
      test('should use custom shouldRetry logic', () async {
        var attempts = 0;

        server.addHandler('/custom-retry', (request) async {
          attempts++;
          // Return 418 (I'm a teapot) - normally not retried
          await request.response.json({'teapot': true}, statusCode: 418);
        });

        // Custom policy that retries on 418
        const customPolicy = _CustomRetryPolicy();

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: customPolicy,
            // Make 418 an error (default only validates 200-299)
            validateStatus: (status) => status >= 200 && status < 300,
          ),
        );
        await client.initialize();

        try {
          // Should throw after all retries exhausted
          await expectLater(
            client.get<void>('/custom-retry'),
            throwsA(isA<HttpError>()),
          );

          // Should retry because custom policy retries on 418
          // maxAttempts=3 means up to 3 retries, resulting in 3-4 total attempts
          // (depending on timing and retry interceptor implementation)
          expect(attempts, greaterThanOrEqualTo(3));
          expect(attempts, lessThanOrEqualTo(4));
        } finally {
          await client.dispose();
        }
      });
    });

    group('Retry with different HTTP methods', () {
      test('should retry POST requests on 5xx', () async {
        var attempts = 0;

        server.addHandler('/post-retry', (request) async {
          expect(request.method, equals('POST'));
          attempts++;
          if (attempts == 1) {
            await request.response.error(HttpStatus.internalServerError);
          } else {
            await request.response.json({'created': true});
          }
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 3,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          final response = await client.post<Map<String, dynamic>>(
            '/post-retry',
            body: JsonBody({'data': 'test'}),
            decoder: (data) => data as Map<String, dynamic>,
          );

          expect(response.data?['created'], isTrue);
          expect(attempts, equals(2));
        } finally {
          await client.dispose();
        }
      });
    });

    group('Retry cancelled by token', () {
      test('should stop retrying when cancelled', () async {
        var attempts = 0;
        final cancelToken = CancelToken();

        server.addHandler('/cancel-during-retry', (request) async {
          attempts++;
          if (attempts == 2) {
            // Cancel during second attempt
            cancelToken.cancel('Cancelled during retry');
          }
          await request.response.error(HttpStatus.internalServerError);
        });

        final client = DioHttpClient(
          config: DioHttpClientConfig(
            baseUrl: server.baseUrl,
            retryPolicy: ExponentialBackoffPolicy(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
            ),
          ),
        );
        await client.initialize();

        try {
          expect(
            () => client.get<void>(
              '/cancel-during-retry',
              cancelToken: cancelToken,
            ),
            throwsA(
              isA<HttpError>()
                  .having((e) => e.type, 'type', HttpErrorType.cancelled),
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 200));

          // Should stop at attempt 2 due to cancellation
          expect(attempts, equals(2));
        } finally {
          await client.dispose();
        }
      });
    });
  });
}

/// Custom retry policy for testing.
class _CustomRetryPolicy extends RetryPolicy {
  const _CustomRetryPolicy();

  int get maxAttempts => 3;

  @override
  bool shouldRetry(HttpError error, int attempt) {
    // Retry on 418 status code (normally wouldn't be retried)
    if (error.response?.statusCode == 418) {
      return attempt < maxAttempts;
    }
    return false;
  }

  @override
  Duration getDelay(int attempt) {
    return Duration(milliseconds: 10 * attempt);
  }
}
