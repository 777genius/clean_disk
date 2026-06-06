import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_response.dart';
import 'package:abstract_http_client/src/observability/http_trace.dart';

/// Observer for HTTP request lifecycle events.
///
/// Implement this to integrate with observability systems
/// (OpenTelemetry, Datadog, Sentry, etc.)
///
/// Example implementation:
/// ```dart
/// class LoggingTraceObserver implements HttpTraceObserver {
///   @override
///   void onStart(HttpTrace trace) {
///     print('Starting: ${trace.request.method} ${trace.request.path}');
///   }
///
///   @override
///   void onFinish(HttpTrace trace, HttpResponse response) {
///     print('Finished: ${response.statusCode} in ${trace.duration}');
///   }
///
///   @override
///   void onError(HttpTrace trace, HttpError error) {
///     print('Error: ${error.type} - ${error.message}');
///   }
/// }
/// ```
abstract class HttpTraceObserver {
  /// Creates an HTTP trace observer.
  const HttpTraceObserver();

  /// Called when a request starts.
  void onStart(HttpTrace trace);

  /// Called when a request completes successfully.
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response);

  /// Called when a request fails.
  void onError(HttpTrace trace, HttpError error);
}

/// No-op observer that does nothing.
///
/// Useful as a default or for disabling tracing.
class NoopTraceObserver implements HttpTraceObserver {
  /// Creates a no-op trace observer.
  const NoopTraceObserver();

  @override
  void onStart(HttpTrace trace) {}

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {}

  @override
  void onError(HttpTrace trace, HttpError error) {}
}

/// Callback for observer errors in [CompositeTraceObserver].
///
/// [observer] is the observer that threw the error.
/// [error] is the exception that was thrown.
/// [stackTrace] is the stack trace of the error.
/// [methodName] is the name of the method that was being called.
typedef ObserverErrorCallback =
    void Function(
      HttpTraceObserver observer,
      Object error,
      StackTrace stackTrace,
      String methodName,
    );

/// Composite observer that delegates to multiple observers.
///
/// If an observer throws an exception, it is caught and optionally
/// reported via [onObserverError]. This ensures that one broken
/// observer doesn't break the entire observability pipeline.
class CompositeTraceObserver implements HttpTraceObserver {
  /// Creates a composite trace observer.
  ///
  /// [observers] are the observers to delegate to.
  /// [onObserverError] is an optional callback for debugging broken observers.
  const CompositeTraceObserver(
    this.observers, {
    this.onObserverError,
  });

  /// The observers to delegate to.
  final List<HttpTraceObserver> observers;

  /// Optional callback for observer errors.
  ///
  /// When an observer throws an exception, this callback is invoked
  /// with details about the error. Useful for debugging and monitoring.
  ///
  /// Example:
  /// ```dart
  /// CompositeTraceObserver(
  ///   [observer1, observer2],
  ///   onObserverError: (observer, error, stackTrace, method) {
  ///     print('Observer ${observer.runtimeType} failed in $method: $error');
  ///   },
  /// )
  /// ```
  final ObserverErrorCallback? onObserverError;

  @override
  void onStart(HttpTrace trace) {
    for (final observer in observers) {
      try {
        observer.onStart(trace);
      } on Object catch (e, st) {
        _reportError(observer, e, st, 'onStart');
      }
    }
  }

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {
    for (final observer in observers) {
      try {
        observer.onFinish(trace, response);
      } on Object catch (e, st) {
        _reportError(observer, e, st, 'onFinish');
      }
    }
  }

  @override
  void onError(HttpTrace trace, HttpError error) {
    for (final observer in observers) {
      try {
        observer.onError(trace, error);
      } on Object catch (e, st) {
        _reportError(observer, e, st, 'onError');
      }
    }
  }

  void _reportError(
    HttpTraceObserver observer,
    Object error,
    StackTrace stackTrace,
    String methodName,
  ) {
    try {
      onObserverError?.call(observer, error, stackTrace, methodName);
    } on Object catch (_) {
      // Prevent error callback from breaking the chain
    }
  }
}

/// Observer that prints trace information for debugging.
class PrintingTraceObserver implements HttpTraceObserver {
  /// Creates a printing trace observer.
  const PrintingTraceObserver({this.prefix = '[HTTP]'});

  /// Prefix for log messages.
  final String prefix;

  @override
  void onStart(HttpTrace trace) {
    // ignore: avoid_print
    print('$prefix --> ${trace.request.method.value} ${trace.request.path}');
  }

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {
    // ignore: avoid_print
    print(
      '$prefix <-- ${response.statusCode} '
      '${trace.request.path} '
      '(${trace.duration?.inMilliseconds}ms)',
    );
  }

  @override
  void onError(HttpTrace trace, HttpError error) {
    // ignore: avoid_print
    print(
      '$prefix <-- ERROR ${error.type} '
      '${trace.request.path} '
      '${error.message ?? ''}',
    );
  }
}
