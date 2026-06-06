import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:meta/meta.dart';

/// Policy for retrying failed HTTP requests.
///
/// Implementations determine whether a request should be retried
/// and calculate the delay before each retry attempt.
///
/// Example implementation:
/// ```dart
/// class SimpleRetryPolicy implements RetryPolicy {
///   @override
///   bool shouldRetry(HttpError error, int attempt) {
///     return attempt < 3 && error.isRetryable;
///   }
///
///   @override
///   Duration getDelay(int attempt) {
///     return Duration(seconds: attempt);
///   }
/// }
/// ```
abstract class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy();

  /// Determines if a request should be retried after an error.
  ///
  /// [error] is the error that occurred.
  /// [attempt] is the current attempt number (1-based).
  bool shouldRetry(HttpError error, int attempt);

  /// Gets the delay before the next retry attempt.
  ///
  /// [attempt] is the current attempt number (1-based).
  Duration getDelay(int attempt);

  /// Optional hook to modify the request before retry.
  ///
  /// Default implementation returns the request unchanged.
  HttpRequest prepareRetry(HttpRequest request, int attempt) => request;
}

/// Retry policy with exponential backoff.
///
/// Delays increase exponentially with each attempt:
/// - Attempt 1: [initialDelay]
/// - Attempt 2: [initialDelay] * [multiplier]
/// - Attempt 3: [initialDelay] * [multiplier]^2
/// - etc.
///
/// The delay is capped at [maxDelay].
@immutable
class ExponentialBackoffPolicy extends RetryPolicy {
  /// Creates an exponential backoff retry policy.
  const ExponentialBackoffPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.retryableErrorTypes,
  });

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for calculating exponential delay.
  final double multiplier;

  /// Error types that should trigger a retry.
  ///
  /// If `null`, uses [HttpErrorType.isRetryable].
  final Set<HttpErrorType>? retryableErrorTypes;

  @override
  bool shouldRetry(HttpError error, int attempt) {
    if (attempt >= maxAttempts) return false;

    if (retryableErrorTypes != null) {
      return retryableErrorTypes!.contains(error.type);
    }

    return error.isRetryable;
  }

  @override
  Duration getDelay(int attempt) {
    // Calculate exponential delay with overflow protection
    final powerResult = _safePow(multiplier, attempt - 1);

    // Return maxDelay if power calculation overflowed
    if (powerResult.hasOverflow) {
      return maxDelay;
    }

    final delayMs = initialDelay.inMilliseconds * powerResult.value;

    // Check for overflow after multiplication with initial delay
    if (delayMs.isInfinite || delayMs.isNaN || delayMs < 0) {
      return maxDelay;
    }

    // Cap at maxDelay
    final cappedMs = delayMs.clamp(0, maxDelay.inMilliseconds);

    return Duration(milliseconds: cappedMs.toInt());
  }

  @override
  String toString() {
    return 'ExponentialBackoffPolicy('
        'maxAttempts: $maxAttempts, '
        'initialDelay: $initialDelay, '
        'maxDelay: $maxDelay, '
        'multiplier: $multiplier'
        ')';
  }
}

/// Retry policy with constant delay.
@immutable
class ConstantDelayPolicy extends RetryPolicy {
  /// Creates a constant delay retry policy.
  const ConstantDelayPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.retryableErrorTypes,
  });

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Constant delay between retries.
  final Duration delay;

  /// Error types that should trigger a retry.
  ///
  /// If `null`, uses [HttpErrorType.isRetryable].
  final Set<HttpErrorType>? retryableErrorTypes;

  @override
  bool shouldRetry(HttpError error, int attempt) {
    if (attempt >= maxAttempts) return false;

    if (retryableErrorTypes != null) {
      return retryableErrorTypes!.contains(error.type);
    }

    return error.isRetryable;
  }

  @override
  Duration getDelay(int attempt) => delay;

  @override
  String toString() {
    return 'ConstantDelayPolicy('
        'maxAttempts: $maxAttempts, '
        'delay: $delay'
        ')';
  }
}

/// Retry policy that never retries.
@immutable
class NoRetryPolicy extends RetryPolicy {
  /// Creates a no-retry policy.
  const NoRetryPolicy();

  @override
  bool shouldRetry(HttpError error, int attempt) => false;

  @override
  Duration getDelay(int attempt) => Duration.zero;

  @override
  String toString() => 'NoRetryPolicy()';
}

/// Result of safe power calculation.
///
/// Encapsulates the result of a power calculation with explicit overflow handling.
@immutable
class _PowerResult {
  const _PowerResult.value(double value) : _value = value, hasOverflow = false;
  const _PowerResult.overflow() : _value = 0, hasOverflow = true;

  final double _value;

  /// Whether the calculation resulted in overflow.
  final bool hasOverflow;

  /// The calculated value. Only valid if [hasOverflow] is false.
  double get value => _value;
}

/// Helper for power calculation with explicit overflow handling.
///
/// Returns a [_PowerResult] indicating whether the calculation succeeded
/// or resulted in overflow.
_PowerResult _safePow(double base, int exponent) {
  // Handle edge cases
  if (exponent < 0) return const _PowerResult.value(0);
  if (exponent == 0) return const _PowerResult.value(1);
  if (base <= 0) return const _PowerResult.value(0);
  if (base == 1.0) return const _PowerResult.value(1);

  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
    // Detect overflow: Infinity, NaN, or negative wraparound
    if (result.isInfinite || result.isNaN || result < 0) {
      return const _PowerResult.overflow();
    }
  }
  return _PowerResult.value(result);
}
