import 'dart:async';

import 'package:abstract_http_client/src/models/http_error.dart';
import 'package:abstract_http_client/src/models/http_request.dart';
import 'package:abstract_http_client/src/models/http_response.dart';

/// Handler for continuing the request chain.
typedef RequestHandler = Future<HttpRequest> Function(HttpRequest request);

/// Handler for continuing the response chain.
typedef ResponseHandler =
    Future<HttpResponse<dynamic>> Function(
      HttpResponse<dynamic> response,
    );

/// Handler for continuing the error chain.
typedef ErrorHandler = Future<HttpResponse<dynamic>> Function(HttpError error);

/// HTTP interceptor for request/response/error processing.
///
/// Interceptors form a chain. Each interceptor can:
/// - Modify request before sending
/// - Modify response before returning
/// - Handle or transform errors
/// - Short-circuit the chain by not calling next
///
/// Example custom interceptor:
/// ```dart
/// class LoggingInterceptor extends HttpInterceptor {
///   @override
///   Future<HttpRequest> onRequest(
///     HttpRequest request,
///     RequestHandler next,
///   ) async {
///     print('Request: ${request.method} ${request.path}');
///     return next(request);
///   }
///
///   @override
///   Future<HttpResponse<dynamic>> onResponse(
///     HttpResponse<dynamic> response,
///     ResponseHandler next,
///   ) async {
///     print('Response: ${response.statusCode}');
///     return next(response);
///   }
///
///   @override
///   Future<HttpResponse<dynamic>> onError(
///     HttpError error,
///     ErrorHandler next,
///   ) async {
///     print('Error: ${error.type}');
///     return next(error);
///   }
/// }
/// ```
abstract class HttpInterceptor {
  /// Creates an HTTP interceptor.
  const HttpInterceptor();

  /// Process outgoing request.
  ///
  /// Call [next] to continue the chain, or return early to short-circuit.
  /// Returning a modified request will pass that to the next interceptor.
  ///
  /// Default implementation simply forwards to the next handler.
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) {
    return next(request);
  }

  /// Process incoming response.
  ///
  /// Call [next] to continue the chain, or return early to short-circuit.
  /// Returning a modified response will pass that to the next interceptor.
  ///
  /// Default implementation simply forwards to the next handler.
  Future<HttpResponse<dynamic>> onResponse(
    HttpResponse<dynamic> response,
    ResponseHandler next,
  ) {
    return next(response);
  }

  /// Process error.
  ///
  /// Can recover from error by returning a response, or rethrow/transform
  /// the error. Call [next] to let the error propagate.
  ///
  /// Default implementation simply forwards to the next handler.
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    ErrorHandler next,
  ) {
    return next(error);
  }
}

/// An interceptor that can be enabled or disabled at runtime.
class ConditionalInterceptor extends HttpInterceptor {
  /// Creates a conditional interceptor.
  const ConditionalInterceptor({
    required this.interceptor,
    required this.isEnabled,
  });

  /// The wrapped interceptor.
  final HttpInterceptor interceptor;

  /// Function to determine if the interceptor is enabled.
  final bool Function() isEnabled;

  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) {
    if (isEnabled()) {
      return interceptor.onRequest(request, next);
    }
    return next(request);
  }

  @override
  Future<HttpResponse<dynamic>> onResponse(
    HttpResponse<dynamic> response,
    ResponseHandler next,
  ) {
    if (isEnabled()) {
      return interceptor.onResponse(response, next);
    }
    return next(response);
  }

  @override
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    ErrorHandler next,
  ) {
    if (isEnabled()) {
      return interceptor.onError(error, next);
    }
    return next(error);
  }
}
