import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Represents the body of an HTTP request.
///
/// Uses sealed class for exhaustive pattern matching (Dart 3+).
/// All subclasses are immutable.
@immutable
sealed class HttpBody {
  const HttpBody();

  /// JSON body. Will be encoded as application/json.
  const factory HttpBody.json(Map<String, Object?> data) = JsonBody;

  /// URL-encoded form data. Will be encoded as
  /// application/x-www-form-urlencoded.
  const factory HttpBody.form(Map<String, String> fields) = FormBody;

  /// Multipart form data. Supports file uploads.
  const factory HttpBody.multipart({
    required List<HttpPart> parts,
  }) = MultipartBody;

  /// Raw binary data.
  const factory HttpBody.binary(
    Uint8List bytes, {
    String? contentType,
  }) = BinaryBody;

  /// Streaming body for large payloads.
  const factory HttpBody.stream(
    Stream<List<int>> stream, {
    int? contentLength,
    String? contentType,
  }) = StreamBody;

  /// Plain text body.
  const factory HttpBody.text(
    String text, {
    String? contentType,
  }) = TextBody;

  /// Empty body.
  const factory HttpBody.empty() = EmptyBody;

  /// Lazy body that serializes on demand.
  ///
  /// Useful for heavy JSONs that shouldn't be computed if request
  /// is cancelled before sending.
  const factory HttpBody.lazy(
    FutureOr<Object?> Function() encoder, {
    String? contentType,
  }) = LazyBody;

  /// The Content-Type header value for this body type.
  ///
  /// Returns `null` if no specific content type is required.
  String? get contentType;
}

/// JSON body encoded as application/json.
@immutable
final class JsonBody extends HttpBody {
  /// Creates a JSON body.
  const JsonBody(this.data);

  /// The JSON data as a Map.
  final Map<String, Object?> data;

  @override
  String get contentType => 'application/json; charset=utf-8';

  @override
  String toString() => 'JsonBody($data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JsonBody && _deepMapEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hashAll(data.entries);
}

/// URL-encoded form body.
@immutable
final class FormBody extends HttpBody {
  /// Creates a form body.
  const FormBody(this.fields);

  /// The form fields as key-value pairs.
  final Map<String, String> fields;

  @override
  String get contentType => 'application/x-www-form-urlencoded; charset=utf-8';

  @override
  String toString() => 'FormBody($fields)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormBody && _mapEquals(other.fields, fields);
  }

  @override
  int get hashCode => Object.hashAll(fields.entries);
}

/// Multipart form data body.
@immutable
final class MultipartBody extends HttpBody {
  /// Creates a multipart body.
  const MultipartBody({required this.parts});

  /// The parts of the multipart request.
  final List<HttpPart> parts;

  @override
  String get contentType => 'multipart/form-data';

  @override
  String toString() => 'MultipartBody(parts: ${parts.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MultipartBody) return false;
    if (parts.length != other.parts.length) return false;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != other.parts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(parts);
}

/// Raw binary body.
@immutable
final class BinaryBody extends HttpBody {
  /// Creates a binary body.
  const BinaryBody(this.bytes, {this.contentType});

  /// The binary data.
  final Uint8List bytes;

  @override
  final String? contentType;

  /// The size of the binary data in bytes.
  int get length => bytes.length;

  @override
  String toString() => 'BinaryBody(${bytes.length} bytes)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BinaryBody) return false;
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(bytes), contentType);
}

/// Streaming body for large payloads.
@immutable
final class StreamBody extends HttpBody {
  /// Creates a stream body.
  const StreamBody(
    this.stream, {
    this.contentLength,
    this.contentType,
  });

  /// The data stream.
  final Stream<List<int>> stream;

  /// The total content length, if known.
  final int? contentLength;

  @override
  final String? contentType;

  @override
  String toString() => 'StreamBody(contentLength: $contentLength)';

  // Note: Stream equality is by identity
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamBody &&
        identical(other.stream, stream) &&
        other.contentLength == contentLength &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(stream, contentLength, contentType);
}

/// Plain text body.
@immutable
final class TextBody extends HttpBody {
  /// Creates a text body.
  const TextBody(this.text, {String? contentType}) : _contentType = contentType;

  /// The text content.
  final String text;

  final String? _contentType;

  @override
  String get contentType => _contentType ?? 'text/plain; charset=utf-8';

  @override
  String toString() => 'TextBody(${text.length} chars)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextBody &&
        other.text == text &&
        other._contentType == _contentType;
  }

  @override
  int get hashCode => Object.hash(text, _contentType);
}

