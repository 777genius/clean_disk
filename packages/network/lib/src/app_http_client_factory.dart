import 'package:abstract_http_client/abstract_http_client.dart' as http;
import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:dio_http_client/dio_http_client.dart'
    show DioHttpClient, DioHttpClientConfig;

final class AppHttpClientFactory {
  const AppHttpClientFactory({
    required AppEnvironment environment,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 20),
    Duration sendTimeout = const Duration(seconds: 12),
    http.TokenStore? tokenStore,
  }) : _environment = environment,
       _connectTimeout = connectTimeout,
       _receiveTimeout = receiveTimeout,
       _sendTimeout = sendTimeout,
       _tokenStore = tokenStore;

  final AppEnvironment _environment;
  final Duration _connectTimeout;
  final Duration _receiveTimeout;
  final Duration _sendTimeout;
  final http.TokenStore? _tokenStore;

  DioHttpClientConfig createConfig() {
    return DioHttpClientConfig(
      baseUrl: _environment.apiBaseUri,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      sendTimeout: _sendTimeout,
      defaultHeaders: const {'Accept': 'application/json'},
      enableLogging: !_environment.isProduction,
    );
  }

  http.HttpClient create() {
    return DioHttpClient(config: createConfig(), tokenStore: _tokenStore);
  }

  Future<http.HttpClient> createInitialized() async {
    final client = create();
    await client.initialize();
    return client;
  }
}
