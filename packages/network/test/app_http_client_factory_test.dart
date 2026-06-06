import 'dart:async';
import 'dart:io';

import 'package:abstract_http_client/abstract_http_client.dart' as http;
import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_network/clean_disk_network.dart';
import 'package:test/test.dart';

void main() {
  test('creates Dio config from app environment', () {
    final environment = AppEnvironment(
      flavor: AppFlavor.staging,
      apiBaseUri: Uri.parse('https://api.example.test'),
    );

    final config = AppHttpClientFactory(
      environment: environment,
      connectTimeout: const Duration(seconds: 1),
      receiveTimeout: const Duration(seconds: 2),
      sendTimeout: const Duration(seconds: 3),
    ).createConfig();

    expect(config.baseUrl, environment.apiBaseUri);
    expect(config.connectTimeout, const Duration(seconds: 1));
    expect(config.receiveTimeout, const Duration(seconds: 2));
    expect(config.sendTimeout, const Duration(seconds: 3));
    expect(config.defaultHeaders['Accept'], 'application/json');
    expect(config.enableLogging, isTrue);
  });

  test('disables network logging in production', () {
    final environment = AppEnvironment(
      flavor: AppFlavor.production,
      apiBaseUri: Uri.parse('https://api.example.test'),
    );

    final config = AppHttpClientFactory(
      environment: environment,
    ).createConfig();

    expect(config.enableLogging, isFalse);
  });

  test('attaches Authorization header from token store', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final StreamSubscription<HttpRequest> subscription;
    String? authorizationHeader;

    subscription = server.listen((request) async {
      authorizationHeader = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok');
      await request.response.close();
    });

    final tokenStore = http.InMemoryTokenStore(
      const http.TokenPair(accessToken: 'access-token'),
    );
    final client = await AppHttpClientFactory(
      environment: AppEnvironment(
        flavor: AppFlavor.production,
        apiBaseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      ),
      tokenStore: tokenStore,
    ).createInitialized();

    addTearDown(() async {
      await client.dispose();
      await tokenStore.dispose();
      await subscription.cancel();
      await server.close(force: true);
    });

    await client.get<String>('/scan', decoder: (data) => data as String);

    expect(authorizationHeader, 'Bearer access-token');
  });
}
