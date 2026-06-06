import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;

/// Interceptor that handles automatic token refresh.
///
/// Uses [QueuedInterceptor] to ensure thread-safety and prevent
/// multiple simultaneous refresh requests.
class DioTokenRefreshInterceptor extends QueuedInterceptor {
  /// Creates a new token refresh interceptor.
  DioTokenRefreshInterceptor({
    required this.tokenStore,
    required this.refreshDelegate,
    required this.dio,
    required this.config,
    required this.client,
    this.headerName = 'Authorization',
    this.tokenPrefix = 'Bearer',
  });

  /// Token storage.
  final TokenStore tokenStore;

  /// Delegate that performs token refresh.
  final TokenRefreshDelegate refreshDelegate;

  /// Dio instance for retrying requests.
  final Dio dio;

  /// Configuration for token refresh behavior.
  final TokenRefreshConfig config;

  /// HTTP client for refresh context.
  final HttpClient client;

  /// Header name for authorization.
  final String headerName;

  /// Prefix for the token (e.g., 'Bearer').
  final String tokenPrefix;

  /// Key used to mark requests that have already been retried after token refresh.
  /// This prevents infinite loops when the server returns 401 even after refresh.
  static const _alreadyRefreshedKey = '_alreadyRefreshed';

  /// Completer for tracking ongoing refresh.
  ///
  /// Once completed, the completer stays to allow late arrivals to get the result.
  Completer<TokenPair?>? _refreshCompleter;

  /// Dedicated Dio instance for retry requests.
  ///
  /// Created lazily on first use to avoid QueuedInterceptor deadlock.
  /// Reused across retries to prevent resource leak from creating
  /// new Dio instances on each retry.
  Dio? _retryDio;

  /// Whether this interceptor has been disposed.
  bool _disposed = false;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 errors
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Check if this request already went through refresh cycle.
    // Prevents infinite loops when server returns 401 even after refresh.
    if (err.requestOptions.extra[_alreadyRefreshedKey] == true) {
      await _safeCallOnForceLogout();
      return handler.reject(err);
    }

    // Check if this request should trigger refresh
    final httpError = _toHttpError(err);
    if (!config.shouldRefresh(httpError)) {
      return handler.next(err);
    }

    // Skip refresh for refresh endpoint itself
    if (_isRefreshEndpoint(err.requestOptions)) {
      return handler.next(err);
    }

    try {
      // Get new tokens (handles deduplication)
      final newTokens = await _refreshTokens();

      if (newTokens == null) {
        // Refresh failed, propagate 401
        await _safeCallOnForceLogout();
        return handler.reject(err);
      }

      // Retry original request with new token
      final response = await _retryRequest(err.requestOptions, newTokens);
      return handler.resolve(response);
    } on Object catch (e, stackTrace) {
      // Refresh request failed
      if (e is DioException && e.response?.statusCode == 401) {
        await _safeCallOnForceLogout();
      }
      // Propagate the actual error that occurred during refresh,
      // not the original 401 error.
      if (e is DioException) {
        return handler.reject(e);
      }
      // Wrap other errors in DioException for consistent handling
      // Include stack trace for debugging
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: e,
          message: 'Token refresh failed: $e',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Safely calls onForceLogout callback, catching any errors.
  Future<void> _safeCallOnForceLogout() async {
    try {
      await config.onForceLogout?.call();
    } on Object catch (e) {
      // Log but don't propagate - logout callback shouldn't break error handling
      assert(
        () {
          // ignore: avoid_print
          print('DioTokenRefreshInterceptor: onForceLogout threw: $e');
          return true;
        }(),
        'onForceLogout callback failed',
      );
    }
  }

  /// Refreshes tokens, ensuring only one refresh happens at a time.
  ///
  /// Uses atomic check-and-set pattern to prevent race conditions where
  /// multiple concurrent calls could start multiple refresh operations.
  ///
  /// Thread-safety: In Dart's single-threaded event loop, the check-and-set
  /// is atomic because there's no `await` between reading `_refreshCompleter`
  /// and assigning a new one. QueuedInterceptor also serializes requests.
  Future<TokenPair?> _refreshTokens() async {
    // Capture current state into local variable - atomic read
    final existing = _refreshCompleter;

    // If refresh is already in progress, wait for it
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    // Start new refresh - assign immediately before any await
    // This is atomic in Dart's single-threaded model
    final completer = Completer<TokenPair?>();
    _refreshCompleter = completer;

    try {
      final currentTokens = await tokenStore.getTokens();

      // Validate refresh token exists
      if (currentTokens?.refreshToken == null) {
        completer.complete(null);
        return null;
      }

      final context = TokenRefreshContext(
        currentTokens: currentTokens,
        client: client,
      );

      final newTokens = await refreshDelegate.refresh(context);

      if (newTokens != null) {
        await tokenStore.saveTokens(newTokens);
        _safeCallOnTokenRefreshed(newTokens);
      }

      completer.complete(newTokens);
      return newTokens;
    } on Object catch (e) {
      // Reset completer after error so next request can retry refresh.
      // This allows error recovery instead of returning stale error to all
      // subsequent requests.
      _refreshCompleter = null;

      // Complete the current completer with error for anyone already waiting
      if (!completer.isCompleted) {
        completer.completeError(e);
      }

      // Propagate error to direct caller. Use rethrow to preserve stack trace.
      // The completer.future will propagate error to waiters via completeError.
      rethrow;
    }
  }

  /// Safely calls onTokenRefreshed callback, catching any errors.
  void _safeCallOnTokenRefreshed(TokenPair tokens) {
    try {
      config.onTokenRefreshed?.call(tokens);
    } on Object catch (e) {
      // Log but don't propagate - callback shouldn't break token refresh flow
      assert(
        () {
          // ignore: avoid_print
          print('DioTokenRefreshInterceptor: onTokenRefreshed threw: $e');
          return true;
        }(),
        'onTokenRefreshed callback failed',
      );
    }
  }

  /// Retries the failed request with new tokens.
  ///
  /// If the retry also returns 401, this method throws without going through
  /// the interceptor chain again (to prevent QueuedInterceptor deadlock).
  Future<Response<dynamic>> _retryRequest(
    RequestOptions options,
    TokenPair tokens,
  ) async {
    // Check if request was cancelled during token refresh
    final cancelToken = options.cancelToken;
    if (cancelToken != null && cancelToken.isCancelled) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'Request cancelled during token refresh',
      );
    }

