import 'dart:async';

import 'package:abstract_http_client/src/auth/token_pair.dart';
import 'package:abstract_http_client/src/client/http_client.dart';
import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/utils/cancel_token.dart';
import 'package:meta/meta.dart';

/// Delegate for token refresh logic.
///
/// Implementations define how to obtain new tokens when the current
/// access token expires.
///
/// Example implementation:
/// ```dart
/// class MyRefreshDelegate implements TokenRefreshDelegate {
///   @override
///   Future<TokenPair?> refresh(TokenRefreshContext context) async {
///     final refreshToken = context.currentTokens?.refreshToken;
///     if (refreshToken == null) return null;
///
///     final response = await context.client.post<Map<String, dynamic>>(
///       '/auth/refresh',
///       body: HttpBody.json({'refresh_token': refreshToken}),
///     );
///
///     return TokenPair.fromJson(response.data!);
///   }
/// }
/// ```
abstract class TokenRefreshDelegate {
  /// Attempt to refresh tokens.
  ///
  /// Returns new [TokenPair] on success, or null if refresh failed
  /// and user should be logged out.
  ///
  /// Throws [HttpError] on network errors.
  Future<TokenPair?> refresh(TokenRefreshContext context);
}

/// Context passed to [TokenRefreshDelegate].
@immutable
class TokenRefreshContext {
  /// Creates a token refresh context.
  const TokenRefreshContext({
    required this.currentTokens,
    required this.client,
    this.cancelToken,
  });

  /// The current tokens (may be expired).
  final TokenPair? currentTokens;

  /// HTTP client to use for refresh request.
  ///
  /// Note: Be careful about recursive refresh when using this client.
  final HttpClient client;

  /// Optional cancellation token.
  final CancelToken? cancelToken;
}

/// Configuration for token refresh behavior.
@immutable
class TokenRefreshConfig {
  /// Creates a token refresh configuration.
  const TokenRefreshConfig({
    required this.refreshEndpoint,
    this.mode = TokenRefreshMode.reusePrimaryClient,
    this.refreshClientBuilder,
    this.shouldRefresh = _defaultShouldRefresh,
    this.onTokenRefreshed,
    this.onForceLogout,
    this.accessTokenKey = 'access_token',
    this.refreshTokenKey = 'refresh_token',
    this.refreshBeforeExpiry = const Duration(minutes: 1),
  });

  /// Endpoint for refresh requests.
  final String refreshEndpoint;

  /// How to make refresh requests.
  final TokenRefreshMode mode;

  /// Custom client builder for refresh requests.
  ///
  /// Required if [mode] is [TokenRefreshMode.separateClient].
  final HttpClient Function()? refreshClientBuilder;

  /// Predicate to determine if error should trigger refresh.
  final bool Function(HttpError error) shouldRefresh;

  /// Called when tokens are successfully refreshed.
  final void Function(TokenPair tokens)? onTokenRefreshed;

  /// Called when refresh fails and user should be logged out.
  final FutureOr<void> Function()? onForceLogout;

  /// Key for access token in response JSON.
  final String accessTokenKey;

  /// Key for refresh token in response JSON.
  final String refreshTokenKey;

  /// Duration before expiry to proactively refresh.
  ///
  /// If set, tokens will be refreshed when they expire within this duration.
  final Duration refreshBeforeExpiry;

  /// Creates a copy with the given fields replaced.
  TokenRefreshConfig copyWith({
    String? refreshEndpoint,
    TokenRefreshMode? mode,
    HttpClient Function()? refreshClientBuilder,
    bool Function(HttpError error)? shouldRefresh,
    void Function(TokenPair tokens)? onTokenRefreshed,
    FutureOr<void> Function()? onForceLogout,
    String? accessTokenKey,
    String? refreshTokenKey,
    Duration? refreshBeforeExpiry,
  }) {
    return TokenRefreshConfig(
      refreshEndpoint: refreshEndpoint ?? this.refreshEndpoint,
      mode: mode ?? this.mode,
      refreshClientBuilder: refreshClientBuilder ?? this.refreshClientBuilder,
      shouldRefresh: shouldRefresh ?? this.shouldRefresh,
      onTokenRefreshed: onTokenRefreshed ?? this.onTokenRefreshed,
      onForceLogout: onForceLogout ?? this.onForceLogout,
      accessTokenKey: accessTokenKey ?? this.accessTokenKey,
      refreshTokenKey: refreshTokenKey ?? this.refreshTokenKey,
      refreshBeforeExpiry: refreshBeforeExpiry ?? this.refreshBeforeExpiry,
    );
  }

  static bool _defaultShouldRefresh(HttpError error) =>
      error.type == HttpErrorType.unauthorized || error.statusCode == 401;

  // =========================================================================
  // Predefined shouldRefresh strategies
  // =========================================================================

  /// Strategy that triggers refresh on 401 Unauthorized.
  ///
  /// This is the default behavior.
  static bool shouldRefreshOn401(HttpError error) =>
      error.type == HttpErrorType.unauthorized || error.statusCode == 401;

  /// Strategy that triggers refresh on 401 or 403.
  ///
  /// Useful for APIs that return 403 when token is expired.
  static bool shouldRefreshOn401Or403(HttpError error) =>
      error.type == HttpErrorType.unauthorized ||
      error.statusCode == 401 ||
      error.statusCode == 403;

  /// Strategy that triggers refresh on specific status codes.
  ///
  /// Example:
  /// ```dart
  /// TokenRefreshConfig(
  ///   refreshEndpoint: '/auth/refresh',
  ///   shouldRefresh: TokenRefreshConfig.shouldRefreshOnStatusCodes({401, 403, 419}),
  /// )
  /// ```
  static bool Function(HttpError) shouldRefreshOnStatusCodes(
    Set<int> statusCodes,
  ) {
    return (error) => statusCodes.contains(error.statusCode);
  }

  /// Strategy that triggers refresh on specific error types.
  ///
  /// Example:
  /// ```dart
  /// TokenRefreshConfig(
  ///   refreshEndpoint: '/auth/refresh',
  ///   shouldRefresh: TokenRefreshConfig.shouldRefreshOnErrorTypes({
  ///     HttpErrorType.unauthorized,
  ///     HttpErrorType.forbidden,
  ///   }),
  /// )
  /// ```
  static bool Function(HttpError) shouldRefreshOnErrorTypes(
    Set<HttpErrorType> errorTypes,
  ) {
    return (error) => errorTypes.contains(error.type);
  }
}

/// Mode for making refresh requests.
enum TokenRefreshMode {
  /// Reuse the primary HttpClient.
  ///
  /// Interceptors are bypassed for refresh requests to avoid recursion.
  /// Simpler but requires careful interceptor ordering.
  reusePrimaryClient,

  /// Use a separate clean HttpClient for refresh.
  ///
  /// No interceptors, completely isolated.
  /// Safer but requires additional configuration.
  separateClient,
}
