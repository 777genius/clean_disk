import 'dart:io';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;
import 'package:dio_http_client/src/mappers/response_mapper.dart';

/// Maps Dio [DioException] to [HttpError].
class DioErrorMapper {
  DioErrorMapper._();

  /// Converts a [DioException] to [HttpError].
  static HttpError toHttpError(
    DioException exception,
    HttpRequest request,
    StackTrace stackTrace,
  ) {
    final errorType = _mapErrorType(exception);
    HttpResponse<dynamic>? response;

    if (exception.response != null) {
      response = DioResponseMapper.toHttpResponse<dynamic>(
        exception.response!,
        request: request,
      );
    }

    return HttpError(
      type: errorType,
      request: request,
      response: response,
      cause: exception,
      stackTrace: stackTrace,
      message: exception.message,
    );
  }

  /// Maps Dio exception type to [HttpErrorType].
  static HttpErrorType _mapErrorType(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
        return HttpErrorType.connectionTimeout;
      case DioExceptionType.sendTimeout:
        return HttpErrorType.sendTimeout;
      case DioExceptionType.receiveTimeout:
        return HttpErrorType.receiveTimeout;
      case DioExceptionType.badCertificate:
        return HttpErrorType.badCertificate;
      case DioExceptionType.badResponse:
        return _mapStatusCodeToErrorType(exception.response?.statusCode);
      case DioExceptionType.cancel:
        return HttpErrorType.cancelled;
      case DioExceptionType.connectionError:
        return HttpErrorType.networkUnreachable;
      case DioExceptionType.unknown:
        return _inferErrorType(exception);
    }
  }

  /// Maps HTTP status code to [HttpErrorType].
  static HttpErrorType _mapStatusCodeToErrorType(int? statusCode) {
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

  /// Infers error type from unknown exception.
  ///
  /// **Detection Strategy:**
  /// 1. Check exception type first (SocketException) for reliable detection
  /// 2. Fall back to message patterns when type doesn't reveal the cause
  ///
  /// **Note on DNS detection:** SocketException provides osError.errorCode
  /// which is more reliable than message matching. Error code 8 typically
  /// indicates DNS resolution failure on most platforms.
  ///
  /// If detection fails, errors fall back to [HttpErrorType.unknown],
  /// which is safe but less informative for error handling.
  static HttpErrorType _inferErrorType(DioException exception) {
    final error = exception.error;
    final message = exception.message?.toLowerCase() ?? '';

    // Check SocketException first - more reliable than message patterns
    if (error is SocketException) {
      // Error code 8 is typically "nodename nor servname provided" (DNS failure)
      // Also check message for 'host' in case error code varies by platform
      if (error.osError?.errorCode == 8 ||
          error.message.toLowerCase().contains('host')) {
        return HttpErrorType.dnsLookupFailed;
      }
      // Other socket errors are network unreachable
      return HttpErrorType.networkUnreachable;
    }

    // Fall back to message patterns for non-SocketException errors
    // Note: These patterns are from Dart's HttpClient and may vary by version
    if (message.contains('failed host lookup') ||
        message.contains('getaddrinfo') ||
        message.contains('dns')) {
      return HttpErrorType.dnsLookupFailed;
    }

    // Try to detect network errors
    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('socket')) {
      return HttpErrorType.networkUnreachable;
    }

    // Check if it's a cancellation
    if (error is CancelException) {
      return HttpErrorType.cancelled;
    }

    return HttpErrorType.unknown;
  }
}
