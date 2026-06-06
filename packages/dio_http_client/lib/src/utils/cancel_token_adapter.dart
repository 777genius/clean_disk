import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart' as http;
import 'package:dio/dio.dart' as dio;

/// Adapter for converting between abstract CancelToken and Dio CancelToken.
///
/// Uses [Expando] for caching to ensure the same abstract token always
/// returns the same Dio token, preventing resource leaks and ensuring
/// proper cancellation propagation.
///
/// **Thread Safety:** This class is designed for single-threaded Dart.
/// Do not call [dispose] while [toDio] may be executing on the same token.
/// Typical usage: call [dispose] only after all requests using this token
/// have completed (e.g., in a finally block after the request finishes).
///
/// **Memory Management:** The [Expando] class uses weak references, so
/// cached entries are automatically cleaned up when the token is garbage
/// collected. Explicit [dispose] is only needed when you want to force
/// cleanup before GC or to reset the adapter state for a token.
///
/// **Important:** Call [cleanup] after the request completes to remove
/// listeners and prevent memory leaks for long-lived tokens.
class CancelTokenAdapter {
  CancelTokenAdapter._();

  /// Cache for abstract -> Dio token mapping.
  static final Expando<dio.CancelToken> _toDioCache = Expando<dio.CancelToken>(
    'CancelTokenAdapter._toDioCache',
  );

  /// Cache for Dio -> abstract token mapping.
  static final Expando<http.CancelToken> _fromDioCache =
      Expando<http.CancelToken>(
        'CancelTokenAdapter._fromDioCache',
      );

  /// Cache for storing listeners for cleanup.
  static final Expando<void Function()> _listenerCache =
      Expando<void Function()>(
        'CancelTokenAdapter._listenerCache',
      );

  /// Cache for tracking disposed tokens to ensure idempotency.
  static final Expando<bool> _disposedCache = Expando<bool>(
    'CancelTokenAdapter._disposedCache',
  );

  /// Converts abstract [http.CancelToken] to Dio [dio.CancelToken].
  ///
  /// Returns cached Dio token if already converted, or creates a new one.
  /// Listener is attached only once when creating a new Dio token.
  ///
  /// **Note:** After [cleanup], the same Dio token is reused but listener
  /// is NOT re-attached. This prevents listener accumulation for long-lived
  /// tokens used across multiple requests. The listener reference remains
  /// valid even after cleanup because it captures the Dio token in closure.
  static dio.CancelToken? toDio(http.CancelToken? token) {
    if (token == null) return null;

    // Check cache first
    var dioToken = _toDioCache[token];
    final isNewToken = dioToken == null;

    if (isNewToken) {
      // Create new Dio token and cache it
      dioToken = dio.CancelToken();
      _toDioCache[token] = dioToken;

      // Add listener ONLY for new tokens to prevent accumulation
      // The listener captures dioToken in closure and stays valid
      void listener() {
        try {
          if (!dioToken!.isCancelled) {
            dioToken.cancel(token.cancelException?.message);
          }
        } on Object catch (e) {
          // Log but don't propagate - listener errors shouldn't break cancel flow
          assert(
            () {
              // ignore: avoid_print
              print('CancelTokenAdapter: listener failed: $e');
              return true;
            }(),
            'CancelTokenAdapter listener failed',
          );
        }
      }

      _listenerCache[token] = listener;
      token.addListener(listener);
    }

    // If already cancelled, cancel Dio token immediately
    if (token.isCancelled && !dioToken.isCancelled) {
      dioToken.cancel(token.cancelException?.message);
    }

    return dioToken;
  }

  /// Cleanup adapter resources for a token.
  ///
  /// This method is now a no-op for listener cleanup because:
  /// 1. Listener is added only once when Dio token is created (in [toDio])
  /// 2. The same listener is reused across all requests with this token
  /// 3. Removing listener would break cancellation for subsequent requests
  ///
  /// **Memory Management:** The [Expando] class uses weak references, so
  /// all entries (dioToken, listener) are automatically cleaned up when
  /// the key token is garbage collected. No explicit cleanup is needed.
  ///
  /// This method is kept for API compatibility but does nothing.
  /// Use [dispose] if you need to fully release a token's resources.
  static void cleanup(http.CancelToken? token) {
    // No-op: listener stays attached for token reuse across requests.
    // Expando weak references handle cleanup when token is GC'd.
  }

  /// Fully removes all cached data for a token.
  ///
  /// Call this when you're completely done with a token and want to
  /// ensure no references remain. After calling this, [toDio] will
  /// create a new Dio token on next call.
  ///
  /// This removes the listener from the abstract token and clears all caches.
  ///
  /// **Idempotency:** This method is idempotent - calling it multiple times
  /// on the same token has no effect after the first call.
  ///
  /// **Usage Pattern:**
  /// ```dart
  /// final token = CancelToken();
  /// try {
  ///   await client.send(request, cancelToken: token);
  /// } finally {
  ///   CancelTokenAdapter.dispose(token); // Safe cleanup
  /// }
  /// ```
  ///
  /// **Warning:** Do not call [dispose] while another thread/isolate might
  /// be calling [toDio] on the same token. In single-threaded Dart this is
  /// generally safe as long as dispose is called after the request completes.
  static void dispose(http.CancelToken? token) {
    if (token == null) return;

    // Check if already disposed - ensure idempotency
    if (_disposedCache[token] ?? false) return;
    _disposedCache[token] = true;

    // Remove listener from abstract token
    final listener = _listenerCache[token];
    if (listener != null) {
      token.removeListener(listener);
      _listenerCache[token] = null;
    }

    // Clear Dio token cache - next toDio() will create fresh token
    _toDioCache[token] = null;
  }

  /// Converts Dio [dio.CancelToken] to abstract [http.CancelToken].
  ///
  /// Returns cached abstract token if already converted, or creates a new one.
  static http.CancelToken fromDio(dio.CancelToken dioToken) {
    // Check cache first
    final cached = _fromDioCache[dioToken];
    if (cached != null) return cached;

    // Create new abstract token and cache it
    final token = http.CancelToken();
    _fromDioCache[dioToken] = token;

    // Link the tokens - when Dio token is cancelled, cancel abstract token
    unawaited(
      dioToken.whenCancel.then((_) {
        if (!token.isCancelled) {
          token.cancel(dioToken.cancelError?.message);
        }
      }),
    );

    // If already cancelled, cancel abstract token immediately
    if (dioToken.isCancelled) {
      token.cancel(dioToken.cancelError?.message);
    }

    return token;
  }
}

/// Extension on abstract CancelToken for easy Dio conversion.
extension CancelTokenDioExtension on http.CancelToken {
  /// Converts this CancelToken to a Dio CancelToken.
  ///
  /// Always returns the same Dio token for repeated calls on the same instance.
  dio.CancelToken toDio() => CancelTokenAdapter.toDio(this)!;
}

/// Extension on Dio CancelToken for easy abstract conversion.
extension DioCancelTokenExtension on dio.CancelToken {
  /// Converts this Dio CancelToken to an abstract CancelToken.
  ///
  /// Always returns the same abstract token for repeated calls on the same instance.
  http.CancelToken toAbstract() => CancelTokenAdapter.fromDio(this);
}
