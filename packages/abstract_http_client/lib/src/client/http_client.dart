import 'dart:async';

import 'package:abstract_http_client/src/client/http_client_config.dart';
import 'package:abstract_http_client/src/models/http_body.dart';
import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_method.dart';
import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:abstract_http_client/src/models/http_response.dart';
import 'package:abstract_http_client/src/utils/cancel_token.dart';

/// Decoder function type for transforming raw response data.
typedef ResponseDecoder<T> = T Function(dynamic data);

/// Core HTTP client contract.
///
/// ## Thread Safety
///
/// All implementations MUST guarantee:
/// - [send] is safe to call from multiple isolates concurrently
/// - [initialize] must complete before any [send] calls
/// - [dispose] must be called only once; subsequent calls should be no-op
/// - After [dispose], all [send] calls will throw [StateError]
///
/// ## Cancellation
///
/// All methods accepting [CancelToken] MUST:
/// - Check cancellation state before starting work
/// - Propagate cancellation to underlying operations
/// - Clean up resources when cancelled
///
/// ## Lifecycle
///
/// 1. Create instance with configuration
/// 2. Call [initialize] before any requests
/// 3. Use [send] or convenience methods for requests
/// 4. Call [dispose] when done (only once)
///
/// Example usage:
/// ```dart
/// final client = DioHttpClient(config: config);
/// await client.initialize();
///
/// final response = await client.get<Map<String, dynamic>>(
///   '/users/123',
///   decoder: (data) => data as Map<String, dynamic>,
/// );
///
/// await client.dispose();
/// ```
abstract class HttpClient {
  /// Client configuration.
  HttpClientConfig get config;

  /// Whether the client has been initialized.
  bool get isInitialized;

  /// Initialize the client.
  ///
  /// Must be called before any requests. Implementations should be
  /// idempotent - calling initialize() multiple times should be safe.
  Future<void> initialize();

  /// Dispose resources.
  ///
  /// Client cannot be used after this. Implementations should cancel
  /// any pending requests and clean up resources.
  Future<void> dispose();

  /// Send an HTTP request.
  ///
  /// [T] is the expected response type. Pass a [decoder] to transform
  /// the raw response body into [T].
  ///
  /// Throws [HttpError] on failure.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.send<User>(
  ///   HttpRequest.get('/users/123'),
  ///   decoder: (data) => User.fromJson(data as Map<String, dynamic>),
  /// );
  /// ```
  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  });

  /// Send a GET request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.get,
        path: path,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send a POST request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> post<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.post,
        path: path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send a PUT request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> put<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.put,
        path: path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send a PATCH request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> patch<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.patch,
        path: path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send a DELETE request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> delete<T>(
    String path, {
    HttpBody? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.delete,
        path: path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send a HEAD request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> head<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.head,
        path: path,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }

  /// Send an OPTIONS request.
  ///
  /// Convenience method that wraps [send].
  Future<HttpResponse<T>> options<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return send<T>(
      HttpRequest(
        method: HttpMethod.options,
        path: path,
        queryParameters: queryParameters,
        headers: headers,
        timeout: timeout,
      ),
      decoder: decoder,
      cancelToken: cancelToken,
    );
  }
}
