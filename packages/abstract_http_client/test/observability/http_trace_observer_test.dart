import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(method: HttpMethod.get, path: '/test');

  group('NoopTraceObserver', () {
    test('should be instantiable', () {
      const observer = NoopTraceObserver();

      expect(observer, isA<HttpTraceObserver>());
    });

    test('onStart should not throw', () {
      const observer = NoopTraceObserver();
      final trace = HttpTrace.start(testRequest);

      expect(() => observer.onStart(trace), returnsNormally);
    });

    test('onFinish should not throw', () {
      const observer = NoopTraceObserver();
      final trace = HttpTrace.start(testRequest);
      const response =
          HttpResponse<void>(statusCode: 200, request: testRequest);

      expect(() => observer.onFinish(trace, response), returnsNormally);
    });

    test('onError should not throw', () {
      const observer = NoopTraceObserver();
      final trace = HttpTrace.start(testRequest);
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      expect(() => observer.onError(trace, error), returnsNormally);
    });
  });

  group('CompositeTraceObserver', () {
    test('should call onStart on all observers', () {
      final calls = <String>[];
      final observer1 = _RecordingObserver('obs1', calls);
      final observer2 = _RecordingObserver('obs2', calls);
      final composite = CompositeTraceObserver([observer1, observer2]);
      final trace = HttpTrace.start(testRequest);

      composite.onStart(trace);

      expect(calls, ['obs1:onStart', 'obs2:onStart']);
    });

    test('should call onFinish on all observers', () {
      final calls = <String>[];
      final observer1 = _RecordingObserver('obs1', calls);
      final observer2 = _RecordingObserver('obs2', calls);
      final composite = CompositeTraceObserver([observer1, observer2]);
      final trace = HttpTrace.start(testRequest);
      const response =
          HttpResponse<void>(statusCode: 200, request: testRequest);

      composite.onFinish(trace, response);

      expect(calls, ['obs1:onFinish', 'obs2:onFinish']);
    });

    test('should call onError on all observers', () {
      final calls = <String>[];
      final observer1 = _RecordingObserver('obs1', calls);
      final observer2 = _RecordingObserver('obs2', calls);
      final composite = CompositeTraceObserver([observer1, observer2]);
      final trace = HttpTrace.start(testRequest);
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      composite.onError(trace, error);

      expect(calls, ['obs1:onError', 'obs2:onError']);
    });

    group('error handling', () {
      test('should continue calling observers when one throws in onStart', () {
        final calls = <String>[];
        final observer1 = _ThrowingObserver('obs1');
        final observer2 = _RecordingObserver('obs2', calls);
        final composite = CompositeTraceObserver([observer1, observer2]);
        final trace = HttpTrace.start(testRequest);

        composite.onStart(trace);

        expect(calls, ['obs2:onStart']);
      });

      test('should continue calling observers when one throws in onFinish',
          () {
        final calls = <String>[];
        final observer1 = _ThrowingObserver('obs1');
        final observer2 = _RecordingObserver('obs2', calls);
        final composite = CompositeTraceObserver([observer1, observer2]);
        final trace = HttpTrace.start(testRequest);
        const response =
            HttpResponse<void>(statusCode: 200, request: testRequest);

        composite.onFinish(trace, response);

        expect(calls, ['obs2:onFinish']);
      });

      test('should continue calling observers when one throws in onError', () {
        final calls = <String>[];
        final observer1 = _ThrowingObserver('obs1');
        final observer2 = _RecordingObserver('obs2', calls);
        final composite = CompositeTraceObserver([observer1, observer2]);
        final trace = HttpTrace.start(testRequest);
        const error = HttpError(
          type: HttpErrorType.connectionTimeout,
          request: testRequest,
        );

        composite.onError(trace, error);

        expect(calls, ['obs2:onError']);
      });

      test('should call onObserverError when observer throws', () {
        final errors = <_ErrorRecord>[];
        final observer = _ThrowingObserver('throwing');
        final composite = CompositeTraceObserver(
          [observer],
          onObserverError: (obs, error, stackTrace, methodName) {
            errors.add(_ErrorRecord(
              observer: obs,
              error: error,
              methodName: methodName,
            ));
          },
        );
        final trace = HttpTrace.start(testRequest);

        composite.onStart(trace);

        expect(errors.length, 1);
        expect(errors.first.observer, observer);
        expect(errors.first.error, isA<Exception>());
        expect(errors.first.methodName, 'onStart');
      });

      test('should call onObserverError for onFinish errors', () {
        final errors = <_ErrorRecord>[];
        final observer = _ThrowingObserver('throwing');
        final composite = CompositeTraceObserver(
          [observer],
          onObserverError: (obs, error, stackTrace, methodName) {
            errors.add(_ErrorRecord(
              observer: obs,
              error: error,
              methodName: methodName,
            ));
          },
        );
        final trace = HttpTrace.start(testRequest);
        const response =
            HttpResponse<void>(statusCode: 200, request: testRequest);

        composite.onFinish(trace, response);

        expect(errors.length, 1);
        expect(errors.first.methodName, 'onFinish');
      });

      test('should call onObserverError for onError errors', () {
        final errors = <_ErrorRecord>[];
        final observer = _ThrowingObserver('throwing');
        final composite = CompositeTraceObserver(
          [observer],
          onObserverError: (obs, error, stackTrace, methodName) {
            errors.add(_ErrorRecord(
              observer: obs,
              error: error,
              methodName: methodName,
            ));
          },
        );
        final trace = HttpTrace.start(testRequest);
        const httpError = HttpError(
          type: HttpErrorType.connectionTimeout,
          request: testRequest,
        );

        composite.onError(trace, httpError);

        expect(errors.length, 1);
        expect(errors.first.methodName, 'onError');
      });

      test('should not break if onObserverError throws', () {
        final observer = _ThrowingObserver('throwing');
        final composite = CompositeTraceObserver(
          [observer],
          onObserverError: (obs, error, stackTrace, methodName) {
            throw Exception('Error callback threw!');
          },
        );
        final trace = HttpTrace.start(testRequest);

        expect(() => composite.onStart(trace), returnsNormally);
      });
    });

    test('should handle empty observers list', () {
      final composite = CompositeTraceObserver([]);
      final trace = HttpTrace.start(testRequest);
      const response =
          HttpResponse<void>(statusCode: 200, request: testRequest);
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      expect(() => composite.onStart(trace), returnsNormally);
      expect(() => composite.onFinish(trace, response), returnsNormally);
      expect(() => composite.onError(trace, error), returnsNormally);
    });
  });

  group('PrintingTraceObserver', () {
    test('should be instantiable with default prefix', () {
      const observer = PrintingTraceObserver();

      expect(observer.prefix, '[HTTP]');
    });

    test('should be instantiable with custom prefix', () {
      const observer = PrintingTraceObserver(prefix: '[API]');

      expect(observer.prefix, '[API]');
    });

    test('onStart should not throw', () {
      const observer = PrintingTraceObserver();
      final trace = HttpTrace.start(testRequest);

      expect(() => observer.onStart(trace), returnsNormally);
    });

    test('onFinish should not throw', () {
      const observer = PrintingTraceObserver();
      final trace = HttpTrace.start(testRequest);
      const response =
          HttpResponse<void>(statusCode: 200, request: testRequest);
      trace.finish(response);

      expect(() => observer.onFinish(trace, response), returnsNormally);
    });

    test('onError should not throw', () {
      const observer = PrintingTraceObserver();
      final trace = HttpTrace.start(testRequest);
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
        message: 'Connection timed out',
      );

      expect(() => observer.onError(trace, error), returnsNormally);
    });

    test('onError should handle null message', () {
      const observer = PrintingTraceObserver();
      final trace = HttpTrace.start(testRequest);
      const error = HttpError(
        type: HttpErrorType.connectionTimeout,
        request: testRequest,
      );

      expect(() => observer.onError(trace, error), returnsNormally);
    });
  });

  group('HttpTraceObserver interface', () {
    test('should be implementable', () {
      final observer = _TestObserver();

      expect(observer, isA<HttpTraceObserver>());
    });
  });
}

class _RecordingObserver implements HttpTraceObserver {
  _RecordingObserver(this.name, this.calls);

  final String name;
  final List<String> calls;

  @override
  void onStart(HttpTrace trace) {
    calls.add('$name:onStart');
  }

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {
    calls.add('$name:onFinish');
  }

  @override
  void onError(HttpTrace trace, HttpError error) {
    calls.add('$name:onError');
  }
}

class _ThrowingObserver implements HttpTraceObserver {
  _ThrowingObserver(this.name);

  final String name;

  @override
  void onStart(HttpTrace trace) {
    throw Exception('$name threw in onStart');
  }

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {
    throw Exception('$name threw in onFinish');
  }

  @override
  void onError(HttpTrace trace, HttpError error) {
    throw Exception('$name threw in onError');
  }
}

class _TestObserver implements HttpTraceObserver {
  @override
  void onStart(HttpTrace trace) {}

  @override
  void onFinish(HttpTrace trace, HttpResponse<dynamic> response) {}

  @override
  void onError(HttpTrace trace, HttpError error) {}
}

class _ErrorRecord {
  _ErrorRecord({
    required this.observer,
    required this.error,
    required this.methodName,
  });

  final HttpTraceObserver observer;
  final Object error;
  final String methodName;
}
