import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:abstract_http_client/src/models/http_response.dart';
import 'package:meta/meta.dart';

/// HTTP error type classification.
///
/// Provides granular error categorization for better error handling
/// and retry decisions.
enum HttpErrorType {
  /// Connection timeout - failed to establish connection.
  connectionTimeout,

  /// Send timeout - request body sending took too long.
  sendTimeout,

  /// Receive timeout - response receiving took too long.
  receiveTimeout,

  /// Bad SSL certificate - certificate validation failed.
  badCertificate,

  /// Server returned error response (4xx, 5xx).
  badResponse,

  /// Request was cancelled via cancel token.
  cancelled,

  /// Network is unreachable - no internet connection.
  networkUnreachable,

  /// DNS resolution failed - hostname could not be resolved.
  dnsLookupFailed,

  /// Authentication required (401 Unauthorized).
  unauthorized,

  /// Access denied (403 Forbidden).
  forbidden,

  /// Resource not found (404 Not Found).
  notFound,

  /// Rate limited (429 Too Many Requests).
  rateLimited,

  /// Server error (5xx status codes).
  serverError,

  /// Unknown or unclassified error.
  unknown
  ;

  /// Whether this error type is typically retryable.
  ///
  /// Returns `true` for transient errors that may succeed on retry:
  /// - Timeouts (connection, send, receive)
  /// - Network issues (unreachable, DNS lookup failures)
  /// - Rate limiting (429)
  /// - Server errors (5xx)
  ///
  /// Note: `badCertificate` is NOT retryable because certificate issues
  /// are typically persistent (invalid cert, expired, wrong domain).
  /// If your use case has transient cert issues (e.g., clock sync),
  /// use a custom retry policy.
  bool get isRetryable => switch (this) {
    HttpErrorType.connectionTimeout ||
    HttpErrorType.sendTimeout ||
    HttpErrorType.receiveTimeout ||
    HttpErrorType.networkUnreachable ||
    HttpErrorType.dnsLookupFailed ||
    HttpErrorType.rateLimited ||
    HttpErrorType.serverError => true,
    _ => false,
  };

  /// Whether this error type indicates an authentication issue.
  bool get isAuthError => switch (this) {
    HttpErrorType.unauthorized || HttpErrorType.forbidden => true,
    _ => false,
  };

  /// Whether this error type indicates a timeout.
  bool get isTimeout => switch (this) {
    HttpErrorType.connectionTimeout ||
    HttpErrorType.sendTimeout ||
    HttpErrorType.receiveTimeout => true,
    _ => false,
  };

  /// Whether this error type indicates a network issue.
  bool get isNetworkError => switch (this) {
    HttpErrorType.connectionTimeout ||
    HttpErrorType.networkUnreachable ||
    HttpErrorType.dnsLookupFailed => true,
    _ => false,
  };
}

/// Represents an HTTP error.
///
/// Contains comprehensive information about what went wrong,
/// including the original request, any response received,
/// and the underlying cause.
@immutable
class HttpError implements Exception {
  /// Creates an HTTP error.
  const HttpError({
    required this.type,
    required this.request,
    this.response,
    this.cause,
    this.stackTrace,
    this.message,
  });

  /// Creates an HTTP error for a connection timeout.
  const HttpError.connectionTimeout({
    required this.request,
    this.cause,
    this.stackTrace,
    this.message,
  }) : type = HttpErrorType.connectionTimeout,
       response = null;

  /// Creates an HTTP error for an unauthorized response.
  const HttpError.unauthorized({
    required this.request,
    this.response,
    this.cause,
    this.stackTrace,
    this.message,
  }) : type = HttpErrorType.unauthorized;

  /// Creates an HTTP error for a cancelled request.
  const HttpError.cancelled({
    required this.request,
    this.cause,
    this.stackTrace,
    this.message,
  }) : type = HttpErrorType.cancelled,
       response = null;

  /// Creates an HTTP error from a status code.
  factory HttpError.fromStatusCode({
    required int statusCode,
    required HttpRequest request,
    HttpResponse<dynamic>? response,
    Object? cause,
    StackTrace? stackTrace,
    String? message,
  }) {
    final type = _typeFromStatusCode(statusCode);
    return HttpError(
      type: type,
      request: request,
      response: response,
      cause: cause,
      stackTrace: stackTrace,
      message: message,
    );
  }

  /// The error type classification.
  final HttpErrorType type;

  /// The request that caused this error.
  final HttpRequest request;

  /// The response received, if any.
  ///
  /// May be `null` for connection errors, timeouts, etc.
  final HttpResponse<dynamic>? response;

  /// The underlying cause of this error.
  ///
  /// May be a platform exception, socket error, etc.
  final Object? cause;

  /// The stack trace when the error occurred.
  final StackTrace? stackTrace;

  /// A human-readable error message.
  final String? message;

  /// HTTP status code if available.
  int? get statusCode => response?.statusCode;

  /// Whether this error is retryable.
  ///
  /// Convenience getter that delegates to [HttpErrorType.isRetryable].
  bool get isRetryable => type.isRetryable;

  /// Whether this error indicates an authentication issue.
  bool get isAuthError => type.isAuthError;

  /// Whether this error indicates a timeout.
  bool get isTimeout => type.isTimeout;

  /// Whether this error indicates a network issue.
  bool get isNetworkError => type.isNetworkError;

  /// Creates a copy of this error with the given fields replaced.
  HttpError copyWith({
    HttpErrorType? type,
    HttpRequest? request,
    HttpResponse<dynamic>? response,
    Object? cause,
    StackTrace? stackTrace,
    String? message,
  }) {
    return HttpError(
      type: type ?? this.type,
      request: request ?? this.request,
      response: response ?? this.response,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
      message: message ?? this.message,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('HttpError(')..write('type: $type');
    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }
    if (message != null) {
      buffer.write(', message: $message');
    }
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HttpError &&
        other.type == type &&
        other.request == request &&
        other.response == response &&
        other.cause == cause &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(type, request, response, cause, message);
}

/// Determines [HttpErrorType] from HTTP status code.
HttpErrorType _typeFromStatusCode(int statusCode) {
  return switch (statusCode) {
    401 => HttpErrorType.unauthorized,
    403 => HttpErrorType.forbidden,
    404 => HttpErrorType.notFound,
    429 => HttpErrorType.rateLimited,
    >= 500 && < 600 => HttpErrorType.serverError,
    >= 400 && < 500 => HttpErrorType.badResponse,
    _ => HttpErrorType.unknown,
  };
}
