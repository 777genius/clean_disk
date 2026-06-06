import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;

/// Interceptor that adds Authorization header to requests.
///
/// Reads tokens from [TokenStore] and adds Bearer token to requests.
///
/// ## Error Handling
///
/// If [TokenStore.getTokens] throws an exception:
/// - If [onTokenError] is provided, it will be called with the error
/// - If [onTokenError] returns true, the request continues without token
/// - If [onTokenError] returns false or is not provided, the request continues
///   without token (backwards compatible behavior)
///
/// To fail the request on token error, use [onTokenError] and throw or
/// call `handler.reject()` manually.
class DioAuthInterceptor extends Interceptor {
  /// Creates a new auth interceptor.
  DioAuthInterceptor({
    required this.tokenStore,
    this.headerName = 'Authorization',
    this.tokenPrefix = 'Bearer',
    this.shouldAddToken,
    this.onTokenError,
  });

  /// Token storage.
  final TokenStore tokenStore;

  /// Header name for authorization.
  final String headerName;

  /// Prefix for the token (e.g., 'Bearer').
  final String tokenPrefix;

  /// Optional predicate to determine if token should be added.
  ///
  /// If null, token is added to all requests.
  final bool Function(RequestOptions options)? shouldAddToken;

  /// Optional callback when token retrieval fails.
  ///
  /// Called with the error and stack trace when [TokenStore.getTokens] throws.
  /// Use this for logging, analytics, or triggering side effects.
  ///
  /// **Note:** The return value is currently ignored for backwards compatibility.
  /// The request always continues without token after this callback.
  /// To fail the request on token error, throw from within the callback.
  ///
  /// Example with logging:
  /// ```dart
  /// DioAuthInterceptor(
  ///   tokenStore: tokenStore,
  ///   onTokenError: (error, stackTrace) {
  ///     logger.error('Failed to get token', error, stackTrace);
  ///     return true; // Return value ignored - request continues without token
  ///   },
  /// )
  /// ```
  final bool Function(Object error, StackTrace stackTrace)? onTokenError;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if we should add token to this request
    if (shouldAddToken != null && !shouldAddToken!(options)) {
      return handler.next(options);
    }

    // Skip if Authorization header is already set
    if (options.headers.containsKey(headerName)) {
      return handler.next(options);
    }

    try {
      final tokens = await tokenStore.getTokens();

      if (tokens != null && tokens.accessToken.isNotEmpty) {
        options.headers[headerName] = '$tokenPrefix ${tokens.accessToken}';
      }

      // FIX: Explicit return for clarity and to prevent accidental code after
      return handler.next(options);
    } on Object catch (e, stackTrace) {
      // Call error callback if provided
      // If callback throws, propagate as request failure (user wants to abort)
      if (onTokenError != null) {
        try {
          onTokenError!(e, stackTrace);
        } on Object catch (callbackError, callbackStackTrace) {
          // Callback threw - this is intentional to abort the request
          return handler.reject(
            DioException(
              requestOptions: options,
              error: callbackError,
              message: 'onTokenError callback failed: $callbackError',
              stackTrace: callbackStackTrace,
            ),
          );
        }
      }

      // Log original error in debug mode for debugging
      assert(
        () {
          // ignore: avoid_print
          print('DioAuthInterceptor: Failed to get tokens: $e\n$stackTrace');
          return true;
        }(),
        'Token retrieval failed',
      );

      // Continue without token for backwards compatibility
      return handler.next(options);
    }
  }
}
