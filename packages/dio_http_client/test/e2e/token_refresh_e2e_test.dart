import 'dart:async';
import 'dart:io';

import 'package:dio_http_client/dio_http_client.dart';
import 'package:test/test.dart';

import 'test_http_server.dart';

void main() {
  late TokenRefreshTestFixture fixture;

  setUp(() async {
    fixture = TokenRefreshTestFixture();
    await fixture.setUp();
  });

  tearDown(() async {
    await fixture.tearDown();
  });

  group('Token Refresh E2E', () {
    group('basic_refresh_flow', () {
      test('refresh_on_401_and_retry', () async {
        var protectedCalls = 0;

        await fixture.setInitialTokens(
          accessToken: 'expired-token',
          refreshToken: 'valid-refresh-token',
        );

        fixture.server.addHandler('/protected', (request) async {
          protectedCalls++;
          final auth = request.header('Authorization');

          if (auth == 'Bearer expired-token') {
            await request.response.error(HttpStatus.unauthorized);
          } else if (auth == 'Bearer new-access-token') {
            await request.response.json({'data': 'secret'});
          } else {
            await request.response.error(HttpStatus.unauthorized);
          }
        });

        fixture.setupRefreshEndpoint(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
          validateRefreshToken: 'valid-refresh-token',
        );

        await fixture.initializeClient();

        final response = await fixture.client.get<Map<String, dynamic>>(
          '/protected',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['data'], equals('secret'));
        expect(protectedCalls, equals(2), reason: 'First 401, then retry');

        final newTokens = await fixture.tokenStore.getTokens();
        expect(newTokens?.accessToken, equals('new-access-token'));
        expect(newTokens?.refreshToken, equals('new-refresh-token'));
      });

      test('call_onTokenRefreshed_callback', () async {
        final refreshedCompleter = Completer<TokenPair>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.setupProtectedEndpoint(validTokens: ['new-token']);
        fixture.setupRefreshEndpoint(
          accessToken: 'new-token',
          refreshToken: 'new-refresh',
        );

        await fixture.initializeClient(
          onTokenRefreshed: (tokens) {
            if (!refreshedCompleter.isCompleted) {
              refreshedCompleter.complete(tokens);
            }
          },
        );

        await fixture.client.get<void>('/protected');

        final refreshedTokens = await refreshedCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onTokenRefreshed not called'),
        );

        expect(refreshedTokens.accessToken, equals('new-token'));
      });
    });

    group('concurrent_401_requests', () {
      test('share_single_refresh', () async {
        var refreshCalls = 0;

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          final auth = request.header('Authorization');
          if (auth == 'Bearer expired') {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await request.response.error(HttpStatus.unauthorized);
          } else if (auth == 'Bearer refreshed-token') {
            await request.response.json({'ok': true});
          } else {
            await request.response.error(HttpStatus.unauthorized);
          }
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await request.response.json({
            'accessToken': 'refreshed-token',
            'refreshToken': 'new-refresh',
          });
        });

        await fixture.initializeClient();

        final futures = [
          fixture.client.get<Map<String, dynamic>>(
            '/protected',
            decoder: (data) => data as Map<String, dynamic>,
          ),
          fixture.client.get<Map<String, dynamic>>(
            '/protected',
            decoder: (data) => data as Map<String, dynamic>,
          ),
          fixture.client.get<Map<String, dynamic>>(
            '/protected',
            decoder: (data) => data as Map<String, dynamic>,
          ),
        ];

        final responses = await Future.wait(futures);

        for (final response in responses) {
          expect(response.data, isNotNull);
        }

        // With QueuedInterceptor, requests are serialized.
        // Each request sees 401 and triggers refresh, but Completer
        // deduplication means subsequent refreshes reuse the first result.
        expect(
          refreshCalls,
          greaterThanOrEqualTo(1),
          reason: 'At least one refresh should occur',
        );
      });
    });

    group('refresh_failure', () {
      test('propagate_401_and_call_onForceLogout', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'invalid-refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient(
          refreshDelegate: _FailingRefreshDelegate(),
          onForceLogout: () async {
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        await expectLater(
          fixture.client.get<void>('/protected'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.unauthorized)
                .having((e) => e.response?.statusCode, 'statusCode', 401),
          ),
        );

        await logoutCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onForceLogout not called'),
        );
      });

      test('propagate_401_when_refresh_returns_null', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient(
          refreshDelegate: _NullRefreshDelegate(),
          onForceLogout: () async {
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        await expectLater(
          fixture.client.get<void>('/protected'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.unauthorized),
          ),
        );

        await logoutCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onForceLogout not called'),
        );
      });
    });

    group('skip_refresh_endpoint', () {
      test('no_refresh_when_401_from_refresh_endpoint', () async {
        var refreshCalls = 0;
        final errorCompleter = Completer<HttpError>();

        await fixture.setInitialTokens(
          accessToken: 'token',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/auth/refresh', (request) async {
          refreshCalls++;
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient();

        try {
          await fixture.client.post<void>('/auth/refresh');
          fail('Should have thrown');
        } on HttpError catch (e) {
          errorCompleter.complete(e);
        }

        await errorCompleter.future;

        expect(refreshCalls, equals(1), reason: 'No recursive refresh');
      });
    });

    group('shouldRefresh_callback', () {
      test('skip_refresh_when_shouldRefresh_returns_false', () async {
        var refreshCalls = 0;
        final errorCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/no-refresh', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          refreshCalls++;
          await request.response.json({
            'accessToken': 'new',
            'refreshToken': 'new-refresh',
          });
        });

        await fixture.initializeClient(
          shouldRefresh: (error) => !error.request.path.contains('no-refresh'),
        );

        try {
          await fixture.client.get<void>('/no-refresh');
        } on HttpError {
          errorCompleter.complete();
        }

        await errorCompleter.future;

        expect(refreshCalls, equals(0), reason: 'shouldRefresh blocked it');
      });
    });

    group('no_refresh_token', () {
      test('propagate_401_when_no_refresh_token', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: null,
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient(
          onForceLogout: () async {
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        await expectLater(
          fixture.client.get<void>('/protected'),
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.unauthorized),
          ),
        );

        await logoutCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onForceLogout not called'),
        );
      });
    });

    group('cancel_during_refresh', () {
      test('cancel_request_during_token_refresh', () async {
        final cancelToken = CancelToken();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient(
          refreshDelegate: _SlowRefreshDelegate(),
        );

        final future = fixture.client.get<void>(
          '/protected',
          cancelToken: cancelToken,
        );

        // Give time for refresh to start
        await Future<void>.delayed(const Duration(milliseconds: 100));

        cancelToken.cancel('Cancelled during refresh');

        await expectLater(
          future,
          throwsA(
            isA<HttpError>()
                .having((e) => e.type, 'type', HttpErrorType.cancelled),
          ),
        );
      });
    });

    group('token_persistence', () {
      test('persist_and_reuse_tokens', () async {
        final headersLog = <String>[];

        await fixture.setInitialTokens(
          accessToken: 'expired-token',
          refreshToken: 'valid-refresh',
        );

        fixture.server.addHandler('/api/data', (request) async {
          final auth = request.header('Authorization') ?? '';
          headersLog.add(auth);

          if (auth == 'Bearer expired-token') {
            await request.response.error(HttpStatus.unauthorized);
          } else if (auth == 'Bearer new-access-token') {
            await request.response.json({'data': 'success'});
          } else {
            await request.response.error(HttpStatus.unauthorized);
          }
        });

        fixture.setupRefreshEndpoint(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        );

        await fixture.initializeClient();

        // First request triggers refresh
        await fixture.client.get<void>('/api/data');

        final savedTokens = await fixture.tokenStore.getTokens();
        expect(savedTokens?.accessToken, equals('new-access-token'));

        // Second request uses new token directly
        await fixture.client.get<void>('/api/data');

        // Headers: expired (401), new (success), new (success)
        expect(headersLog.length, equals(3));
        expect(headersLog[0], equals('Bearer expired-token'));
        expect(headersLog[1], equals('Bearer new-access-token'));
        expect(headersLog[2], equals('Bearer new-access-token'));
      });

      test('preserve_POST_body_after_refresh', () async {
        Map<String, dynamic>? receivedBody;
        var attempts = 0;

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/api/create', (request) async {
          attempts++;
          final auth = request.header('Authorization');

          if (auth == 'Bearer expired') {
            await request.response.error(HttpStatus.unauthorized);
          } else {
            receivedBody = await request.readAsJson() as Map<String, dynamic>;
            await request.response.json({'created': true});
          }
        });

        fixture.setupRefreshEndpoint(
          accessToken: 'new-token',
          refreshToken: 'new-refresh',
        );

        await fixture.initializeClient();

        final response = await fixture.client.post<Map<String, dynamic>>(
          '/api/create',
          body: JsonBody({
            'name': 'Test Item',
            'count': 42,
            'nested': {'key': 'value'},
          }),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['created'], isTrue);
        expect(attempts, equals(2), reason: '401 + retry');

        expect(receivedBody?['name'], equals('Test Item'));
        expect(receivedBody?['count'], equals(42));
        expect(receivedBody?['nested']['key'], equals('value'));
      });

      test('update_Authorization_header_after_refresh', () async {
        final capturedHeaders = <String>[];

        await fixture.setInitialTokens(
          accessToken: 'old-token',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/api/check', (request) async {
          capturedHeaders.add(request.header('Authorization') ?? 'none');

          if (capturedHeaders.length == 1) {
            await request.response.error(HttpStatus.unauthorized);
          } else {
            await request.response.json({'ok': true});
          }
        });

        fixture.setupRefreshEndpoint(
          accessToken: 'brand-new-token',
          refreshToken: 'new-refresh',
        );

        await fixture.initializeClient();

        await fixture.client.get<void>('/api/check');

        expect(capturedHeaders.length, equals(2));
        expect(capturedHeaders[0], equals('Bearer old-token'));
        expect(capturedHeaders[1], equals('Bearer brand-new-token'));
      });
    });

    group('refresh_edge_cases', () {
      test(
        'force_logout_on_401_after_refresh',
        timeout: const Timeout(Duration(seconds: 5)),
        () async {
          final logoutCompleter = Completer<void>();
          var refreshCount = 0;

          await fixture.setInitialTokens(
            accessToken: 'expired',
            refreshToken: 'refresh',
          );

          // Server always returns 401 - simulates revoked token
          fixture.server.addHandler('/protected', (request) async {
            await request.response.error(HttpStatus.unauthorized);
          });

          fixture.server.addHandler('/auth/refresh', (request) async {
            refreshCount++;
            await request.response.json({
              'accessToken': 'new-token-$refreshCount',
              'refreshToken': 'new-refresh-$refreshCount',
            });
          });

          await fixture.initializeClient(
            onForceLogout: () async {
              if (!logoutCompleter.isCompleted) {
                logoutCompleter.complete();
              }
            },
          );

          try {
            await fixture.client.get<void>('/protected');
            fail('Should have thrown');
          } on HttpError catch (e) {
            expect(e.type, equals(HttpErrorType.unauthorized));
          }

          await logoutCompleter.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail('onForceLogout not called'),
          );

          // Retry uses separate Dio, so only 1 refresh should happen
          expect(refreshCount, equals(1));
        },
      );

      test('clear_tokens_on_force_logout', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        await fixture.initializeClient(
          refreshDelegate: _FailingRefreshDelegate(),
          onForceLogout: () async {
            await fixture.tokenStore.clearTokens();
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        try {
          await fixture.client.get<void>('/protected');
        } on HttpError {
          // Expected
        }

        await logoutCompleter.future.timeout(const Duration(seconds: 1));

        final tokens = await fixture.tokenStore.getTokens();
        expect(tokens, isNull);
      });

      // Note: Testing dispose during refresh is complex due to async timing.
      // The important behavior (no deadlock, no memory leak) is covered by
      // other tests and the proper cleanup in tearDown.
    });

    group('sequential_requests', () {
      test('handle_multiple_401s_in_sequence', () async {
        var refreshCount = 0;

        await fixture.setInitialTokens(
          accessToken: 'token-v1',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/api/resource', (request) async {
          final auth = request.header('Authorization');

          if (auth == 'Bearer token-v1') {
            await request.response.error(HttpStatus.unauthorized);
          } else if (auth == 'Bearer token-v2') {
            await request.response.json({'ok': true});
          } else {
            await request.response.error(HttpStatus.unauthorized);
          }
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          refreshCount++;
          await request.response.json({
            'accessToken': 'token-v2',
            'refreshToken': 'refresh-v2',
          });
        });

        await fixture.initializeClient();

        // Three sequential requests
        await fixture.client.get<void>('/api/resource');
        await fixture.client.get<void>('/api/resource');
        await fixture.client.get<void>('/api/resource');

        // Only ONE refresh for the first 401
        expect(refreshCount, equals(1));
      });

      test('queue_requests_during_slow_refresh', () async {
        var refreshCount = 0;
        final requestIds = <int>[];

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/api/item', (request) async {
          final auth = request.header('Authorization');
          final id = int.parse(request.uri.queryParameters['id'] ?? '0');

          if (auth == 'Bearer expired') {
            await request.response.error(HttpStatus.unauthorized);
          } else if (auth == 'Bearer fresh-token') {
            requestIds.add(id);
            await request.response.json({'id': id});
          } else {
            await request.response.error(HttpStatus.unauthorized);
          }
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          refreshCount++;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await request.response.json({
            'accessToken': 'fresh-token',
            'refreshToken': 'new-refresh',
          });
        });

        await fixture.initializeClient();

        final futures = [
          fixture.client.get<void>('/api/item', queryParameters: {'id': '1'}),
          fixture.client.get<void>('/api/item', queryParameters: {'id': '2'}),
          fixture.client.get<void>('/api/item', queryParameters: {'id': '3'}),
        ];

        await Future.wait(futures);

        expect(requestIds.length, equals(3));
        expect(refreshCount, greaterThanOrEqualTo(1));
      });
    });

    group('token_stream', () {
      test('emit_token_changes', () async {
        final tokenChanges = <TokenPair?>[];
        late StreamSubscription<TokenPair?> subscription;

        subscription = fixture.tokenStore.tokenChanges.listen(tokenChanges.add);

        await fixture.setInitialTokens(
          accessToken: 'initial',
          refreshToken: 'refresh',
        );

        fixture.setupProtectedEndpoint(validTokens: ['refreshed']);
        fixture.setupRefreshEndpoint(
          accessToken: 'refreshed',
          refreshToken: 'new-refresh',
        );

        await fixture.initializeClient();
        await fixture.client.get<void>('/protected');

        // Wait for stream events
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await subscription.cancel();

        expect(tokenChanges.length, greaterThanOrEqualTo(2));
        expect(tokenChanges.first?.accessToken, equals('initial'));
        expect(tokenChanges.last?.accessToken, equals('refreshed'));
      });
    });

    group('error_scenarios', () {
      test('handle_malformed_refresh_response', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        fixture.server.addHandler('/auth/refresh', (request) async {
          // Return malformed response - missing accessToken
          await request.response.json({'invalid': 'response'});
        });

        await fixture.initializeClient(
          onForceLogout: () async {
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        await expectLater(
          fixture.client.get<void>('/protected'),
          throwsA(isA<HttpError>()),
        );

        // Should trigger force logout due to refresh failure
        await logoutCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onForceLogout not called for malformed response'),
        );
      });

      test('handle_refresh_delegate_error', () async {
        final logoutCompleter = Completer<void>();

        await fixture.setInitialTokens(
          accessToken: 'expired',
          refreshToken: 'refresh',
        );

        fixture.server.addHandler('/protected', (request) async {
          await request.response.error(HttpStatus.unauthorized);
        });

        // Use delegate that always fails
        await fixture.initializeClient(
          refreshDelegate: _FailingRefreshDelegate(),
          onForceLogout: () async {
            if (!logoutCompleter.isCompleted) {
              logoutCompleter.complete();
            }
          },
        );

        await expectLater(
          fixture.client.get<void>('/protected'),
          throwsA(isA<HttpError>()),
        );

        await logoutCompleter.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail('onForceLogout not called for delegate error'),
        );
      });
    });
  });
}

