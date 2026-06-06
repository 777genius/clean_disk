import 'package:abstract_http_client/abstract_http_client.dart';

final class DeferredHttpClient extends HttpClient {
  DeferredHttpClient({
    required HttpClientConfig config,
    required Future<HttpClient> client,
  }) : _config = config,
       _clientFuture = client;

  final HttpClientConfig _config;
  final Future<HttpClient> _clientFuture;
  HttpClient? _client;

  @override
  HttpClientConfig get config => _config;

  @override
  bool get isInitialized => _client?.isInitialized ?? false;

  @override
  Future<void> initialize() async {
    await _resolveClient();
  }

  @override
  Future<void> dispose() async {
    final client = _client;
    if (client == null) {
      return;
    }
    await client.dispose();
  }

  @override
  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  }) async {
    final client = await _resolveClient();
    return client.send<T>(request, decoder: decoder, cancelToken: cancelToken);
  }

  Future<HttpClient> _resolveClient() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }
    final client = await _clientFuture;
    _client = client;
    return client;
  }
}