/// Empty body.
@immutable
final class EmptyBody extends HttpBody {
  /// Creates an empty body.
  const EmptyBody();

  @override
  String? get contentType => null;

  @override
  String toString() => 'EmptyBody()';

  @override
  bool operator ==(Object other) => other is EmptyBody;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Lazy body that computes content on demand.
@immutable
final class LazyBody extends HttpBody {
  /// Creates a lazy body.
  const LazyBody(this.encoder, {this.contentType});

  /// The encoder function that produces the body content.
  final FutureOr<Object?> Function() encoder;

  @override
  final String? contentType;

  /// Evaluates the encoder and returns the body content.
  FutureOr<Object?> evaluate() => encoder();

  @override
  String toString() => 'LazyBody()';

  // Note: Function equality is by identity
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LazyBody &&
        identical(other.encoder, encoder) &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(encoder, contentType);
}

// ============================================================================
// HTTP Part (for multipart requests)
// ============================================================================

/// Part of a multipart request.
@immutable
sealed class HttpPart {
  const HttpPart();

  /// Creates a text field part.
  const factory HttpPart.field({
    required String name,
    required String value,
  }) = FieldPart;

  /// Creates a file part from a stream.
  const factory HttpPart.file({
    required String name,
    required String filename,
    required Stream<List<int>> stream,
    int? length,
    String? contentType,
  }) = FilePart;

  /// Creates a file part from bytes.
  const factory HttpPart.bytes({
    required String name,
    required String filename,
    required Uint8List bytes,
    String? contentType,
  }) = BytesPart;

  /// The name of this part in the form.
  String get name;
}

/// A text field in a multipart form.
@immutable
final class FieldPart extends HttpPart {
  /// Creates a field part.
  const FieldPart({
    required this.name,
    required this.value,
  });

  @override
  final String name;

  /// The field value.
  final String value;

  @override
  String toString() => 'FieldPart(name: $name, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FieldPart && other.name == name && other.value == value;
  }

  @override
  int get hashCode => Object.hash(name, value);
}

/// A file part in a multipart form (from stream).
@immutable
final class FilePart extends HttpPart {
  /// Creates a file part from a stream.
  const FilePart({
    required this.name,
    required this.filename,
    required this.stream,
    this.length,
    this.contentType,
  });

  @override
  final String name;

  /// The filename to report to the server.
  final String filename;

  /// The file content as a stream.
  final Stream<List<int>> stream;

  /// The file size in bytes, if known.
  final int? length;

  /// The MIME type of the file.
  final String? contentType;

  @override
  String toString() =>
      'FilePart(name: $name, filename: $filename, length: $length)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilePart &&
        other.name == name &&
        other.filename == filename &&
        identical(other.stream, stream) &&
        other.length == length &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(name, filename, stream, length, contentType);
}

/// A file part in a multipart form (from bytes).
@immutable
final class BytesPart extends HttpPart {
  /// Creates a file part from bytes.
  const BytesPart({
    required this.name,
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  @override
  final String name;

  /// The filename to report to the server.
  final String filename;

  /// The file content as bytes.
  final Uint8List bytes;

  /// The MIME type of the file.
  final String? contentType;

  /// The size of the bytes.
  int get length => bytes.length;

  @override
  String toString() =>
      'BytesPart(name: $name, filename: $filename, length: ${bytes.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BytesPart) return false;
    if (other.name != name ||
        other.filename != filename ||
        other.contentType != contentType) {
      return false;
    }
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(name, filename, Object.hashAll(bytes), contentType);
}

// ============================================================================
// Utility functions
// ============================================================================

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

bool _deepMapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    final aValue = entry.value;
    final bValue = b[entry.key];
    if (aValue is Map<String, Object?> && bValue is Map<String, Object?>) {
      if (!_deepMapEquals(aValue, bValue)) return false;
    } else if (aValue is List && bValue is List) {
      if (!_listEquals(aValue, bValue)) return false;
    } else if (aValue != bValue) {
      return false;
    }
  }
  return true;
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final aValue = a[i];
    final bValue = b[i];
    if (aValue is Map<String, Object?> && bValue is Map<String, Object?>) {
      if (!_deepMapEquals(aValue, bValue)) return false;
    } else if (aValue is List && bValue is List) {
      if (!_listEquals(aValue, bValue)) return false;
    } else if (aValue != bValue) {
      return false;
    }
  }
  return true;
}
