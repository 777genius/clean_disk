import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:meta/meta.dart';

/// Sentinel value for copyWith to distinguish "not provided" from "explicitly null".
const Object _unset = Object();

/// Represents an HTTP response.
///
/// Generic type [T] is the decoded data type.
@immutable
class HttpResponse<T> {
  /// Creates an HTTP response.
  const HttpResponse({
    required this.statusCode,
    required this.request,
    this.data,
    this.headers = const {},
    this.statusMessage,
    this.rawBody,
    this.latency,
    this.extra,
  });

  /// The HTTP status code.
  final int statusCode;

  /// The original request that produced this response.
  final HttpRequest request;

  /// The decoded response data.
  final T? data;

  /// Response headers.
  final Map<String, String> headers;

  /// The HTTP status message (e.g., "OK", "Not Found").
  final String? statusMessage;

  /// The raw response body before decoding.
  ///
  /// Useful for debugging or when custom parsing is needed.
  final Object? rawBody;

  /// Time taken from request start to response completion.
  final Duration? latency;

  /// Extra data passed through from request or added by interceptors.
  final Map<String, Object?>? extra;

  /// Whether the response indicates success (2xx status code).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response indicates a redirect (3xx status code).
  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  /// Whether the response indicates a client error (4xx status code).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the response indicates a server error (5xx status code).
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// Whether the response indicates any error (4xx or 5xx).
  bool get isError => statusCode >= 400;

  /// Get a specific header value (case-insensitive).
  String? header(String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  /// The Content-Type header value.
  String? get contentType => header('content-type');

  /// The Content-Length header value parsed as int.
  int? get contentLength {
    final value = header('content-length');
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Creates a copy of this response with the given fields replaced.
  ///
  /// To explicitly set a nullable field to null, pass null for that parameter.
  /// Omitting a parameter preserves the original value.
  ///
  /// Example:
  /// ```dart
  /// // Set data to null explicitly
  /// response.copyWith(data: null);  // Works correctly
  ///
  /// // Preserve original data
  /// response.copyWith(statusCode: 200);  // data unchanged
  /// ```
  HttpResponse<T> copyWith({
    int? statusCode,
    HttpRequest? request,
    Object? data = _unset,
    Map<String, String>? headers,
    Object? statusMessage = _unset,
    Object? rawBody = _unset,
    Object? latency = _unset,
    Object? extra = _unset,
  }) {
    return HttpResponse<T>(
      statusCode: statusCode ?? this.statusCode,
      request: request ?? this.request,
      data: identical(data, _unset) ? this.data : data as T?,
      headers: headers ?? this.headers,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      rawBody: identical(rawBody, _unset) ? this.rawBody : rawBody,
      latency: identical(latency, _unset) ? this.latency : latency as Duration?,
      extra: identical(extra, _unset)
          ? this.extra
          : extra as Map<String, Object?>?,
    );
  }

  /// Creates a new response with different data type.
  ///
  /// Useful when transforming response data through decoders.
  HttpResponse<R> transform<R>(R Function(T? data) transformer) {
    return HttpResponse<R>(
      statusCode: statusCode,
      request: request,
      data: transformer(data),
      headers: headers,
      statusMessage: statusMessage,
      rawBody: rawBody,
      latency: latency,
      extra: extra,
    );
  }

  @override
  String toString() {
    return 'HttpResponse('
        'statusCode: $statusCode, '
        'statusMessage: $statusMessage, '
        'data: $data, '
        'latency: $latency'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HttpResponse<T> &&
        other.statusCode == statusCode &&
        other.request == request &&
        other.data == data &&
        _mapEquals(other.headers, headers) &&
        other.statusMessage == statusMessage &&
        other.rawBody == rawBody &&
        other.latency == latency &&
        _mapEquals(other.extra, extra);
  }

  @override
  int get hashCode {
    return Object.hash(
      statusCode,
      request,
      data,
      Object.hashAll(headers.entries),
      statusMessage,
      rawBody,
      latency,
      Object.hashAll(extra?.entries ?? []),
    );
  }
}

bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
