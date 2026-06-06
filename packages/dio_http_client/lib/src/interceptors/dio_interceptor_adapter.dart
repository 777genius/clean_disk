import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart' hide CancelToken;
import 'package:dio_http_client/src/mappers/error_mapper.dart';
import 'package:dio_http_client/src/mappers/request_mapper.dart';
import 'package:dio_http_client/src/mappers/response_mapper.dart';

/// Adapts an [HttpInterceptor] to work with Dio's interceptor system.
///
/// This allows using the abstract HTTP interceptors with the Dio client.
///
/// **Implementation Note:** Uses async wrapper methods to ensure proper
/// error handling. All exceptions are caught and converted to DioExceptions
/// to prevent unhandled promise rejections.
///
/// Example:
/// ```dart
/// final client = DioHttpClient(
///   config: DioHttpClientConfig(...),
///   interceptors: [MyCustomInterceptor()],
/// );
/// ```
class DioInterceptorAdapter extends Interceptor {
  /// Creates a Dio interceptor adapter.
  DioInterceptorAdapter({required this.interceptor});

  /// The wrapped [HttpInterceptor].
  final HttpInterceptor interceptor;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Use unawaited with catchError to ensure synchronous exceptions
    // are caught and converted to DioExceptions
    unawaited(
      _handleRequest(options, handler).catchError((Object e, StackTrace st) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            stackTrace: st,
          ),
        );
      }),
    );
  }

  /// Handles request interception with proper async error handling.
  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final httpRequest = _toHttpRequest(options);
      final modifiedRequest = await interceptor.onRequest(
        httpRequest,
        (request) async => request,
      );
      final modifiedOptions = _applyRequestChanges(options, modifiedRequest);
      handler.next(modifiedOptions);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Use unawaited with catchError to ensure synchronous exceptions
    // are caught and converted to DioExceptions
    unawaited(
      _handleResponse(response, handler).catchError((Object e, StackTrace st) {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            error: e,
            stackTrace: st,
          ),
        );
      }),
    );
  }

  /// Handles response interception with proper async error handling.
  Future<void> _handleResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      final httpRequest = _toHttpRequest(response.requestOptions);
      final httpResponse = DioResponseMapper.toHttpResponse<dynamic>(
        response,
        request: httpRequest,
      );
      final modifiedResponse = await interceptor.onResponse(
        httpResponse,
        (resp) async => resp,
      );
      final modifiedDioResponse = _applyResponseChanges(
        response,
        modifiedResponse,
      );
      handler.next(modifiedDioResponse);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Use unawaited with catchError to ensure synchronous exceptions
    // are caught and converted to DioExceptions
    unawaited(
      _handleError(err, handler).catchError((Object e, StackTrace st) {
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: e,
            stackTrace: st,
          ),
        );
      }),
    );
  }

  /// Handles error interception with proper async error handling.
  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final httpRequest = _toHttpRequest(err.requestOptions);
      final httpError = DioErrorMapper.toHttpError(
        err,
        httpRequest,
        err.stackTrace,
      );

      final recoveredResponse = await interceptor.onError(
        httpError,
        (error) async {
          // Default error handling: rethrow as DioException
          throw DioException(
            requestOptions: err.requestOptions,
            error: error,
            type: _mapHttpErrorToDioType(error.type),
            response: err.response,
            message: error.message,
          );
        },
      );

      // Interceptor recovered from error by returning a response
      // Prefer rawBody to preserve original data for response decoder pipeline
      final dioResponse = Response<dynamic>(
        requestOptions: err.requestOptions,
        data: recoveredResponse.rawBody ?? recoveredResponse.data,
        statusCode: recoveredResponse.statusCode,
        statusMessage: recoveredResponse.statusMessage,
        headers: Headers.fromMap(
          recoveredResponse.headers.map(
            (key, value) => MapEntry(key, [value]),
          ),
        ),
        extra: recoveredResponse.extra,
      );
      handler.resolve(dioResponse);
    } on DioException catch (e) {
      handler.reject(e);
    } on HttpError catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: error.cause ?? error,
          type: _mapHttpErrorToDioType(error.type),
          message: error.message,
          stackTrace: stackTrace,
        ),
      );
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Converts Dio [RequestOptions] to [HttpRequest].
  static HttpRequest _toHttpRequest(RequestOptions options) {
    final uri = options.uri;

    return HttpRequest(
      method: HttpMethod.tryParse(options.method) ?? HttpMethod.get,
      path: uri.path,
      baseUrl: uri.hasScheme
          ? Uri(
              scheme: uri.scheme,
              host: uri.host,
              port: uri.hasPort ? uri.port : null,
            )
          : null,
      queryParameters: uri.queryParameters.isNotEmpty
          ? Map<String, dynamic>.from(uri.queryParameters)
          : null,
      headers: options.headers.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      timeout: options.sendTimeout ?? options.receiveTimeout,
      extra: options.extra.isNotEmpty ? options.extra : null,
    );
  }

  /// Applies changes from [HttpRequest] back to [RequestOptions].
  static RequestOptions _applyRequestChanges(
    RequestOptions original,
    HttpRequest modified,
  ) {
    final newOptions = DioRequestMapper.toOptions(modified);

    // Parse baseUrl safely - use null if empty or invalid
    Uri? baseUrl;
    if (original.baseUrl.isNotEmpty) {
      baseUrl = Uri.tryParse(original.baseUrl);
    }

    return original.copyWith(
      method: newOptions.method,
      headers: newOptions.headers,
      sendTimeout: newOptions.sendTimeout,
      receiveTimeout: newOptions.receiveTimeout,
      extra: newOptions.extra,
      path: modified.resolveUri(defaultBaseUrl: baseUrl).toString(),
    );
  }

  /// Applies changes from [HttpResponse] back to Dio [Response].
  static Response<dynamic> _applyResponseChanges(
    Response<dynamic> original,
    HttpResponse<dynamic> modified,
  ) {
    return Response<dynamic>(
      requestOptions: original.requestOptions,
      data: modified.rawBody ?? modified.data,
      statusCode: modified.statusCode,
      statusMessage: modified.statusMessage,
      headers: Headers.fromMap(
        modified.headers.map((key, value) => MapEntry(key, [value])),
      ),
      extra: modified.extra,
    );
  }

  /// Maps [HttpErrorType] to [DioExceptionType].
  static DioExceptionType _mapHttpErrorToDioType(HttpErrorType type) {
    return switch (type) {
      HttpErrorType.connectionTimeout => DioExceptionType.connectionTimeout,
      HttpErrorType.sendTimeout => DioExceptionType.sendTimeout,
      HttpErrorType.receiveTimeout => DioExceptionType.receiveTimeout,
      HttpErrorType.cancelled => DioExceptionType.cancel,
      HttpErrorType.badCertificate => DioExceptionType.badCertificate,
      HttpErrorType.networkUnreachable ||
      HttpErrorType.dnsLookupFailed => DioExceptionType.connectionError,
      _ => DioExceptionType.unknown,
    };
  }
}