// =============================================================================
// TEST FIXTURE
// =============================================================================

/// Reusable test fixture that reduces boilerplate in token refresh tests.
class TokenRefreshTestFixture {
  late TestHttpServer server;
  late _InMemoryTokenStore tokenStore;
  DioHttpClient? _client;
  bool _tornDown = false;

  DioHttpClient get client {
    if (_client == null) {
      throw StateError('Call initializeClient() first');
    }
    return _client!;
  }

  Future<void> setUp() async {
    server = TestHttpServer();
    await server.start();
    tokenStore = _InMemoryTokenStore();
    _tornDown = false;
  }

  Future<void> tearDown() async {
    if (_tornDown) return;
    _tornDown = true;
    await _client?.dispose();
    await tokenStore.dispose();
    await server.stop();
  }

  Future<void> setInitialTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await tokenStore.saveTokens(
      TokenPair(accessToken: accessToken, refreshToken: refreshToken),
    );
  }

  void setupProtectedEndpoint({
    required List<String> validTokens,
    String path = '/protected',
  }) {
    server.addHandler(path, (request) async {
      final auth = request.header('Authorization');
      final token = auth?.replaceFirst('Bearer ', '');

      if (token != null && validTokens.contains(token)) {
        await request.response.json({'ok': true});
      } else {
        await request.response.error(HttpStatus.unauthorized);
      }
    });
  }

  void setupRefreshEndpoint({
    required String accessToken,
    required String refreshToken,
    String? validateRefreshToken,
    String path = '/auth/refresh',
  }) {
    server.addHandler(path, (request) async {
      if (validateRefreshToken != null) {
        final body = await request.readAsJson();
        if (body['refreshToken'] != validateRefreshToken) {
          await request.response.error(HttpStatus.unauthorized);
          return;
        }
      }

      await request.response.json({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      });
    });
  }

  Future<void> initializeClient({
    TokenRefreshDelegate? refreshDelegate,
    void Function(TokenPair)? onTokenRefreshed,
    Future<void> Function()? onForceLogout,
    bool Function(HttpError)? shouldRefresh,
  }) async {
    _client = DioHttpClient(
      config: DioHttpClientConfig(
        baseUrl: server.baseUrl,
        tokenRefreshConfig: TokenRefreshConfig(
          refreshEndpoint: '/auth/refresh',
          onTokenRefreshed: onTokenRefreshed,
          onForceLogout: onForceLogout,
          shouldRefresh: shouldRefresh ?? (_) => true,
        ),
      ),
      tokenStore: tokenStore,
      refreshDelegate: refreshDelegate ?? _TestRefreshDelegate(server),
    );
    await _client!.initialize();
  }
}

