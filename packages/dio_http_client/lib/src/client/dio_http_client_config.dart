import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:meta/meta.dart';

/// Dio-specific HTTP client configuration.
///
/// Extends [HttpClientConfig] with Dio-specific options.
@immutable
class DioHttpClientConfig extends HttpClientConfig {
  /// Creates a Dio HTTP client configuration.
  const DioHttpClientConfig({
    super.baseUrl,
    super.connectTimeout = const Duration(seconds: 30),
    super.receiveTimeout = const Duration(seconds: 30),
    super.sendTimeout = const Duration(seconds: 30),
    super.defaultHeaders = const {},
    super.interceptors = const [],
    super.retryPolicy,
    super.validateStatus,
    super.followRedirects = true,
    super.maxRedirects = 5,
    super.enableLogging = false,
    super.extra = const {},
    this.tokenRefreshConfig,
    this.logRequestBody = true,
    this.logResponseBody = true,
    this.logRequestHeaders = true,
    this.logResponseHeaders = true,
    this.contentType,
    this.responseType,
    this.listFormat,
  });

  /// Configuration for token refresh.
  final TokenRefreshConfig? tokenRefreshConfig;

  /// Whether to log request bodies.
  final bool logRequestBody;

  /// Whether to log response bodies.
  final bool logResponseBody;

  /// Whether to log request headers.
  final bool logRequestHeaders;

  /// Whether to log response headers.
  final bool logResponseHeaders;

  /// Default content type for requests.
  final String? contentType;

  /// Response type (json, stream, plain, bytes).
  final DioResponseType? responseType;

  /// Format for encoding list parameters in query strings.
  final DioListFormat? listFormat;

  @override
  DioHttpClientConfig copyWith({
    Uri? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, String>? defaultHeaders,
    List<HttpInterceptor>? interceptors,
    RetryPolicy? retryPolicy,
    bool Function(int statusCode)? validateStatus,
    bool? followRedirects,
    int? maxRedirects,
    bool? enableLogging,
    Map<String, Object?>? extra,
    TokenRefreshConfig? tokenRefreshConfig,
    bool? logRequestBody,
    bool? logResponseBody,
    bool? logRequestHeaders,
    bool? logResponseHeaders,
    String? contentType,
    DioResponseType? responseType,
    DioListFormat? listFormat,
  }) {
    return DioHttpClientConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      interceptors: interceptors ?? this.interceptors,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      validateStatus: validateStatus ?? this.validateStatus,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      enableLogging: enableLogging ?? this.enableLogging,
      extra: extra ?? this.extra,
      tokenRefreshConfig: tokenRefreshConfig ?? this.tokenRefreshConfig,
      logRequestBody: logRequestBody ?? this.logRequestBody,
      logResponseBody: logResponseBody ?? this.logResponseBody,
      logRequestHeaders: logRequestHeaders ?? this.logRequestHeaders,
      logResponseHeaders: logResponseHeaders ?? this.logResponseHeaders,
      contentType: contentType ?? this.contentType,
      responseType: responseType ?? this.responseType,
      listFormat: listFormat ?? this.listFormat,
    );
  }
}

/// Dio response type.
enum DioResponseType {
  /// JSON response.
  json,

  /// Stream response.
  stream,

  /// Plain text response.
  plain,

  /// Bytes response.
  bytes,
}

/// Format for encoding list parameters.
enum DioListFormat {
  /// Comma-separated: `key=1,2,3`
  csv,

  /// Separate parameters: `key=1&key=2&key=3`
  multi,

  /// Bracket notation: `key[]=1&key[]=2&key[]=3`
  multiCompatible,

  /// Indexed: `key[0]=1&key[1]=2&key[2]=3`
  indexed,
}
