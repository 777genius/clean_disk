import 'dart:async';

import 'package:abstract_http_client/src/interceptors/http_interceptor.dart';
import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:abstract_http_client/src/models/http_response.dart';
import 'package:abstract_http_client/src/utils/cancel_token.dart';

/// Executes a chain of interceptors.
///
/// The chain follows the Chain of Responsibility pattern.
/// For requests: interceptors are called in order (first to last).
/// For responses: interceptors are called in reverse order (last to first).
/// For errors: interceptors are called in reverse order (last to first).
class InterceptorChain {
  /// Creates an interceptor chain.
  const InterceptorChain(this.interceptors);

  /// The interceptors in this chain.
  final List<HttpInterceptor> interceptors;

  /// Process a request through the chain.
  ///
  /// Interceptors are called in order. Each interceptor can modify
  /// the request before passing to the next.
  ///
  /// [cancelToken] - Optional token to cancel the chain processing.
  /// [timeout] - Optional timeout for the entire chain processing.
  ///
  /// Thread-safe: uses immutable index parameter instead of mutable closure
  /// state to prevent race conditions with concurrent calls.
  ///
  /// Throws [CancelException] if cancelled.
  /// Throws [TimeoutException] if timeout exceeded.
  Future<HttpRequest> processRequest(
    HttpRequest request, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    if (interceptors.isEmpty) return request;

    Future<HttpRequest> processAtIndex(HttpRequest req, int index) async {
      // Check cancellation before each interceptor
      cancelToken?.throwIfCancelled();

      if (index >= interceptors.length) {
        return req;
      }
      final interceptor = interceptors[index];
      return interceptor.onRequest(
        req,
        (nextReq) => processAtIndex(nextReq, index + 1),
      );
    }

    final future = processAtIndex(request, 0);

    if (timeout != null) {
      return future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Interceptor chain timed out after $timeout',
          timeout,
        ),
      );
    }

    return future;
  }

  /// Process a response through the chain.
  ///
  /// Interceptors are called in reverse order. Each interceptor can
  /// modify the response before passing to the next.
  ///
  /// [cancelToken] - Optional token to cancel the chain processing.
  /// [timeout] - Optional timeout for the entire chain processing.
  ///
  /// Thread-safe: uses immutable index parameter instead of mutable closure
  /// state to prevent race conditions with concurrent calls.
  ///
  /// Throws [CancelException] if cancelled.
  /// Throws [TimeoutException] if timeout exceeded.
  Future<HttpResponse<dynamic>> processResponse(
    HttpResponse<dynamic> response, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    if (interceptors.isEmpty) return response;

    Future<HttpResponse<dynamic>> processAtIndex(
      HttpResponse<dynamic> res,
      int index,
    ) async {
      // Check cancellation before each interceptor
      cancelToken?.throwIfCancelled();

      if (index < 0) {
        return res;
      }
      final interceptor = interceptors[index];
      return interceptor.onResponse(
        res,
        (nextRes) => processAtIndex(nextRes, index - 1),
      );
    }

    final future = processAtIndex(response, interceptors.length - 1);

    if (timeout != null) {
      return future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Interceptor chain timed out after $timeout',
          timeout,
        ),
      );
    }

    return future;
  }

  /// Process an error through the chain.
  ///
  /// Interceptors are called in reverse order. Each interceptor can
  /// recover by returning a response, or let the error propagate.
  ///
  /// [cancelToken] - Optional token to cancel the chain processing.
  /// [timeout] - Optional timeout for the entire chain processing.
  ///
  /// Throws [HttpError] if no interceptor recovers from the error.
  /// Throws [CancelException] if cancelled.
  /// Throws [TimeoutException] if timeout exceeded.
  ///
  /// Thread-safe: uses immutable index parameter instead of mutable closure
  /// state to prevent race conditions with concurrent calls.
  Future<HttpResponse<dynamic>> processError(
    HttpError error, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    if (interceptors.isEmpty) throw error;

    Future<HttpResponse<dynamic>> processAtIndex(
      HttpError err,
      int index,
    ) async {
      // Check cancellation before each interceptor
      cancelToken?.throwIfCancelled();

      if (index < 0) {
        throw err;
      }
      final interceptor = interceptors[index];
      return interceptor.onError(
        err,
        (nextErr) => processAtIndex(nextErr, index - 1),
      );
    }

    final future = processAtIndex(error, interceptors.length - 1);

    if (timeout != null) {
      return future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Interceptor chain timed out after $timeout',
          timeout,
        ),
      );
    }

    return future;
  }

  /// Creates a new chain with an additional interceptor appended.
  InterceptorChain add(HttpInterceptor interceptor) {
    return InterceptorChain([...interceptors, interceptor]);
  }

  /// Creates a new chain with additional interceptors appended.
  InterceptorChain addAll(Iterable<HttpInterceptor> newInterceptors) {
    return InterceptorChain([...interceptors, ...newInterceptors]);
  }

  /// Creates a new chain with an interceptor prepended.
  InterceptorChain prepend(HttpInterceptor interceptor) {
    return InterceptorChain([interceptor, ...interceptors]);
  }

  /// Creates a new chain without interceptors matching the predicate.
  InterceptorChain removeWhere(bool Function(HttpInterceptor) test) {
    return InterceptorChain(
      interceptors.where((i) => !test(i)).toList(),
    );
  }

  /// Whether this chain is empty.
  bool get isEmpty => interceptors.isEmpty;

  /// Whether this chain has interceptors.
  bool get isNotEmpty => interceptors.isNotEmpty;

  /// Number of interceptors in this chain.
  int get length => interceptors.length;
}
