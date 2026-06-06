import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('InterceptorChain', () {
    late HttpRequest testRequest;
    late HttpResponse<String> testResponse;
    late HttpError testError;

    setUp(() {
      testRequest = const HttpRequest(
        method: HttpMethod.get,
        path: '/test',
      );
      testResponse = HttpResponse<String>(
        statusCode: 200,
        data: 'test data',
        request: testRequest,
      );
      testError = HttpError(
        type: HttpErrorType.serverError,
        request: testRequest,
        message: 'Test error',
      );
    });

    group('constructor', () {
      test('should create empty chain', () {
        const chain = InterceptorChain([]);
        expect(chain.isEmpty, isTrue);
        expect(chain.length, 0);
      });

      test('should create chain with interceptors', () {
        const chain = InterceptorChain([
          _PassThroughInterceptor(),
          _PassThroughInterceptor(),
        ]);
        expect(chain.isNotEmpty, isTrue);
        expect(chain.length, 2);
      });
    });

    group('processRequest', () {
      test('should return request unchanged when chain is empty', () async {
        const chain = InterceptorChain([]);
        final result = await chain.processRequest(testRequest);
        expect(result, testRequest);
      });

      test('should call interceptors in order', () async {
        final callOrder = <int>[];
        final chain = InterceptorChain([
          _OrderTrackingInterceptor(1, callOrder),
          _OrderTrackingInterceptor(2, callOrder),
          _OrderTrackingInterceptor(3, callOrder),
        ]);

        await chain.processRequest(testRequest);

        expect(callOrder, [1, 2, 3]);
      });

      test('should allow interceptor to modify request', () async {
        final chain = InterceptorChain([
          _HeaderAddingInterceptor('X-Test', 'value'),
        ]);

        final result = await chain.processRequest(testRequest);

        expect(result.headers?['X-Test'], 'value');
      });

      test('should pass modified request to next interceptor', () async {
        final receivedHeaders = <String, String>{};
        final chain = InterceptorChain([
          _HeaderAddingInterceptor('X-First', '1'),
          _HeaderCapturingInterceptor(receivedHeaders),
          _HeaderAddingInterceptor('X-Third', '3'),
        ]);

        await chain.processRequest(testRequest);

        expect(receivedHeaders['X-First'], '1');
      });

      test('should allow short-circuit without calling next', () async {
        final callOrder = <int>[];
        final chain = InterceptorChain([
          _OrderTrackingInterceptor(1, callOrder),
          _ShortCircuitInterceptor(),
          _OrderTrackingInterceptor(3, callOrder),
        ]);

        await chain.processRequest(testRequest);

        expect(callOrder, [1]); // Third interceptor not called
      });
    });

    group('processResponse', () {
      test('should return response unchanged when chain is empty', () async {
        const chain = InterceptorChain([]);
        final result = await chain.processResponse(testResponse);
        expect(result, testResponse);
      });

      test('should call interceptors in reverse order', () async {
        final callOrder = <int>[];
        final chain = InterceptorChain([
          _ResponseOrderTrackingInterceptor(1, callOrder),
          _ResponseOrderTrackingInterceptor(2, callOrder),
          _ResponseOrderTrackingInterceptor(3, callOrder),
        ]);

        await chain.processResponse(testResponse);

        expect(callOrder, [3, 2, 1]); // Reverse order
      });

      test('should allow interceptor to modify response', () async {
        final chain = InterceptorChain([
          _ResponseModifyingInterceptor(),
        ]);

        final result = await chain.processResponse(testResponse);

        expect(result.headers['X-Modified'], 'true');
      });
    });

    group('processError', () {
      test('should throw error when chain is empty', () async {
        const chain = InterceptorChain([]);

        expect(
          () => chain.processError(testError),
          throwsA(isA<HttpError>()),
        );
      });

      test('should call interceptors in reverse order', () async {
        final callOrder = <int>[];
        final chain = InterceptorChain([
          _ErrorOrderTrackingInterceptor(1, callOrder),
          _ErrorOrderTrackingInterceptor(2, callOrder),
          _ErrorOrderTrackingInterceptor(3, callOrder),
        ]);

        expect(
          () => chain.processError(testError),
          throwsA(isA<HttpError>()),
        );

        expect(callOrder, [3, 2, 1]); // Reverse order
      });

      test('should allow interceptor to recover from error', () async {
        final chain = InterceptorChain([
          _ErrorRecoveringInterceptor(testResponse),
        ]);

        final result = await chain.processError(testError);

        expect(result, testResponse);
      });

      test('should allow interceptor to transform error', () async {
        final chain = InterceptorChain([
          _ErrorTransformingInterceptor(),
        ]);

        expect(
          () => chain.processError(testError),
          throwsA(
            isA<HttpError>().having(
              (e) => e.message,
              'message',
              'Transformed error',
            ),
          ),
        );
      });
    });

    group('chain modification', () {
      test('add should append interceptor', () {
        const chain = InterceptorChain([]);
        final newChain = chain.add(const _PassThroughInterceptor());

        expect(chain.length, 0);
        expect(newChain.length, 1);
      });

      test('addAll should append multiple interceptors', () {
        const chain = InterceptorChain([]);
        final newChain = chain.addAll([
          const _PassThroughInterceptor(),
          const _PassThroughInterceptor(),
        ]);

        expect(newChain.length, 2);
      });

      test('prepend should add interceptor at beginning', () async {
        final callOrder = <int>[];
        final chain = InterceptorChain([
          _OrderTrackingInterceptor(2, callOrder),
        ]);

        final newChain = chain.prepend(_OrderTrackingInterceptor(1, callOrder));
        await newChain.processRequest(testRequest);

        expect(callOrder, [1, 2]);
      });

      test('removeWhere should filter interceptors', () {
        final chain = InterceptorChain([
          _NamedInterceptor('keep1'),
          _NamedInterceptor('remove'),
          _NamedInterceptor('keep2'),
        ]);

        final newChain = chain.removeWhere(
          (i) => i is _NamedInterceptor && i.name == 'remove',
        );

        expect(newChain.length, 2);
      });
    });

    group('thread safety', () {
      test('concurrent processRequest calls should not interfere', () async {
        final chain = InterceptorChain([
          _DelayInterceptor(const Duration(milliseconds: 10)),
          _HeaderAddingInterceptor('X-Request-Id', ''),
        ]);

        // Start multiple concurrent requests
        final futures = List.generate(5, (i) {
          return chain.processRequest(
            HttpRequest(
              method: HttpMethod.get,
              path: '/test/$i',
            ),
          );
        });

        final results = await Future.wait(futures);

        // Each request should have its own path preserved
        for (var i = 0; i < results.length; i++) {
          expect(results[i].path, '/test/$i');
        }
      });
    });
  });
}

