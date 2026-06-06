import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;

/// Interceptor that handles request retry with configurable policy.
///
/// **Important:** This interceptor does NOT retry 401/403 errors by default,
/// as those should be handled by the token refresh interceptor instead.
/// This prevents infinite loops between retry and token refresh.
class DioRetryInterceptor extends Interceptor {
  /// Creates a new retry interceptor.
  DioRetryInterceptor({
    required this.policy,
    required this.dio,
    this.skipAuthErrors = true,
  });

  /// Retry policy configuration.
  final RetryPolicy policy;

  /// Dio instance for retrying requests.
  final Dio dio;

  /// Whether to skip retry for 401/403 errors.
  ///
  /// Default is `true` to prevent conflicts with token refresh interceptor.
  /// Set to `false` only if you're not using token refresh.
  final bool skipAuthErrors;

  /// Maximum retry attempts as a safety net (independent of policy).
  static const int _maxSafeRetries = 10;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Skip retry for auth errors to prevent conflicts with token refresh
    if (skipAuthErrors && _isAuthError(err)) {
      return handler.next(err);
    }

    final originalError = err; // Preserve original error for diagnostics
    var currentError = err;
    var attempt = _getAttempt(err.requestOptions);

    // Iterative retry loop with safety limit
    while (attempt < _maxSafeRetries) {
      // Check for cancellation at start of each iteration (fresh read)
      final cancelToken = currentError.requestOptions.cancelToken;
      if (cancelToken != null && cancelToken.isCancelled) {
        return handler.reject(_createCancelError(currentError.requestOptions));
      }

      final httpError = _toHttpError(currentError);

      // Check if we should retry (policy handles max attempts internally)
      if (!policy.shouldRetry(httpError, attempt + 1)) {
        return handler.next(currentError);
      }

      // Get delay for this attempt
      final delay = policy.getDelay(attempt + 1);

      // Wait before retry
      await Future<void>.delayed(delay);

      // Re-read cancelToken after delay (it might have changed)
      final freshCancelToken = currentError.requestOptions.cancelToken;
      if (freshCancelToken != null && freshCancelToken.isCancelled) {
        return handler.reject(_createCancelError(currentError.requestOptions));
      }

      // Increment attempt counter
      attempt++;
      // Copy options to avoid mutating shared state between interceptors
      final newOptions = currentError.requestOptions.copyWith(
        extra: {...currentError.requestOptions.extra, '_retryAttempt': attempt},
      );

      try {
        // Retry the request
        final response = await dio.fetch<dynamic>(newOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        // Continue loop with new error
        currentError = e;
      } on Object catch (e) {
        // Non-DioException errors (ArgumentError, StateError, etc.)
        // Wrap in DioException and propagate - don't retry these
        final wrappedError = DioException(
          requestOptions: newOptions,
          error: e,
          message: 'Unexpected error during retry: $e',
        );
        return handler.next(wrappedError);
      }
    }

    // Safety limit reached - propagate original error with retry context
    // This preserves the root cause for better diagnostics
    final retryCount = attempt > 0 ? attempt - 1 : 0;
    final finalError = DioException(
      requestOptions: currentError.requestOptions,
      response: currentError.response,
      type: currentError.type,
      error: currentError.error,
      stackTrace: currentError.stackTrace,
      message:
          'Request failed after $attempt attempts ($retryCount retries). '
          'Original error: ${originalError.message}',
    );
    return handler.next(finalError);
  }

  /// Checks if error is an authentication error (401/403).
  bool _isAuthError(DioException err) {
    final statusCode = err.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  /// Gets the current retry attempt from request options.
  int _getAttempt(RequestOptions options) {
    return (options.extra['_retryAttempt'] as int?) ?? 0;
  }

  /// Creates a cancellation error for the given request options.
  DioException _createCancelError(RequestOptions options) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'Request cancelled during retry',
    );
  }

  /// Converts DioException to HttpError for policy check.
  HttpError _toHttpError(DioException err) {
    final errorType = _mapErrorType(err);
    final dioResponse = err.response;

    final httpRequest = HttpRequest(
      method: HttpMethod.values.firstWhere(
        (m) => m.value.toUpperCase() == err.requestOptions.method,
        orElse: () => HttpMethod.get,
      ),
      path: err.requestOptions.path,
    );

    // Create HttpResponse if we have a Dio response
    HttpResponse<dynamic>? httpResponse;
    if (dioResponse != null) {
      httpResponse = HttpResponse<dynamic>(
        statusCode: dioResponse.statusCode ?? 0,
        request: httpRequest,
        statusMessage: dioResponse.statusMessage,
        headers: dioResponse.headers.map.map(
          (key, value) => MapEntry(key, value.join(', ')),
        ),
        rawBody: dioResponse.data,
      );
    }

    return HttpError(
      type: errorType,
      request: httpRequest,
      response: httpResponse,
      message: err.message,
    );
  }

  /// Maps Dio exception type to HttpErrorType.
  HttpErrorType _mapErrorType(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return HttpErrorType.connectionTimeout;
      case DioExceptionType.sendTimeout:
        return HttpErrorType.sendTimeout;
      case DioExceptionType.receiveTimeout:
        return HttpErrorType.receiveTimeout;
      case DioExceptionType.badCertificate:
        return HttpErrorType.badCertificate;
      case DioExceptionType.badResponse:
        return _mapStatusCode(err.response?.statusCode);
      case DioExceptionType.cancel:
        return HttpErrorType.cancelled;
      case DioExceptionType.connectionError:
        return HttpErrorType.networkUnreachable;
      case DioExceptionType.unknown:
        return HttpErrorType.unknown;
    }
  }

  /// Maps HTTP status code to error type.
  HttpErrorType _mapStatusCode(int? statusCode) {
    if (statusCode == null) return HttpErrorType.badResponse;

    return switch (statusCode) {
      401 => HttpErrorType.unauthorized,
      403 => HttpErrorType.forbidden,
      404 => HttpErrorType.notFound,
      429 => HttpErrorType.rateLimited,
      >= 500 && < 600 => HttpErrorType.serverError,
      _ => HttpErrorType.badResponse,
    };
  }
}
