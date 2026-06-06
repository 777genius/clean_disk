import 'dart:math';

import 'package:meta/meta.dart';

/// W3C Trace Context for distributed tracing.
///
/// Implements the W3C Trace Context specification for propagating
/// trace information across service boundaries.
///
/// See: https://www.w3.org/TR/trace-context/
@immutable
class TraceContext {
  /// Creates a trace context.
  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.traceFlags = 0,
    this.traceState,
  });

  /// Creates a new root trace context.
  factory TraceContext.root({bool sampled = true}) {
    return TraceContext(
      traceId: _generateTraceId(),
      spanId: _generateSpanId(),
      traceFlags: sampled ? _sampledFlag : 0,
    );
  }

  /// Parse from traceparent header.
  ///
  /// Format: `{version}-{traceId}-{spanId}-{flags}`
  /// Example: `00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01`
  factory TraceContext.fromHeader(String traceparent) {
    final parts = traceparent.split('-');
    if (parts.length < 4) {
      throw FormatException('Invalid traceparent: $traceparent');
    }

    final version = parts[0];
    if (version != '00') {
      // Only version 00 is supported
      throw FormatException('Unsupported version: $version');
    }

    final traceId = parts[1];
    if (traceId.length != 32) {
      throw FormatException('Invalid traceId length: ${traceId.length}');
    }

    final spanId = parts[2];
    if (spanId.length != 16) {
      throw FormatException('Invalid spanId length: ${spanId.length}');
    }

    final flags = int.parse(parts[3], radix: 16);

    return TraceContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: flags,
    );
  }

  /// Try to parse from traceparent header.
  ///
  /// Returns null if parsing fails.
  static TraceContext? tryFromHeader(String traceparent) {
    try {
      return TraceContext.fromHeader(traceparent);
    } on FormatException {
      return null;
    }
  }

  static const _sampledFlag = 0x01;

  /// Trace ID (32 hex chars, 128 bits).
  final String traceId;

  /// Span ID (16 hex chars, 64 bits).
  final String spanId;

  /// Trace flags (8-bit field).
  final int traceFlags;

  /// Vendor-specific trace state.
  final String? traceState;

  /// Whether sampling is enabled.
  bool get isSampled => traceFlags & _sampledFlag == _sampledFlag;

  /// Format as traceparent header value.
  String toHeader() {
    final flagsHex = traceFlags.toRadixString(16).padLeft(2, '0');
    return '00-$traceId-$spanId-$flagsHex';
  }

  /// Create child context for downstream call.
  ///
  /// Maintains the same traceId but generates a new spanId.
  TraceContext createChild() {
    return TraceContext(
      traceId: traceId,
      spanId: _generateSpanId(),
      traceFlags: traceFlags,
      traceState: traceState,
    );
  }

  /// Create a copy with sampling enabled.
  TraceContext withSampling({required bool sampled}) {
    return TraceContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: sampled
          ? (traceFlags | _sampledFlag)
          : (traceFlags & ~_sampledFlag),
      traceState: traceState,
    );
  }

  /// Create a copy with trace state.
  TraceContext withTraceState(String? state) {
    return TraceContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
      traceState: state,
    );
  }

  @override
  String toString() {
    return 'TraceContext('
        'traceId: $traceId, '
        'spanId: $spanId, '
        'isSampled: $isSampled'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TraceContext &&
        other.traceId == traceId &&
        other.spanId == spanId &&
        other.traceFlags == traceFlags &&
        other.traceState == traceState;
  }

  @override
  int get hashCode => Object.hash(traceId, spanId, traceFlags, traceState);
}

/// Propagator for distributed tracing context.
///
/// Injects/extracts trace context from HTTP headers.
/// Compatible with OpenTelemetry SDK.
abstract class TraceContextPropagator {
  /// Creates a trace context propagator.
  const TraceContextPropagator();

  /// Default W3C Trace Context propagator.
  static const TraceContextPropagator w3c = W3CTraceContextPropagator();

  /// Inject trace context into request headers.
  Map<String, String> inject(TraceContext context);

  /// Extract trace context from response headers.
  TraceContext? extract(Map<String, String> headers);
}

/// W3C Trace Context propagator implementation.
class W3CTraceContextPropagator implements TraceContextPropagator {
  /// Creates a W3C trace context propagator.
  const W3CTraceContextPropagator();

  static const _traceparentHeader = 'traceparent';
  static const _tracestateHeader = 'tracestate';

  @override
  Map<String, String> inject(TraceContext context) {
    return {
      _traceparentHeader: context.toHeader(),
      if (context.traceState != null) _tracestateHeader: context.traceState!,
    };
  }

  @override
  TraceContext? extract(Map<String, String> headers) {
    // Case-insensitive header lookup
    String? getHeader(String name) {
      final lowerName = name.toLowerCase();
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == lowerName) {
          return entry.value;
        }
      }
      return null;
    }

    final traceparent = getHeader(_traceparentHeader);
    if (traceparent == null) return null;

    try {
      final context = TraceContext.fromHeader(traceparent);
      final tracestate = getHeader(_tracestateHeader);
      if (tracestate != null) {
        return context.withTraceState(tracestate);
      }
      return context;
    } on FormatException {
      return null;
    }
  }
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