// Test interceptor implementations

class _PassThroughInterceptor extends HttpInterceptor {
  const _PassThroughInterceptor();
}

class _OrderTrackingInterceptor extends HttpInterceptor {
  _OrderTrackingInterceptor(this.id, this.callOrder);

  final int id;
  final List<int> callOrder;

  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    callOrder.add(id);
    return next(request);
  }
}

class _ResponseOrderTrackingInterceptor extends HttpInterceptor {
  _ResponseOrderTrackingInterceptor(this.id, this.callOrder);

  final int id;
  final List<int> callOrder;

  @override
  Future<HttpResponse<dynamic>> onResponse(
    HttpResponse<dynamic> response,
    ResponseHandler next,
  ) async {
    callOrder.add(id);
    return next(response);
  }
}

class _ErrorOrderTrackingInterceptor extends HttpInterceptor {
  _ErrorOrderTrackingInterceptor(this.id, this.callOrder);

  final int id;
  final List<int> callOrder;

  @override
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    ErrorHandler next,
  ) async {
    callOrder.add(id);
    return next(error);
  }
}

class _HeaderAddingInterceptor extends HttpInterceptor {
  _HeaderAddingInterceptor(this.name, this.value);

  final String name;
  final String value;

  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    final newHeaders = Map<String, String>.from(request.headers ?? {});
    newHeaders[name] = value;
    return next(request.copyWith(headers: newHeaders));
  }
}

class _HeaderCapturingInterceptor extends HttpInterceptor {
  _HeaderCapturingInterceptor(this.capturedHeaders);

  final Map<String, String> capturedHeaders;

  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    capturedHeaders.addAll(request.headers ?? {});
    return next(request);
  }
}

class _ShortCircuitInterceptor extends HttpInterceptor {
  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    // Don't call next - short-circuit
    return request;
  }
}

class _ResponseModifyingInterceptor extends HttpInterceptor {
  @override
  Future<HttpResponse<dynamic>> onResponse(
    HttpResponse<dynamic> response,
    ResponseHandler next,
  ) async {
    final newHeaders = Map<String, String>.from(response.headers);
    newHeaders['X-Modified'] = 'true';
    return next(response.copyWith(headers: newHeaders));
  }
}

class _ErrorRecoveringInterceptor extends HttpInterceptor {
  _ErrorRecoveringInterceptor(this.recoveryResponse);

  final HttpResponse<dynamic> recoveryResponse;

  @override
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    ErrorHandler next,
  ) async {
    // Recover from error by returning a response
    return recoveryResponse;
  }
}

class _ErrorTransformingInterceptor extends HttpInterceptor {
  @override
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    ErrorHandler next,
  ) async {
    // Transform the error
    throw HttpError(
      type: error.type,
      request: error.request,
      message: 'Transformed error',
    );
  }
}

class _NamedInterceptor extends HttpInterceptor {
  _NamedInterceptor(this.name);

  final String name;
}

class _DelayInterceptor extends HttpInterceptor {
  _DelayInterceptor(this.delay);

  final Duration delay;

  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    await Future<void>.delayed(delay);
    return next(request);
  }
}
