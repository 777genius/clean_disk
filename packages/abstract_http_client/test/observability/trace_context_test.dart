import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('TraceContext', () {
    group('constructor', () {
      test('should create with required fields', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
        );

        expect(context.traceId, '0af7651916cd43dd8448eb211c80319c');
        expect(context.spanId, 'b7ad6b7169203331');
        expect(context.traceFlags, 0);
        expect(context.traceState, isNull);
        expect(context.isSampled, isFalse);
      });

      test('should create with all fields', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
          traceState: 'vendor=value',
        );

        expect(context.traceFlags, 0x01);
        expect(context.traceState, 'vendor=value');
        expect(context.isSampled, isTrue);
      });
    });

    group('root', () {
      test('should generate valid trace and span IDs', () {
        final context = TraceContext.root();

        expect(context.traceId.length, 32);
        expect(context.spanId.length, 16);
        expect(context.traceId, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(context.spanId, matches(RegExp(r'^[0-9a-f]{16}$')));
      });

      test('should be sampled by default', () {
        final context = TraceContext.root();

        expect(context.isSampled, isTrue);
        expect(context.traceFlags, 0x01);
      });

      test('should not be sampled when specified', () {
        final context = TraceContext.root(sampled: false);

        expect(context.isSampled, isFalse);
        expect(context.traceFlags, 0);
      });

      test('should generate unique IDs', () {
        final context1 = TraceContext.root();
        final context2 = TraceContext.root();

        expect(context1.traceId, isNot(context2.traceId));
        expect(context1.spanId, isNot(context2.spanId));
      });
    });

    group('fromHeader', () {
      test('should parse valid traceparent', () {
        const header = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
        final context = TraceContext.fromHeader(header);

        expect(context.traceId, '0af7651916cd43dd8448eb211c80319c');
        expect(context.spanId, 'b7ad6b7169203331');
        expect(context.traceFlags, 0x01);
        expect(context.isSampled, isTrue);
      });

      test('should parse unsampled traceparent', () {
        const header = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00';
        final context = TraceContext.fromHeader(header);

        expect(context.isSampled, isFalse);
        expect(context.traceFlags, 0x00);
      });

      test('should throw on invalid format - too few parts', () {
        expect(
          () => TraceContext.fromHeader('00-abc-def'),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw on unsupported version', () {
        const header = '01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
        expect(
          () => TraceContext.fromHeader(header),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported version'),
          )),
        );
      });

      test('should throw on invalid traceId length', () {
        const header = '00-abc-b7ad6b7169203331-01';
        expect(
          () => TraceContext.fromHeader(header),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid traceId length'),
          )),
        );
      });

      test('should throw on invalid spanId length', () {
        const header = '00-0af7651916cd43dd8448eb211c80319c-abc-01';
        expect(
          () => TraceContext.fromHeader(header),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid spanId length'),
          )),
        );
      });
    });

    group('tryFromHeader', () {
      test('should return context for valid header', () {
        const header = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
        final context = TraceContext.tryFromHeader(header);

        expect(context, isNotNull);
        expect(context!.traceId, '0af7651916cd43dd8448eb211c80319c');
      });

      test('should return null for invalid header', () {
        expect(TraceContext.tryFromHeader('invalid'), isNull);
        expect(TraceContext.tryFromHeader('00-abc'), isNull);
      });
    });

    group('toHeader', () {
      test('should format as valid traceparent', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
        );

        expect(
          context.toHeader(),
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
        );
      });

      test('should pad flags with zero', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x00,
        );

        expect(context.toHeader(), endsWith('-00'));
      });

      test('should roundtrip from/to header', () {
        const original =
            '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
        final context = TraceContext.fromHeader(original);
        final result = context.toHeader();

        expect(result, original);
      });
    });

    group('createChild', () {
      test('should maintain same traceId', () {
        const parent = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
        );

        final child = parent.createChild();

        expect(child.traceId, parent.traceId);
        expect(child.traceFlags, parent.traceFlags);
        expect(child.traceState, parent.traceState);
      });

      test('should generate new spanId', () {
        const parent = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
        );

        final child = parent.createChild();

        expect(child.spanId, isNot(parent.spanId));
        expect(child.spanId.length, 16);
      });

      test('should preserve traceState', () {
        const parent = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceState: 'vendor=value',
        );

        final child = parent.createChild();

        expect(child.traceState, 'vendor=value');
      });
    });

    group('withSampling', () {
      test('should enable sampling', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x00,
        );

        final sampled = context.withSampling(sampled: true);

        expect(sampled.isSampled, isTrue);
        expect(sampled.traceFlags, 0x01);
      });

      test('should disable sampling', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
        );

        final unsampled = context.withSampling(sampled: false);

        expect(unsampled.isSampled, isFalse);
        expect(unsampled.traceFlags, 0x00);
      });

      test('should preserve other fields', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceState: 'vendor=value',
        );

        final sampled = context.withSampling(sampled: true);

        expect(sampled.traceId, context.traceId);
        expect(sampled.spanId, context.spanId);
        expect(sampled.traceState, context.traceState);
      });
    });

    group('withTraceState', () {
      test('should set traceState', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
        );

        final withState = context.withTraceState('vendor=value');

        expect(withState.traceState, 'vendor=value');
      });

      test('should clear traceState with null', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceState: 'vendor=value',
        );

        final cleared = context.withTraceState(null);

        expect(cleared.traceState, isNull);
      });
    });

    group('equality', () {
      test('should be equal for same values', () {
        const context1 = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
          traceState: 'vendor=value',
        );

        const context2 = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
          traceState: 'vendor=value',
        );

        expect(context1, context2);
        expect(context1.hashCode, context2.hashCode);
      });

      test('should not be equal for different values', () {
        const context1 = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
        );

        const context2 = TraceContext(
          traceId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          spanId: 'b7ad6b7169203331',
        );

        expect(context1, isNot(context2));
      });
    });

    test('toString should include relevant info', () {
      const context = TraceContext(
        traceId: '0af7651916cd43dd8448eb211c80319c',
        spanId: 'b7ad6b7169203331',
        traceFlags: 0x01,
      );

      final str = context.toString();

      expect(str, contains('TraceContext'));
      expect(str, contains('traceId: 0af7651916cd43dd8448eb211c80319c'));
      expect(str, contains('isSampled: true'));
    });
  });

  group('W3CTraceContextPropagator', () {
    const propagator = W3CTraceContextPropagator();

    group('inject', () {
      test('should inject traceparent header', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceFlags: 0x01,
        );

        final headers = propagator.inject(context);

        expect(
          headers['traceparent'],
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
        );
      });

      test('should inject tracestate when present', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
          traceState: 'vendor=value',
        );

        final headers = propagator.inject(context);

        expect(headers['tracestate'], 'vendor=value');
      });

      test('should not inject tracestate when null', () {
        const context = TraceContext(
          traceId: '0af7651916cd43dd8448eb211c80319c',
          spanId: 'b7ad6b7169203331',
        );

        final headers = propagator.inject(context);

        expect(headers.containsKey('tracestate'), isFalse);
      });
    });

    group('extract', () {
      test('should extract from valid headers', () {
        final headers = {
          'traceparent':
              '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
        };

        final context = propagator.extract(headers);

        expect(context, isNotNull);
        expect(context!.traceId, '0af7651916cd43dd8448eb211c80319c');
        expect(context.spanId, 'b7ad6b7169203331');
        expect(context.isSampled, isTrue);
      });

      test('should extract tracestate', () {
        final headers = {
          'traceparent':
              '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
          'tracestate': 'vendor=value',
        };

        final context = propagator.extract(headers);

        expect(context!.traceState, 'vendor=value');
      });

      test('should handle case-insensitive headers', () {
        final headers = {
          'Traceparent':
              '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
          'TraceState': 'vendor=value',
        };

        final context = propagator.extract(headers);

        expect(context, isNotNull);
        expect(context!.traceState, 'vendor=value');
      });

      test('should return null when traceparent missing', () {
        final context = propagator.extract({});

        expect(context, isNull);
      });

      test('should return null for invalid traceparent', () {
        final headers = {'traceparent': 'invalid'};

        final context = propagator.extract(headers);

        expect(context, isNull);
      });
    });

    test('should roundtrip inject/extract', () {
      const original = TraceContext(
        traceId: '0af7651916cd43dd8448eb211c80319c',
        spanId: 'b7ad6b7169203331',
        traceFlags: 0x01,
        traceState: 'vendor=value',
      );

      final headers = propagator.inject(original);
      final extracted = propagator.extract(headers);

      expect(extracted, original);
    });
  });

  group('TraceContextPropagator.w3c', () {
    test('should be W3CTraceContextPropagator instance', () {
      expect(
        TraceContextPropagator.w3c,
        isA<W3CTraceContextPropagator>(),
      );
    });
  });
}
