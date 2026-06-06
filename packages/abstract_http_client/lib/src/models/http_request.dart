import 'package:abstract_http_client/src/models/http_body.dart';
import 'package:abstract_http_client/src/models/http_method.dart';
import 'package:meta/meta.dart';

/// Represents an HTTP request.
///
/// Immutable by design. Use [copyWith] to create modified copies.
@immutable
class HttpRequest {
  /// Creates an HTTP request.
  const HttpRequest({
    required this.method,
    required this.path,
    this.baseUrl,
    this.queryParameters,
    this.headers,
    this.body,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  });

  /// Creates a GET request.
  const HttpRequest.get(
    this.path, {
    this.baseUrl,
    this.queryParameters,
    this.headers,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  }) : method = HttpMethod.get,
       body = null;

  /// Creates a POST request.
  const HttpRequest.post(
    this.path, {
    this.baseUrl,
    this.body,
    this.queryParameters,
    this.headers,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  }) : method = HttpMethod.post;

  /// Creates a PUT request.
  const HttpRequest.put(
    this.path, {
    this.baseUrl,
    this.body,
    this.queryParameters,
    this.headers,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  }) : method = HttpMethod.put;

  /// Creates a PATCH request.
  const HttpRequest.patch(
    this.path, {
    this.baseUrl,
    this.body,
    this.queryParameters,
    this.headers,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  }) : method = HttpMethod.patch;

  /// Creates a DELETE request.
  const HttpRequest.delete(
    this.path, {
    this.baseUrl,
    this.body,
    this.queryParameters,
    this.headers,
    this.timeout,
    this.requiresAuth = false,
    this.extra,
  }) : method = HttpMethod.delete;

  /// The HTTP method.
  final HttpMethod method;

  /// The request path (relative to [baseUrl]).
  final String path;

  /// Optional base URL that overrides the client's default base URL.
  final Uri? baseUrl;

  /// Query parameters to append to the URL.
  final Map<String, dynamic>? queryParameters;

  /// HTTP headers for this request.
  final Map<String, String>? headers;

  /// The request body.
  final HttpBody? body;

  /// Request timeout. Overrides client default if set.
  final Duration? timeout;

  /// Whether this request requires authentication.
  ///
  /// When `true`, the auth interceptor will add the Authorization header.
  final bool requiresAuth;

  /// Extra data to pass through interceptors.
  ///
  /// Can be used for custom metadata, tracing info, etc.
  final Map<String, Object?>? extra;

  /// Resolves the full URI for this request.
  ///
  /// Combines [baseUrl] (or falls back to [defaultBaseUrl]) with [path]
  /// and [queryParameters].
  ///
  /// Path resolution rules:
  /// - If [path] starts with '/', it replaces the base path
  /// - Otherwise, [path] is appended to the base path
  /// - Double slashes in paths are preserved (intentional double-slashes
  ///   are valid in some APIs)
  Uri resolveUri({Uri? defaultBaseUrl}) {
    final base = baseUrl ?? defaultBaseUrl;

    if (base == null) {
      return Uri.parse(path).replace(
        queryParameters: queryParameters?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    }

    // Properly join paths without breaking intentional double-slashes.
    // Only normalize the join point between base path and request path.
    final basePath = base.path;
    final String combinedPath;

    if (path.startsWith('/')) {
      // Absolute path: replace base path entirely
      combinedPath = path;
    } else if (basePath.isEmpty || basePath.endsWith('/')) {
      // Base path empty or ends with slash: just append
      combinedPath = '$basePath$path';
    } else {
      // Base path doesn't end with slash: add separator
      combinedPath = '$basePath/$path';
    }

    return base.replace(
      path: combinedPath,
      queryParameters: {
        ...base.queryParameters,
        ...?queryParameters?.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  /// Creates a copy of this request with the given fields replaced.
  HttpRequest copyWith({
    HttpMethod? method,
    String? path,
    Uri? baseUrl,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    HttpBody? body,
    Duration? timeout,
    bool? requiresAuth,
    Map<String, Object?>? extra,
  }) {
    return HttpRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      baseUrl: baseUrl ?? this.baseUrl,
      queryParameters: queryParameters ?? this.queryParameters,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      extra: extra ?? this.extra,
    );
  }

  /// Creates a copy with additional headers merged.
  HttpRequest withHeaders(Map<String, String> additionalHeaders) {
    return copyWith(
      headers: {
        ...?headers,
        ...additionalHeaders,
      },
    );
  }

  /// Creates a copy with additional query parameters merged.
  HttpRequest withQueryParameters(Map<String, dynamic> additionalParams) {
    return copyWith(
      queryParameters: {
        ...?queryParameters,
        ...additionalParams,
      },
    );
  }

  /// Creates a copy with additional extra data merged.
  HttpRequest withExtra(Map<String, Object?> additionalExtra) {
    return copyWith(
      extra: {
        ...?extra,
        ...additionalExtra,
      },
    );
  }

  @override
  String toString() {
    return 'HttpRequest('
        'method: $method, '
        'path: $path, '
        'baseUrl: $baseUrl, '
        'queryParameters: $queryParameters, '
        'headers: $headers, '
        'body: $body, '
        'timeout: $timeout, '
        'requiresAuth: $requiresAuth'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HttpRequest &&
        other.method == method &&
        other.path == path &&
        other.baseUrl == baseUrl &&
        _mapEquals(other.queryParameters, queryParameters) &&
        _mapEquals(other.headers, headers) &&
        other.body == body &&
        other.timeout == timeout &&
        other.requiresAuth == requiresAuth &&
        _mapEquals(other.extra, extra);
  }

  @override
  int get hashCode {
    return Object.hash(
      method,
      path,
      baseUrl,
      Object.hashAll(queryParameters?.entries ?? []),
      Object.hashAll(headers?.entries ?? []),
      body,
      timeout,
      requiresAuth,
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
