import 'dart:convert';

import 'package:dio/dio.dart' hide CancelToken;

/// Pretty logging interceptor for HTTP requests and responses.
class DioLoggingInterceptor extends Interceptor {
  /// Creates a new logging interceptor.
  ///
  /// Use [sampleRate] to reduce logging in production environments.
  /// For example, `sampleRate: 10` logs every 10th request.
  DioLoggingInterceptor({
    this.logRequest = true,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponse = true,
    this.logResponseHeaders = true,
    this.logResponseBody = true,
    this.logError = true,
    this.maxBodyLength = 1024,
    this.sampleRate = 1,
    this.logger,
  }) : assert(sampleRate >= 1, 'sampleRate must be >= 1');

  /// Whether to log requests.
  final bool logRequest;

  /// Whether to log request headers.
  final bool logRequestHeaders;

  /// Whether to log request body.
  final bool logRequestBody;

  /// Whether to log responses.
  final bool logResponse;

  /// Whether to log response headers.
  final bool logResponseHeaders;

  /// Whether to log response body.
  final bool logResponseBody;

  /// Whether to log errors.
  final bool logError;

  /// Maximum body length to log (truncates if longer).
  final int maxBodyLength;

  /// Sample rate for logging (logs 1 in N requests).
  ///
  /// Default is 1 (log all requests). Set to higher values in production
  /// to reduce logging overhead. For example:
  /// - `sampleRate: 1` - logs every request (100%)
  /// - `sampleRate: 10` - logs every 10th request (10%)
  /// - `sampleRate: 100` - logs every 100th request (1%)
  ///
  /// **Note:** Errors are always logged regardless of sample rate.
  final int sampleRate;

  /// Custom logger function. Defaults to print.
  final void Function(String message)? logger;

  /// Counter for sample rate tracking.
  int _requestCount = 0;

  /// Key used to mark requests for logging (when using sample rate > 1).
  static const _shouldLogKey = '_dioLoggingShouldLog';

  /// Checks if this request should be logged based on sample rate.
  ///
  /// Increments counter and returns true if this is the Nth request.
  /// Uses modulo arithmetic to prevent counter overflow in long-running apps.
  bool _shouldSampleLog() {
    if (sampleRate == 1) return true;
    // Use modulo arithmetic to prevent unbounded counter growth
    _requestCount = (_requestCount + 1) % sampleRate;
    return _requestCount == 0;
  }

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    } else {
      // ignore: avoid_print
      print(message);
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Check sample rate - mark request if it should be logged
    final shouldLog = _shouldSampleLog();
    options.extra[_shouldLogKey] = shouldLog;

    if (logRequest && shouldLog) {
      final buffer = StringBuffer()
        ..writeln()
        ..writeln('╔══════════════════════════════════════════════════════')
        ..writeln('║ REQUEST')
        ..writeln('╠══════════════════════════════════════════════════════')
        ..writeln('║ ${options.method} ${options.uri}');

      if (logRequestHeaders && options.headers.isNotEmpty) {
        buffer
          ..writeln('╠──────────────────────────────────────────────────────')
          ..writeln('║ Headers:');
        options.headers.forEach((key, value) {
          // Mask sensitive headers, use toString() for safe conversion
          final displayValue = _isSensitiveHeader(key)
              ? '***'
              : value?.toString() ?? 'null';
          buffer.writeln('║   $key: $displayValue');
        });
      }

      if (logRequestBody && options.data != null) {
        buffer
          ..writeln('╠──────────────────────────────────────────────────────')
          ..writeln('║ Body:');
        final body = _formatBody(options.data);
        for (final line in body.split('\n')) {
          buffer.writeln('║   $line');
        }
      }

      buffer.writeln('╚══════════════════════════════════════════════════════');
      _log(buffer.toString());
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Only log response if request was marked for logging
    final shouldLog =
        response.requestOptions.extra[_shouldLogKey] as bool? ?? true;

    if (logResponse && shouldLog) {
      final buffer = StringBuffer()
        ..writeln()
        ..writeln('╔══════════════════════════════════════════════════════')
        ..writeln('║ RESPONSE')
        ..writeln('╠══════════════════════════════════════════════════════')
        ..writeln('║ ${response.statusCode} ${response.statusMessage ?? ''}')
        ..writeln(
          '║ ${response.requestOptions.method} '
          '${response.requestOptions.uri}',
        );

      if (logResponseHeaders && response.headers.map.isNotEmpty) {
        buffer
          ..writeln('╠──────────────────────────────────────────────────────')
          ..writeln('║ Headers:');
        response.headers.forEach((name, values) {
          buffer.writeln('║   $name: ${values.join(', ')}');
        });
      }

      if (logResponseBody && response.data != null) {
        buffer
          ..writeln('╠──────────────────────────────────────────────────────')
          ..writeln('║ Body:');
        final body = _formatBody(response.data);
        for (final line in body.split('\n')) {
          buffer.writeln('║   $line');
        }
      }

      buffer.writeln('╚══════════════════════════════════════════════════════');
      _log(buffer.toString());
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logError) {
      final buffer = StringBuffer()
        ..writeln()
        ..writeln('╔══════════════════════════════════════════════════════')
        ..writeln('║ ERROR')
        ..writeln('╠══════════════════════════════════════════════════════')
        ..writeln('║ ${err.type.name}: ${err.message ?? 'Unknown error'}')
        ..writeln(
          '║ ${err.requestOptions.method} '
          '${err.requestOptions.uri}',
        );

      // Capture response in local variable to avoid repeated null checks
      final response = err.response;
      if (response != null) {
        buffer
          ..writeln('╠──────────────────────────────────────────────────────')
          ..writeln(
            '║ Status: ${response.statusCode} '
            '${response.statusMessage ?? ''}',
          );

        if (logResponseBody && response.data != null) {
          buffer.writeln('║ Response Body:');
          final body = _formatBody(response.data);
          for (final line in body.split('\n')) {
            buffer.writeln('║   $line');
          }
        }
      }

      buffer.writeln('╚══════════════════════════════════════════════════════');
      _log(buffer.toString());
    }

    handler.next(err);
  }

  /// Formats body for logging.
  String _formatBody(dynamic data) {
    if (data == null) return 'null';

    String body;
    if (data is Map || data is List) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        body = encoder.convert(data);
      } on Object catch (_) {
        body = data.toString();
      }
    } else if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}: ${e.value}').join(', ');
      final files = data.files.map((e) => '${e.key}: ${e.value.filename}');
      body = 'FormData { fields: [$fields], files: [${files.join(', ')}] }';
    } else {
      body = data.toString();
    }

    // Truncate if too long
    if (body.length > maxBodyLength) {
      body = '${body.substring(0, maxBodyLength)}... (truncated)';
    }

    return body;
  }

  /// Checks if header is sensitive and should be masked.
  bool _isSensitiveHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'authorization' ||
        lower == 'cookie' ||
        lower == 'set-cookie' ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('key');
  }
}
