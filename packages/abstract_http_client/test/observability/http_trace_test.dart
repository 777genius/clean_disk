import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(method: HttpMethod.get, path: '/test');

  group('HttpTrace', () {
    group('start', () {
      test('should create trace with generated IDs', () {
        final trace = HttpTrace.start(testRequest);

        expect(trace.id, isNotEmpty);
        expect(trace.id.length, 16); // 64-bit span ID
        expect(trace.traceId, isNotEmpty);
        expect(trace.traceId!.length, 32); // 128-bit trace ID
        expect(trace.request, testRequest);
        expect(trace.startTime, isNotNull);
        expect(trace.parentSpanId, isNull);
      });

      test('should use provided traceId', () {
        const traceId = 'abc123def456789012345678901234ab';
        final trace = HttpTrace.start(testRequest, traceId: traceId);

        expect(trace.traceId, traceId);
      });

      test('should use provided parentSpanId', () {
        const parentSpanId = 'parent12345678';
        final trace = HttpTrace.start(testRequest, parentSpanId: parentSpanId);

        expect(trace.parentSpanId, parentSpanId);
      });
    });

    group('initial state', () {
      test('should not be completed initially', () {
        final trace = HttpTrace.start(testRequest);

        expect(trace.isCompleted, isFalse);
        expect(trace.endTime, isNull);
        expect(trace.duration, isNull);
        expect(trace.response, isNull);
        expect(trace.error, isNull);
        expect(trace.isSuccess, isFalse);
        expect(trace.statusCode, isNull);
      });

      test('should have empty attributes and events', () {
        final trace = HttpTrace.start(testRequest);

        expect(trace.attributes, isEmpty);
        expect(trace.events, isEmpty);
      });
    });

    group('finish', () {
      test('should mark trace as completed', () {
        final trace = HttpTrace.start(testRequest);

        final result = trace.finish();

        expect(result, isTrue);
        expect(trace.isCompleted, isTrue);
        expect(trace.endTime, isNotNull);
        expect(trace.duration, isNotNull);
        // isSuccess requires response to be set
        expect(trace.isSuccess, isFalse);
      });

      test('should mark trace as successful with response', () {
        final trace = HttpTrace.start(testRequest);
        const response =
            HttpResponse<void>(statusCode: 200, request: testRequest);

        final result = trace.finish(response);

        expect(result, isTrue);
        expect(trace.isSuccess, isTrue);
      });

      test('should store response', () {
        final trace = HttpTrace.start(testRequest);
        const response =
            HttpResponse<void>(statusCode: 200, request: testRequest);

        trace.finish(response);

        expect(trace.response, response);
        expect(trace.statusCode, 200);
      });

      test('should return false if already completed', () {
        final trace = HttpTrace.start(testRequest);
        trace.finish();

        final result = trace.finish();

        expect(result, isFalse);
      });

      test('should clear error when finishing successfully', () {
        final trace = HttpTrace.start(testRequest);
        const response =
            HttpResponse<void>(statusCode: 200, request: testRequest);

        // Complete with finish and response
        trace.finish(response);

        // Error should be null
        expect(trace.error, isNull);
        expect(trace.isSuccess, isTrue);
      });
    });

    group('fail', () {
      test('should mark trace as failed', () {
        final trace = HttpTrace.start(testRequest);
        const error = HttpError(
          type: HttpErrorType.connectionTimeout,
          request: testRequest,
        );

        final result = trace.fail(error);

        expect(result, isTrue);
        expect(trace.isCompleted, isTrue);
        expect(trace.endTime, isNotNull);
        expect(trace.error, error);
        expect(trace.isSuccess, isFalse);
      });

      test('should return false if already completed', () {
        final trace = HttpTrace.start(testRequest);
        trace.finish();

        const error = HttpError(
          type: HttpErrorType.connectionTimeout,
          request: testRequest,
        );
        final result = trace.fail(error);

        expect(result, isFalse);
        expect(trace.error, isNull);
      });

      test('should clear response when failing', () {
        final trace = HttpTrace.start(testRequest);
        const error = HttpError(
          type: HttpErrorType.connectionTimeout,
          request: testRequest,
        );

        trace.fail(error);

        expect(trace.response, isNull);
        expect(trace.isSuccess, isFalse);
      });
    });

    group('attributes', () {
      test('setAttribute should add attribute', () {
        final trace = HttpTrace.start(testRequest);

        trace.setAttribute('user_id', '123');

        expect(trace.attributes['user_id'], '123');
      });

      test('setAttributes should add multiple attributes', () {
        final trace = HttpTrace.start(testRequest);

        trace.setAttributes({
          'user_id': '123',
          'session_id': 'abc',
        });

        expect(trace.attributes['user_id'], '123');
        expect(trace.attributes['session_id'], 'abc');
      });

      test('attributes should be unmodifiable', () {
        final trace = HttpTrace.start(testRequest);
        trace.setAttribute('key', 'value');

        expect(
          () => trace.attributes['new_key'] = 'new_value',
          throwsUnsupportedError,
        );
      });
    });

    group('events', () {
      test('addEvent should record event', () {
        final trace = HttpTrace.start(testRequest);

        trace.addEvent('request_started');

        expect(trace.events.length, 1);
        expect(trace.events.first.name, 'request_started');
        expect(trace.events.first.timestamp, isNotNull);
      });

      test('addEvent should support attributes', () {
        final trace = HttpTrace.start(testRequest);

        trace.addEvent(
          'retry_attempt',
          attributes: {'attempt': 1, 'delay_ms': 100},
        );

        expect(trace.events.first.attributes['attempt'], 1);
        expect(trace.events.first.attributes['delay_ms'], 100);
      });

      test('events should be unmodifiable', () {
        final trace = HttpTrace.start(testRequest);
        trace.addEvent('test');

        expect(
          () => trace.events.add(
            TraceEvent(name: 'hack', timestamp: DateTime.now()),
          ),
          throwsUnsupportedError,
        );
      });
    });

    group('duration', () {
      test('should be null before completion', () {
        final trace = HttpTrace.start(testRequest);

        expect(trace.duration, isNull);
      });

      test('should be calculated after completion', () async {
        final trace = HttpTrace.start(testRequest);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        trace.finish();

        expect(trace.duration, isNotNull);
        expect(trace.duration!.inMilliseconds, greaterThanOrEqualTo(10));
      });
    });

    test('toString should include relevant info', () {
      final trace = HttpTrace.start(testRequest);
      const response =
          HttpResponse<void>(statusCode: 200, request: testRequest);
      trace.finish(response);

      final str = trace.toString();

      expect(str, contains('HttpTrace'));
      expect(str, contains('path: /test'));
      expect(str, contains('statusCode: 200'));
    });
  });

  group('TraceEvent', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();

      final event = TraceEvent(
        name: 'test_event',
        timestamp: timestamp,
      );

      expect(event.name, 'test_event');
      expect(event.timestamp, timestamp);
      expect(event.attributes, isEmpty);
    });

    test('should create with attributes', () {
      final event = TraceEvent(
        name: 'test',
        timestamp: DateTime.now(),
        attributes: {'key': 'value'},
      );

      expect(event.attributes['key'], 'value');
    });

    test('toString should include name and timestamp', () {
      final event = TraceEvent(
        name: 'test_event',
        timestamp: DateTime(2024, 1, 1),
      );

      final str = event.toString();

      expect(str, contains('TraceEvent'));
      expect(str, contains('test_event'));
    });
  });
}
