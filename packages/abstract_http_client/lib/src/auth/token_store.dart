import 'dart:async';

import 'package:abstract_http_client/src/auth/token_pair.dart';

/// Storage for authentication tokens.
///
/// Implementations should be thread-safe and persistent (survive app restarts).
///
/// Example implementation with secure storage:
/// ```dart
/// class SecureTokenStore implements TokenStore {
///   final FlutterSecureStorage _storage;
///   final _controller = StreamController<TokenPair?>.broadcast();
///   TokenPair? _cached;
///
///   @override
///   Future<TokenPair?> getTokens() async {
///     if (_cached != null) return _cached;
///     final accessToken = await _storage.read(key: 'access_token');
///     if (accessToken == null) return null;
///     // ... read other fields
///     _cached = TokenPair(accessToken: accessToken, ...);
///     return _cached;
///   }
///
///   @override
///   Future<void> saveTokens(TokenPair tokens) async {
///     await _storage.write(key: 'access_token', value: tokens.accessToken);
///     // ... save other fields
///     _cached = tokens;
///     _controller.add(tokens);
///   }
///
///   @override
///   Future<void> clearTokens() async {
///     await _storage.deleteAll();
///     _cached = null;
///     _controller.add(null);
///   }
///
///   @override
///   Stream<TokenPair?> get tokenChanges => _controller.stream;
/// }
/// ```
abstract class TokenStore {
  /// Get current token pair, or null if not authenticated.
  Future<TokenPair?> getTokens();

  /// Save token pair.
  ///
  /// Should persist tokens and emit on [tokenChanges] stream.
  Future<void> saveTokens(TokenPair tokens);

  /// Clear all tokens (logout).
  ///
  /// Should emit null on [tokenChanges] stream.
  Future<void> clearTokens();

  /// Stream of token changes.
  ///
  /// Emits whenever tokens are saved or cleared.
  Stream<TokenPair?> get tokenChanges;
}

/// In-memory token store for testing or simple use cases.
///
/// Tokens are not persisted and will be lost on app restart.
///
/// **Thread-Safety:** This implementation is safe for use within a single
/// Dart isolate. All operations are synchronous internally and Dart's
/// single-threaded event loop ensures no race conditions within one isolate.
/// For multi-isolate scenarios, use a persistent store with proper locking.
class InMemoryTokenStore implements TokenStore {
  /// Creates an in-memory token store.
  ///
  /// Optionally provide [initialTokens] to start with pre-existing tokens.
  InMemoryTokenStore([TokenPair? initialTokens]) : _tokens = initialTokens;

  TokenPair? _tokens;
  final StreamController<TokenPair?> _controller =
      StreamController<TokenPair?>.broadcast();
  bool _disposed = false;

  @override
  Future<TokenPair?> getTokens() async {
    _checkNotDisposed();
    return _tokens;
  }

  @override
  Future<void> saveTokens(TokenPair tokens) async {
    _checkNotDisposed();
    _tokens = tokens;
    _safeAdd(tokens);
  }

  @override
  Future<void> clearTokens() async {
    _checkNotDisposed();
    _tokens = null;
    _safeAdd(null);
  }

  @override
  Stream<TokenPair?> get tokenChanges => _controller.stream;

  /// Disposes the token store and closes the stream.
  ///
  /// After calling dispose, any operations will throw [StateError].
  /// Returns a [Future] that completes when the stream controller is closed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }

  /// Safely adds a value to the stream controller.
  ///
  /// Guards against race condition where dispose could be called
  /// between _checkNotDisposed() and the add operation.
  void _safeAdd(TokenPair? tokens) {
    if (_disposed || _controller.isClosed) return;
    _controller.add(tokens);
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('InMemoryTokenStore has been disposed');
    }
  }
}
