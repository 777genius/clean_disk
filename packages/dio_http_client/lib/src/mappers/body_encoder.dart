import 'dart:async';
import 'dart:convert';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;

/// Encodes [HttpBody] to Dio-compatible format.
class DioBodyEncoder {
  DioBodyEncoder._();

  /// Encodes an [HttpBody] for Dio.
  ///
  /// Returns the encoded data suitable for Dio's request.
  /// This is async to properly handle [LazyBody] which may return a Future.
  static FutureOr<dynamic> encode(HttpBody? body) async {
    if (body == null) return null;

    return switch (body) {
      JsonBody(:final data) => data,
      FormBody(:final fields) => fields,
      MultipartBody(:final parts) => _encodeMultipart(parts),
      BinaryBody(:final bytes) => bytes,
      StreamBody(:final stream, contentLength: _) => stream,
      TextBody(:final text) => text,
      EmptyBody() => null,
      LazyBody(:final encoder) => await _encodeLazy(encoder),
    };
  }

  /// Encodes multipart parts to Dio [FormData].
  ///
  /// **Important - Stream Requirements:**
  /// - [FilePart] streams MUST NOT be consumed before calling this method
  /// - Dio reads from the stream when sending the request
  /// - If the stream was already consumed, the upload will fail or send empty data
  /// - For reusable data, use [BytesPart] instead which works with in-memory bytes
  ///
  /// **Note on cancellation:** Streams are passed to Dio's MultipartFile
  /// and will be consumed during the request. If the request is cancelled,
  /// the stream may not be properly closed. Use streams from file I/O
  /// which the OS closes automatically, or implement cleanup in your code.
  static FormData _encodeMultipart(List<HttpPart> parts) {
    final formData = FormData();

    for (final part in parts) {
      switch (part) {
        case FieldPart(:final name, :final value):
          formData.fields.add(MapEntry(name, value));

        case FilePart(
          :final name,
          :final filename,
          :final stream,
          :final length,
          :final contentType,
        ):
          // Validate length is provided - required for stream uploads
          if (length == null) {
            throw ArgumentError(
              'FilePart.length is required for stream uploads. '
              'Provide the file size or use BytesPart for in-memory data. '
              'File: $filename',
            );
          }
          formData.files.add(
            MapEntry(
              name,
              MultipartFile.fromStream(
                () => stream,
                length,
                filename: filename,
                contentType: _parseContentType(contentType),
              ),
            ),
          );

        case BytesPart(
          :final name,
          :final filename,
          :final bytes,
          :final contentType,
        ):
          formData.files.add(
            MapEntry(
              name,
              MultipartFile.fromBytes(
                bytes,
                filename: filename,
                contentType: _parseContentType(contentType),
              ),
            ),
          );
      }
    }

    return formData;
  }

  /// Encodes lazy body, properly handling async encoders.
  ///
  /// Supports: null, Map, String, List, and JSON-serializable objects.
  /// Throws [FormatException] for non-serializable types.
  static Future<dynamic> _encodeLazy(
    FutureOr<Object?> Function() encoder,
  ) async {
    final result = await encoder();

    if (result == null) {
      return null;
    } else if (result is Map<String, dynamic>) {
      return result;
    } else if (result is String) {
      return result;
    } else if (result is List) {
      return result;
    } else {
      // Try to encode as JSON with proper error handling
      try {
        return jsonEncode(result);
      } on Object catch (e) {
        throw FormatException(
          'LazyBody encoder returned non-serializable type: '
          '${result.runtimeType}. Error: $e',
        );
      }
    }
  }

  /// Safely parses content type, returning null for invalid formats.
  ///
  /// Logs a warning in debug mode when parsing fails to help developers
  /// identify invalid content-type strings.
  static DioMediaType? _parseContentType(String? contentType) {
    if (contentType == null) return null;
    try {
      return DioMediaType.parse(contentType);
    } on Object catch (e) {
      // Log invalid content type in debug mode for debugging
      assert(
        () {
          // ignore: avoid_print
          print(
            'DioBodyEncoder: Invalid content-type "$contentType": $e. '
            'Using default content-type instead.',
          );
          return true;
        }(),
        'Invalid content-type provided',
      );
      // Return null for default handling
      return null;
    }
  }
}
