import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;

/// Maps [HttpRequest] to Dio [Options].
class DioRequestMapper {
  DioRequestMapper._();

  /// Converts an [HttpRequest] to Dio [Options].
  ///
  /// **Note on timeouts:** The abstract [HttpRequest] has a single `timeout`
  /// field which is applied to both `sendTimeout` and `receiveTimeout` in Dio.
  /// For more granular control, use `DioHttpClientConfig` which supports
  /// separate send/receive/connect timeouts at the client level.
  static Options toOptions(HttpRequest request) {
    return Options(
      method: request.method.value,
      headers: request.headers,
      sendTimeout: request.timeout,
      receiveTimeout: request.timeout,
      extra: request.extra,
      contentType: _getContentType(request.body),
    );
  }

  /// Gets the content type based on body type.
  static String? _getContentType(HttpBody? body) {
    return body?.contentType;
  }
}