    // Mark request as already refreshed to prevent infinite loops.
    options.extra[_alreadyRefreshedKey] = true;

    // Update Authorization header
    options.headers[headerName] = '$tokenPrefix ${tokens.accessToken}';

    // Use dedicated retry Dio instance to avoid QueuedInterceptor deadlock.
    // QueuedInterceptor blocks nested requests, so we can't use the same Dio
    // instance for retry while still inside onError.
    // The retry Dio is reused across retries to prevent resource leaks.
    return _getRetryDio().fetch(options);
  }

  /// Checks if the request is to the refresh endpoint.
  ///
  /// Uses exact path comparison (after normalization) to prevent false matches.
  /// For example, with refreshEndpoint="/auth/refresh", this correctly rejects
  /// "/auth/refresh-token" or "/some/auth/refresh/extra".
  bool _isRefreshEndpoint(RequestOptions options) {
    final refreshEndpoint = config.refreshEndpoint;

    // Normalize paths by removing leading/trailing slashes for comparison
    final normalizedEndpoint = refreshEndpoint.replaceAll(
      RegExp(r'^/+|/+$'),
      '',
    );
    final requestPath = options.path.replaceAll(RegExp(r'^/+|/+$'), '');
    final uriPath = options.uri.path.replaceAll(RegExp(r'^/+|/+$'), '');

    // Check for exact match or path ending with the endpoint
    // (to handle cases where baseUrl is prepended)
    return requestPath == normalizedEndpoint ||
        uriPath == normalizedEndpoint ||
        requestPath.endsWith('/$normalizedEndpoint') ||
        uriPath.endsWith('/$normalizedEndpoint');
  }

  /// Converts DioException to HttpError for shouldRefresh check.
  HttpError _toHttpError(DioException err) {
    return HttpError(
      type: HttpErrorType.unauthorized,
      request: HttpRequest(
        method: HttpMethod.values.firstWhere(
          (m) => m.value.toUpperCase() == err.requestOptions.method,
          orElse: () => HttpMethod.get,
        ),
        path: err.requestOptions.path,
      ),
      message: err.message,
    );
  }

  /// Returns the retry Dio instance, creating it lazily if needed.
  ///
  /// Uses a separate Dio without interceptors to avoid QueuedInterceptor
  /// deadlock when retrying requests from within onError.
  Dio _getRetryDio() {
    if (_disposed) {
      throw StateError(
        'DioTokenRefreshInterceptor has been disposed',
      );
    }

    return _retryDio ??= Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: dio.options.connectTimeout,
        receiveTimeout: dio.options.receiveTimeout,
        sendTimeout: dio.options.sendTimeout,
      ),
    );
  }

  /// Disposes of resources held by this interceptor.
  ///
  /// After calling dispose, the interceptor should not be used.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _retryDio?.close();
    _retryDio = null;
    _refreshCompleter = null;
  }
}
