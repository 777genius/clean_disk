import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken, ResponseDecoder;
import 'package:dio_http_client/src/client/dio_http_client_config.dart';
import 'package:dio_http_client/src/interceptors/dio_auth_interceptor.dart';
import 'package:dio_http_client/src/interceptors/dio_interceptor_adapter.dart';
import 'package:dio_http_client/src/interceptors/dio_logging_interceptor.dart';
import 'package:dio_http_client/src/interceptors/dio_retry_interceptor.dart';
import 'package:dio_http_client/src/interceptors/dio_token_refresh_interceptor.dart';
import 'package:dio_http_client/src/mappers/body_encoder.dart';
import 'package:dio_http_client/src/mappers/error_mapper.dart';
import 'package:dio_http_client/src/mappers/request_mapper.dart';
import 'package:dio_http_client/src/mappers/response_mapper.dart';
import 'package:dio_http_client/src/utils/cancel_token_adapter.dart';

/// HTTP client implementation using Dio.
///
/// Example usage:
/// ```dart
/// final client = DioHttpClient(
///   config: DioHttpClientConfig(
///     baseUrl: Uri.parse('https://api.example.com'),
///     connectTimeout: Duration(seconds: 30),
///   ),
/// );
///
/// await client.initialize();
///
/// final response = await client.get<Map<String, dynamic>>(
///   '/users/123',
///   decoder: (data) => data as Map<String, dynamic>,
/// );
///
/// await client.dispose();
/// ```
class DioHttpClient extends HttpClient {
  /// Creates a Dio HTTP client.
  DioHttpClient({
    required DioHttpClientConfig config,
    Dio? dio,
    TokenStore? tokenStore,
    TokenRefreshDelegate? refreshDelegate,
    List<HttpInterceptor>? interceptors,
    HttpTraceObserver? traceObserver,
  }) : _config = config,
       _dio = dio ?? Dio(),
       _tokenStore = tokenStore,
       _refreshDelegate = refreshDelegate,
       _interceptors = interceptors ?? const [],
       _traceObserver = traceObserver;

  final DioHttpClientConfig _config;
  final Dio _dio;
  final TokenStore? _tokenStore;
  final TokenRefreshDelegate? _refreshDelegate;
  final List<HttpInterceptor> _interceptors;
  final HttpTraceObserver? _traceObserver;

  bool _initialized = false;
  bool _initializing = false;
  bool _disposing = false;

  /// Reference to token refresh interceptor for cleanup.
  DioTokenRefreshInterceptor? _tokenRefreshInterceptor;

  @override
  HttpClientConfig get config => _config;

  @override
  bool get isInitialized => _initialized;

  /// The underlying Dio instance.
  ///
  /// Useful for advanced configuration or debugging.
  Dio get dio => _dio;

