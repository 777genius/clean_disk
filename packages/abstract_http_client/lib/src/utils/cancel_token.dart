import 'dart:async';

import 'package:meta/meta.dart';

/// Token for cancelling HTTP requests.
///
/// Thread-safe. Can be shared between multiple requests.
/// Designed for future compatibility with dart:async AbortSignal.
///
/// Example:
/// ```dart
/// final token = CancelToken();
///
/// // Start a request
/// final future = client.get('/slow-endpoint', cancelToken: token);
///
/// // Cancel after 5 seconds
/// Future.delayed(Duration(seconds: 5), () => token.cancel('Too slow'));
///
/// try {
///   final response = await future;
/// } on CancelException catch (e) {
///   print('Request cancelled: ${e.message}');
/// }
/// ```
class CancelToken {
  /// Creates a new cancel token.
  CancelToken();

  /// Creates a CancelToken that automatically cancels after [duration].
  ///
  /// Example:
  /// ```dart
  /// final token = CancelToken.timeout(Duration(seconds: 30));
  /// await client.get('/endpoint', cancelToken: token);
  /// ```
  factory CancelToken.timeout(Duration duration) {
    final token = CancelToken();
    Future<void>.delayed(duration, () {
      if (!token.isCancelled) {
        token.cancel('Request timeout after $duration');
      }
    });
    return token;
  }

  final Completer<CancelException> _completer = Completer<CancelException>();
  CancelException? _cancelException;
  final List<void Function()> _listeners = [];

  /// Whether the token has been cancelled.
  bool get isCancelled => _cancelException != null;

  /// The cancellation reason, if cancelled.
  CancelException? get cancelException => _cancelException;

  /// Future that completes with error when the token is cancelled.
  ///
  /// Useful for races with try/catch:
  /// ```dart
  /// try {
  ///   await Future.any([
  ///     someOperation(),
  ///     token.whenCancelled,
  ///   ]);
  /// } on CancelException catch (e) {
  ///   print('Cancelled: ${e.message}');
  /// }
  /// ```
  Future<Never> get whenCancelled => _completer.future.then((e) => throw e);

  /// Cancel all requests using this token.
  ///
  /// If already cancelled, this is a no-op.
  /// All registered listeners will be notified.
  ///
  /// Thread-safe: Uses defensive programming to handle potential race
  /// conditions. Listeners are copied before iteration to prevent
  /// ConcurrentModificationError if a listener adds/removes listeners.
  void cancel([String? reason]) {
    // Double-check pattern: first quick check without state modification
    if (isCancelled) return;

    final exception = CancelException(reason);

    // Atomic-like operation: set exception and complete in sequence.
    // If another call raced past the first check, completer.complete
    // will throw StateError which we catch.
    try {
      // Set exception BEFORE completing to ensure isCancelled returns true
      // for any subsequent checks
      _cancelException = exception;
      _completer.complete(exception);
    }
    // ignore: avoid_catching_errors
    on StateError {
      // Intentional: StateError is caught here as a defensive programming
      // pattern to handle potential race conditions where multiple cancel()
      // calls might occur concurrently. This is a deliberate design choice.
      return;
    }

    // Copy listeners before iteration to prevent ConcurrentModificationError
    // if a listener calls addListener() or removeListener() during iteration.
    final listenersCopy = List<void Function()>.of(_listeners);
    _listeners.clear();

    for (final listener in listenersCopy) {
      try {
        listener();
      } on Object catch (_) {
        // Ignore listener errors to ensure all listeners get called
      }
    }
  }

  /// Add a listener called on cancellation.
  ///
  /// If already cancelled, the listener is called immediately.
  ///
  /// Thread-safe: Uses double-check pattern to prevent race condition
  /// where cancel() could be called between checking isCancelled and
  /// adding to _listeners, which would cause the listener to be lost.
  void addListener(void Function() listener) {
    if (isCancelled) {
      listener();
      return;
    }

    _listeners.add(listener);

    // Double-check after add: if cancel() was called between the first check
    // and adding the listener, the listener might have been added after
    // cancel() cleared _listeners. Re-check and call if needed.
    if (isCancelled && !_listeners.contains(listener)) {
      listener();
    }
  }

  /// Remove a cancellation listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Throw if this token has been cancelled.
  ///
  /// Useful for checking cancellation state at various points:
  /// ```dart
  /// cancelToken.throwIfCancelled();
  /// await step1();
  /// cancelToken.throwIfCancelled();
  /// await step2();
  /// ```
  void throwIfCancelled() {
    if (isCancelled) throw _cancelException!;
  }

  @override
  String toString() {
    return 'CancelToken(isCancelled: $isCancelled'
        '${_cancelException != null ? ', reason: ${_cancelException!.message}' : ''})';
  }
}

/// Exception thrown when a request is cancelled.
@immutable
class CancelException implements Exception {
  /// Creates a cancel exception.
  const CancelException([this.message]);

  /// The cancellation reason.
  final String? message;

  @override
  String toString() => 'CancelException: ${message ?? 'Request cancelled'}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancelException && other.message == message;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);
}
