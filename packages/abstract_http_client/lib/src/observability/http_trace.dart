import 'dart:math';

import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:abstract_http_client/src/models/http_response.dart';
import 'package:meta/meta.dart';

/// HTTP request/response trace for observability.
///
/// Captures timing and metadata for requests, compatible with
/// distributed tracing systems like OpenTelemetry.
class HttpTrace {
  HttpTrace._({
    required this.id,
    required this.request,
    required this.startTime,
    this.parentSpanId,
    this.traceId,
  });

  /// Start a new trace.
  factory HttpTrace.start(
    HttpRequest request, {
    String? parentSpanId,
    String? traceId,
  }) {
    return HttpTrace._(
      id: _generateSpanId(),
      request: request,
      startTime: DateTime.now(),
      parentSpanId: parentSpanId,
      traceId: traceId ?? _generateTraceId(),
    );
  }

  /// Unique identifier for this span.
  final String id;

  /// The request being traced.
  final HttpRequest request;

  /// When the request started.
  final DateTime startTime;

  /// Parent span ID for distributed tracing.
  final String? parentSpanId;

  /// Trace ID for distributed tracing.
  final String? traceId;

  DateTime? _endTime;
  HttpResponse<dynamic>? _response;
  HttpError? _error;
  final Map<String, Object?> _attributes = {};
  final List<TraceEvent> _events = [];

  /// End time of the trace.
  DateTime? get endTime => _endTime;

  /// Response if successful.
  HttpResponse<dynamic>? get response => _response;

  /// Error if failed.
  HttpError? get error => _error;

  /// Duration of the request.
  Duration? get duration {
    if (_endTime == null) return null;
    return _endTime!.difference(startTime);
  }

  /// Whether the trace has completed.
  bool get isCompleted => _endTime != null;

  /// Whether the trace completed successfully.
  bool get isSuccess => _response != null && _error == null;

  /// Custom attributes for this trace.
  Map<String, Object?> get attributes => Map.unmodifiable(_attributes);

  /// Events recorded during the trace.
  List<TraceEvent> get events => List.unmodifiable(_events);

  /// HTTP status code if available.
  int? get statusCode => _response?.statusCode;

  /// Add custom attribute.
  void setAttribute(String key, Object? value) {
    _attributes[key] = value;
  }

  /// Add multiple attributes.
  void setAttributes(Map<String, Object?> attrs) {
    _attributes.addAll(attrs);
  }

  /// Record an event during the trace.
  void addEvent(String name, {Map<String, Object?>? attributes}) {
    _events.add(
      TraceEvent(
        name: name,
        timestamp: DateTime.now(),
        attributes: attributes ?? const {},
      ),
    );
  }

  /// Mark trace as finished successfully.
  ///
  /// If the trace is already completed (either by [finish] or [fail]),
  /// this method is a no-op. Returns `true` if the trace was successfully
  /// finished, `false` if it was already completed.
  ///
  /// Thread-safe: first call wins in case of concurrent calls.
  /// Clears any error to maintain invariant: success means no error.
  bool finish([HttpResponse<dynamic>? response]) {
    // Atomic check-and-set: in Dart's synchronous execution model,
    // no other code can run between these statements
    if (_endTime != null) return false;
    _endTime = DateTime.now();
    _response = response;
    _error = null; // Clear error to maintain invariant
    return true;
  }

  /// Mark trace as failed.
  ///
  /// If the trace is already completed (either by [finish] or [fail]),
  /// this method is a no-op. Returns `true` if the trace was successfully
  /// marked as failed, `false` if it was already completed.
  ///
  /// Thread-safe: first call wins in case of concurrent calls.
  /// Clears any response to maintain invariant: failure means no response.
  bool fail(HttpError error) {
    // Atomic check-and-set: in Dart's synchronous execution model,
    // no other code can run between these statements
    if (_endTime != null) return false;
    _endTime = DateTime.now();
    _error = error;
    _response = null; // Clear response to maintain invariant
    return true;
  }

  @override
  String toString() {
    return 'HttpTrace('
        'id: $id, '
        'method: ${request.method}, '
        'path: ${request.path}, '
        'duration: $duration, '
        'statusCode: $statusCode'
        ')';
  }
}

/// Event recorded during a trace.
@immutable
class TraceEvent {
  /// Creates a trace event.
  const TraceEvent({
    required this.name,
    required this.timestamp,
    this.attributes = const {},
  });

  /// Event name.
  final String name;

  /// When the event occurred.
  final DateTime timestamp;

  /// Event attributes.
  final Map<String, Object?> attributes;

  @override
  String toString() => 'TraceEvent(name: $name, timestamp: $timestamp)';
}

// ============================================================================
// ID Generation
// ============================================================================

final _random = Random.secure();

/// Generates a 16-character span ID (64 bits).
String _generateSpanId() {
  final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generates a 32-character trace ID (128 bits).
String _generateTraceId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