  @override
  Future<void> initialize() async {
    // Prevent concurrent initialization calls from duplicating interceptors.
    // Uses _initializing flag to protect against race conditions.
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      // Validate baseUrl format if provided
      final baseUrl = _config.baseUrl;
      if (baseUrl != null) {
        final baseUrlStr = baseUrl.toString();
        if (!baseUrl.hasScheme || !baseUrl.hasAuthority) {
          throw ArgumentError(
            'Invalid baseUrl: $baseUrlStr. '
            'Must be a valid URL with scheme (http/https) and host.',
          );
        }
      }

      // Validate token refresh configuration dependencies
      if (_config.tokenRefreshConfig != null) {
        if (_tokenStore == null || _refreshDelegate == null) {
          throw ArgumentError(
            'tokenRefreshConfig requires both tokenStore and refreshDelegate. '
            'Provide all three parameters to enable token refresh.',
          );
        }
      }

      _dio.options = BaseOptions(
        baseUrl: _config.baseUrl?.toString() ?? '',
        connectTimeout: _config.connectTimeout,
        receiveTimeout: _config.receiveTimeout,
        sendTimeout: _config.sendTimeout,
        headers: _config.defaultHeaders,
        followRedirects: _config.followRedirects,
        maxRedirects: _config.maxRedirects,
        validateStatus: _config.validateStatus != null
            ? (status) => _config.validateStatus!(status ?? 0)
            : _defaultValidateStatus,
        contentType: _config.contentType,
        responseType: _mapResponseType(_config.responseType),
        listFormat: _mapListFormat(_config.listFormat),
      );

      // Add auth interceptor if token store is provided
      if (_tokenStore != null) {
        _dio.interceptors.add(
          DioAuthInterceptor(tokenStore: _tokenStore),
        );
      }

      // Add token refresh interceptor if both store and delegate are provided
      if (_tokenStore != null &&
          _refreshDelegate != null &&
          _config.tokenRefreshConfig != null) {
        _tokenRefreshInterceptor = DioTokenRefreshInterceptor(
          tokenStore: _tokenStore,
          refreshDelegate: _refreshDelegate,
          dio: _dio,
          client: this,
          config: _config.tokenRefreshConfig!,
        );
        _dio.interceptors.add(_tokenRefreshInterceptor!);
      }

      // Add retry interceptor if policy is configured
      if (_config.retryPolicy != null) {
        _dio.interceptors.add(
          DioRetryInterceptor(
            policy: _config.retryPolicy!,
            dio: _dio,
          ),
        );
      }

      // Add custom HttpInterceptors via adapter
      for (final interceptor in _interceptors) {
        _dio.interceptors.add(DioInterceptorAdapter(interceptor: interceptor));
      }

      // Add logging interceptor if enabled
      if (_config.enableLogging) {
        _dio.interceptors.add(
          DioLoggingInterceptor(
            logRequestBody: _config.logRequestBody,
            logResponseBody: _config.logResponseBody,
            logRequestHeaders: _config.logRequestHeaders,
            logResponseHeaders: _config.logResponseHeaders,
          ),
        );
      }

      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  /// Counter for active requests to prevent dispose during execution.
  int _activeRequests = 0;

  /// Completer that signals when all active requests have completed.
  /// Used by dispose() to wait efficiently without polling.
  Completer<void>? _requestsCompleter;

  /// Disposes the HTTP client and releases resources.
  ///
  /// This method:
  /// - Waits for active requests to complete (up to 5 seconds)
  /// - Closes the underlying Dio instance
  ///
  /// **Implementation Note:** Uses Completer-based waiting pattern that
  /// completes immediately when all requests finish, avoiding CPU waste
  /// from polling. Falls back to 5-second timeout to prevent indefinite blocking.
  ///
  /// **Note:** External dependencies ([TokenStore], [TokenRefreshDelegate],
  /// [HttpTraceObserver]) are NOT disposed - they are owned by the caller.
  @override
  Future<void> dispose() async {
    // Prevent concurrent dispose calls
    if (_disposing) return;
    if (!_initialized) return;

    _disposing = true;
    // Set _initialized = false BEFORE closing to reject new requests immediately
    _initialized = false;

    try {
      // Wait for active requests to complete (with timeout)
      if (_activeRequests > 0) {
        // Create completer if not exists (will be completed by _decrementRequests)
        _requestsCompleter ??= Completer<void>();

        // Wait for either: all requests complete OR 5 second timeout
        await Future.any([
          _requestsCompleter!.future,
          Future<void>.delayed(const Duration(seconds: 5)),
        ]);
      }

      // Dispose token refresh interceptor to release its retry Dio instance
      _tokenRefreshInterceptor?.dispose();
      _tokenRefreshInterceptor = null;

      _dio.close();
    } finally {
      _disposing = false;
      _requestsCompleter = null;
    }
  }

  @override
  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();

    // Increment BEFORE try and decrement in finally to ensure counter
    // consistency even if code between increment and try throws
    _activeRequests++;
    try {
      final trace = HttpTrace.start(request);
      _traceObserver?.onStart(trace);

      try {
        final options = DioRequestMapper.toOptions(request);
        final data = await DioBodyEncoder.encode(request.body);

        final uri = request.resolveUri(defaultBaseUrl: _config.baseUrl);

        final dioResponse = await _dio.requestUri<dynamic>(
          uri,
          data: data,
          options: options,
          cancelToken: CancelTokenAdapter.toDio(cancelToken),
        );

        final response = DioResponseMapper.toHttpResponse<T>(
          dioResponse,
          request: request,
          decoder: decoder,
        );

        trace.finish(response);
        _traceObserver?.onFinish(trace, response);

        return response;
      } on DioException catch (e, stackTrace) {
        final error = DioErrorMapper.toHttpError(e, request, stackTrace);
        trace.fail(error);
        _traceObserver?.onError(trace, error);
        throw error;
      }
    } finally {
      _activeRequests--;
      // Signal completion if dispose is waiting and all requests are done
      if (_activeRequests == 0 &&
          _requestsCompleter != null &&
          !_requestsCompleter!.isCompleted) {
        _requestsCompleter!.complete();
      }
      // Cleanup cancel token adapter resources to prevent memory leaks
      CancelTokenAdapter.cleanup(cancelToken);
    }
  }

  void _ensureInitialized() {
    if (_disposing) {
      throw StateError('DioHttpClient is being disposed.');
    }
    if (!_initialized) {
      throw StateError(
        'DioHttpClient not initialized. Call initialize() first.',
      );
    }
  }

  static bool _defaultValidateStatus(int? status) =>
      status != null && status >= 200 && status < 300;

  /// Maps [DioResponseType] to Dio's [ResponseType].
  static ResponseType _mapResponseType(DioResponseType? type) {
    if (type == null) return ResponseType.json;
    return switch (type) {
      DioResponseType.json => ResponseType.json,
      DioResponseType.stream => ResponseType.stream,
      DioResponseType.plain => ResponseType.plain,
      DioResponseType.bytes => ResponseType.bytes,
    };
  }

  /// Maps [DioListFormat] to Dio's [ListFormat].
  ///
  /// Note: [DioListFormat.indexed] maps to [ListFormat.multiCompatible]
  /// as the closest approximation (Dio doesn't support indexed arrays natively).
  static ListFormat _mapListFormat(DioListFormat? format) {
    if (format == null) return ListFormat.multi;
    return switch (format) {
      DioListFormat.csv => ListFormat.csv,
      DioListFormat.multi => ListFormat.multi,
      DioListFormat.multiCompatible => ListFormat.multiCompatible,
      // Dio doesn't have native indexed format (key[0]=1&key[1]=2),
      // using multiCompatible (key[]=1&key[]=2) as closest alternative
      DioListFormat.indexed => ListFormat.multiCompatible,
    };
  }
}