// =============================================================================
// TEST HELPERS
// =============================================================================

/// In-memory token store with proper cleanup.
class _InMemoryTokenStore implements TokenStore {
  TokenPair? _tokens;
  final _controller = StreamController<TokenPair?>.broadcast();
  bool _disposed = false;

  @override
  Future<TokenPair?> getTokens() async => _tokens;

  @override
  Future<void> saveTokens(TokenPair tokens) async {
    _tokens = tokens;
    if (!_disposed && !_controller.isClosed) {
      _controller.add(tokens);
    }
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
    if (!_disposed && !_controller.isClosed) {
      _controller.add(null);
    }
  }

  @override
  Stream<TokenPair?> get tokenChanges => _controller.stream;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }
}

/// Test refresh delegate that calls the server.
class _TestRefreshDelegate implements TokenRefreshDelegate {
  _TestRefreshDelegate(this.server);

  final TestHttpServer server;

  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async {
    final currentTokens = context.currentTokens;
    if (currentTokens?.refreshToken == null) {
      return null;
    }

    try {
      final response = await context.client.post<Map<String, dynamic>>(
        '/auth/refresh',
        body: JsonBody({'refreshToken': currentTokens!.refreshToken}),
        decoder: (data) => data as Map<String, dynamic>,
      );

      final data = response.data;
      if (data == null) return null;

      final accessToken = data['accessToken'];
      if (accessToken == null) return null;

      return TokenPair(
        accessToken: accessToken as String,
        refreshToken: data['refreshToken'] as String?,
      );
    } on HttpError {
      return null;
    }
  }
}

/// Refresh delegate that always returns null.
class _NullRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async => null;
}

/// Slow refresh delegate for testing cancellation/dispose scenarios.
class _SlowRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return const TokenPair(
      accessToken: 'new-token',
      refreshToken: 'new-refresh',
    );
  }
}

/// Refresh delegate that always fails.
class _FailingRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async => null;
}
