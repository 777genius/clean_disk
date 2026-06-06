import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken, ResponseDecoder;

/// Maps Dio [Response] to [HttpResponse].
class DioResponseMapper {
  DioResponseMapper._();

  /// Converts a Dio [Response] to [HttpResponse].
  static HttpResponse<T> toHttpResponse<T>(
    Response<dynamic> dioResponse, {
    required HttpRequest request,
    ResponseDecoder<T>? decoder,
  }) {
    final rawData = dioResponse.data;
    final T? data;

    if (decoder != null) {
      // decoder returns T, which may be nullable
      // Wrap in try-catch to handle decoder errors gracefully
      try {
        data = decoder(rawData);
      } on Object catch (e, stackTrace) {
        // Log decoder error in debug mode for debugging
        assert(
          () {
            // ignore: avoid_print
            print(
              'DioResponseMapper: decoder threw: $e\n$stackTrace',
            );
            return true;
          }(),
          'decoder failed',
        );
        // Rethrow to let caller handle the error
        // This preserves the original exception type and message
        rethrow;
      }
    } else if (rawData is T) {
      data = rawData;
    } else {
      data = null;
    }

    // statusCode should never be null in normal operation.
    // If it is, default to 0 but log in debug mode for investigation.
    final statusCode = dioResponse.statusCode;
    if (statusCode == null) {
      assert(
        () {
          // ignore: avoid_print
          print(
            'DioResponseMapper: Unexpected null statusCode from Dio response. '
            'This may indicate a malformed response or network error.',
          );
          return true;
        }(),
        'null statusCode warning',
      );
    }

    return HttpResponse<T>(
      statusCode: statusCode ?? 0,
      request: request,
      data: data,
      headers: _extractHeaders(dioResponse.headers),
      statusMessage: dioResponse.statusMessage,
      rawBody: rawData,
      extra: dioResponse.extra,
    );
  }

  /// Extracts headers from Dio response.
  static Map<String, String> _extractHeaders(Headers headers) {
    final result = <String, String>{};

    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        // Join multiple values with comma as per HTTP spec
        result[name] = values.join(', ');
      }
    });

    return result;
  }
}
