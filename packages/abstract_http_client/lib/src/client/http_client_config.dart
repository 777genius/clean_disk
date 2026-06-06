import 'package:abstract_http_client/src/interceptors/http_interceptor.dart';
import 'package:abstract_http_client/src/retry/retry_policy.dart';
import 'package:meta/meta.dart';

/// Configuration for an HTTP client.
///
/// Immutable by design. Use [copyWith] to create modified copies.
@immutable
class HttpClientConfig {
  /// Creates an HTTP client configuration.
  const HttpClientConfig({
    this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.interceptors = const [],
    this.retryPolicy,
    this.validateStatus,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.enableLogging = false,
    this.extra = const {},
  });

  /// Base URL for all requests.
  ///
  /// If provided, request paths will be resolved relative to this URL.
  final Uri? baseUrl;

  /// Timeout for establishing a connection.
  final Duration connectTimeout;

  /// Timeout for receiving data.
  final Duration receiveTimeout;

  /// Timeout for sending data.
  final Duration sendTimeout;

  /// Default headers to include with every request.
  ///
  /// Request-specific headers will override these.
  final Map<String, String> defaultHeaders;

  /// Interceptors to apply to all requests.
  ///
  /// Interceptors are applied in order for requests and reverse order
  /// for responses.
  final List<HttpInterceptor> interceptors;

  /// Retry policy for failed requests.
  ///
  /// If `null`, no automatic retries will be performed.
  final RetryPolicy? retryPolicy;

  /// Custom status code validation.
  ///
  /// If provided, this function determines whether a status code
  /// should be treated as a successful response. By default,
  /// 2xx status codes are considered successful.
  final bool Function(int statusCode)? validateStatus;

  /// Whether to automatically follow redirects.
  final bool followRedirects;

  /// Maximum number of redirects to follow.
  final int maxRedirects;

  /// Whether to enable request/response logging.
  final bool enableLogging;

  /// Extra configuration data for custom implementations.
  final Map<String, Object?> extra;

  /// Default status validation - 2xx status codes are successful.
  static bool defaultValidateStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Creates a copy of this configuration with the given fields replaced.
  HttpClientConfig copyWith({
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
  }) {
    return HttpClientConfig(
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
    );
  }

  /// Creates a copy with additional headers merged.
  HttpClientConfig withHeaders(Map<String, String> additionalHeaders) {
    return copyWith(
      defaultHeaders: {
        ...defaultHeaders,
        ...additionalHeaders,
      },
    );
  }

  /// Creates a copy with an additional interceptor appended.
  HttpClientConfig withInterceptor(HttpInterceptor interceptor) {
    return copyWith(
      interceptors: [...interceptors, interceptor],
    );
  }

  @override
  String toString() {
    return 'HttpClientConfig('
        'baseUrl: $baseUrl, '
        'connectTimeout: $connectTimeout, '
        'receiveTimeout: $receiveTimeout, '
        'sendTimeout: $sendTimeout, '
        'defaultHeaders: $defaultHeaders, '
        'interceptors: ${interceptors.length}, '
        'retryPolicy: $retryPolicy, '
        'followRedirects: $followRedirects, '
        'maxRedirects: $maxRedirects, '
        'enableLogging: $enableLogging'
        ')';
  }
}
