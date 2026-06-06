import 'dart:async';

import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:meta/meta.dart';

/// Circuit breaker state.
enum CircuitBreakerState {
  /// Normal operation, requests pass through.
  closed,

  /// Too many failures, requests are rejected.
  open,

  /// Testing if service recovered.
  halfOpen,
}

/// Circuit breaker policy for fault tolerance.
///
/// Prevents cascading failures by temporarily rejecting requests
/// to a failing service.
///
/// State transitions:
/// - CLOSED -> OPEN: When failure threshold is reached
/// - OPEN -> HALF_OPEN: After open duration expires
/// - HALF_OPEN -> CLOSED: After success threshold is met
/// - HALF_OPEN -> OPEN: On any failure
///
/// This is an interface - implementations will be provided in
/// separate packages or custom code.
abstract class CircuitBreakerPolicy {
  /// Creates a circuit breaker policy.
  const CircuitBreakerPolicy();

  /// Current state of the circuit breaker.
  CircuitBreakerState get state;

  /// Whether requests should be allowed through.
  bool get isAllowed => state != CircuitBreakerState.open;

  /// Record a successful request.
  void recordSuccess();

  /// Record a failed request.
  void recordFailure(HttpError error);

  /// Reset the circuit breaker to closed state.
  void reset();

  /// Stream of state changes.
  Stream<CircuitBreakerState> get stateChanges;
}

/// Configuration for circuit breaker.
@immutable
class CircuitBreakerConfig {
  /// Creates a circuit breaker configuration.
  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.successThreshold = 2,
    this.openDuration = const Duration(seconds: 30),
    this.halfOpenMaxRequests = 1,
    this.failureCountingWindow = const Duration(minutes: 1),
    this.errorFilter,
  });

  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// Number of successes in half-open state to close the circuit.
  final int successThreshold;

  /// How long to keep the circuit open before testing.
  final Duration openDuration;

  /// Max concurrent requests in half-open state.
  final int halfOpenMaxRequests;

  /// Time window for counting failures.
  ///
  /// Failures outside this window are not counted.
  final Duration failureCountingWindow;

  /// Optional filter to determine which errors count as failures.
  ///
  /// If null, all errors count as failures.
  final bool Function(HttpError error)? errorFilter;

  /// Creates a copy with the given fields replaced.
  CircuitBreakerConfig copyWith({
    int? failureThreshold,
    int? successThreshold,
    Duration? openDuration,
    int? halfOpenMaxRequests,
    Duration? failureCountingWindow,
    bool Function(HttpError error)? errorFilter,
  }) {
    return CircuitBreakerConfig(
      failureThreshold: failureThreshold ?? this.failureThreshold,
      successThreshold: successThreshold ?? this.successThreshold,
      openDuration: openDuration ?? this.openDuration,
      halfOpenMaxRequests: halfOpenMaxRequests ?? this.halfOpenMaxRequests,
      failureCountingWindow:
          failureCountingWindow ?? this.failureCountingWindow,
      errorFilter: errorFilter ?? this.errorFilter,
    );
  }

  @override
  String toString() {
    return 'CircuitBreakerConfig('
        'failureThreshold: $failureThreshold, '
        'successThreshold: $successThreshold, '
        'openDuration: $openDuration, '
        'halfOpenMaxRequests: $halfOpenMaxRequests'
        ')';
  }
}

/// Exception thrown when circuit breaker is open.
class CircuitBreakerOpenException implements Exception {
  /// Creates a circuit breaker open exception.
  const CircuitBreakerOpenException([this.message]);

  /// Error message.
  final String? message;

  @override
  String toString() =>
      'CircuitBreakerOpenException: ${message ?? 'Circuit breaker is open'}';
}
