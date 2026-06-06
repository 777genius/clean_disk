import 'package:meta/meta.dart';

/// Token pair for authentication.
///
/// Contains access and refresh tokens with optional expiration times.
/// Immutable by design.
@immutable
class TokenPair {
  /// Creates a token pair.
  const TokenPair({
    required this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
    this.tokenType = 'Bearer',
    this.scope,
  });

  /// Creates a token pair from a JSON response.
  ///
  /// Supports common OAuth2 response formats:
  /// ```json
  /// {
  ///   "access_token": "...",
  ///   "refresh_token": "...",
  ///   "expires_in": 3600,
  ///   "token_type": "Bearer",
  ///   "scope": "read write"
  /// }
  /// ```
  ///
  /// ## Validation behavior:
  /// - Throws [ArgumentError] if access_token is missing or empty
  /// - Invalid/negative `expires_in` values are ignored (token treated as non-expiring)
  /// - Very large `expires_in` values are capped at ~10 years to prevent overflow
  factory TokenPair.fromJson(
    Map<String, dynamic> json, {
    String accessTokenKey = 'access_token',
    String refreshTokenKey = 'refresh_token',
    String expiresInKey = 'expires_in',
    String tokenTypeKey = 'token_type',
    String scopeKey = 'scope',
  }) {
    final accessToken = json[accessTokenKey] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw ArgumentError('Missing or empty access token');
    }

    DateTime? accessTokenExpiresAt;
    final expiresIn = json[expiresInKey];
    if (expiresIn != null) {
      // FIX: Use safe parsing with validation to prevent FormatException
      // and DateTime overflow
      int? seconds;
      if (expiresIn is int) {
        seconds = expiresIn;
      } else if (expiresIn is num) {
        seconds = expiresIn.toInt();
      } else {
        // Try to parse string representation
        seconds = int.tryParse('$expiresIn');
      }

      // Only set expiration if we have a valid positive seconds value
      // Cap at 10 years (315360000 seconds) to prevent DateTime overflow
      if (seconds != null && seconds > 0) {
        const maxSeconds = 315360000; // ~10 years
        final cappedSeconds = seconds > maxSeconds ? maxSeconds : seconds;
        accessTokenExpiresAt = DateTime.now().add(
          Duration(seconds: cappedSeconds),
        );
      }
    }

    return TokenPair(
      accessToken: accessToken,
      refreshToken: json[refreshTokenKey] as String?,
      accessTokenExpiresAt: accessTokenExpiresAt,
      tokenType: json[tokenTypeKey] as String? ?? 'Bearer',
      scope: json[scopeKey] as String?,
    );
  }

  /// The access token used for API authentication.
  final String accessToken;

  /// The refresh token used to obtain new access tokens.
  final String? refreshToken;

  /// When the access token expires.
  final DateTime? accessTokenExpiresAt;

  /// When the refresh token expires.
  final DateTime? refreshTokenExpiresAt;

  /// The token type (typically "Bearer").
  final String tokenType;

  /// The scope of the access granted.
  final String? scope;

  /// Whether the access token has expired.
  ///
  /// Returns `false` if [accessTokenExpiresAt] is not set.
  bool get isAccessTokenExpired {
    if (accessTokenExpiresAt == null) return false;
    return DateTime.now().isAfter(accessTokenExpiresAt!);
  }

  /// Whether the access token will expire within [duration].
  bool accessTokenExpiresWithin(Duration duration) {
    if (accessTokenExpiresAt == null) return false;
    return DateTime.now().add(duration).isAfter(accessTokenExpiresAt!);
  }

  /// Whether the refresh token has expired.
  ///
  /// Returns `false` if [refreshTokenExpiresAt] is not set.
  bool get isRefreshTokenExpired {
    if (refreshTokenExpiresAt == null) return false;
    return DateTime.now().isAfter(refreshTokenExpiresAt!);
  }

  /// Whether a refresh token is available.
  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;

  /// The Authorization header value.
  String get authorizationHeader => '$tokenType $accessToken';

  /// Creates a copy with the given fields replaced.
  TokenPair copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
    String? tokenType,
    String? scope,
  }) {
    return TokenPair(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      tokenType: tokenType ?? this.tokenType,
      scope: scope ?? this.scope,
    );
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson({
    String accessTokenKey = 'access_token',
    String refreshTokenKey = 'refresh_token',
    String tokenTypeKey = 'token_type',
    String scopeKey = 'scope',
  }) {
    return {
      accessTokenKey: accessToken,
      if (refreshToken != null) refreshTokenKey: refreshToken,
      tokenTypeKey: tokenType,
      if (scope != null) scopeKey: scope,
    };
  }

  @override
  String toString() {
    return 'TokenPair('
        'accessToken: ${_maskToken(accessToken)}, '
        'refreshToken: ${refreshToken != null ? _maskToken(refreshToken!) : null}, '
        'accessTokenExpiresAt: $accessTokenExpiresAt, '
        'tokenType: $tokenType'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenPair &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.accessTokenExpiresAt == accessTokenExpiresAt &&
        other.refreshTokenExpiresAt == refreshTokenExpiresAt &&
        other.tokenType == tokenType &&
        other.scope == scope;
  }

  @override
  int get hashCode => Object.hash(
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    refreshTokenExpiresAt,
    tokenType,
    scope,
  );
}

/// Masks a token for safe logging.
String _maskToken(String token) {
  if (token.length <= 8) return '***';
  return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
}
