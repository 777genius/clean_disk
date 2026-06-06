import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('CancelToken', () {
    test('should not be cancelled initially', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
      expect(token.cancelException, isNull);
    });

    test('should be cancelled after cancel() call', () {
      final token = CancelToken();
      token.cancel('Test reason');
      expect(token.isCancelled, isTrue);
      expect(token.cancelException?.message, 'Test reason');
    });

    test('should be cancelled without reason', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(token.cancelException, isNotNull);
      expect(token.cancelException?.message, isNull);
    });

    test('cancel() should be idempotent', () {
      final token = CancelToken();
      token.cancel('First');
      token.cancel('Second');
      expect(token.cancelException?.message, 'First');
    });

    test('should notify listeners on cancel', () {
      final token = CancelToken();
      var notified = false;
      token.addListener(() => notified = true);

      token.cancel();

      expect(notified, isTrue);
    });

    test('should notify multiple listeners', () {
      final token = CancelToken();
      var count = 0;
      token.addListener(() => count++);
      token.addListener(() => count++);
      token.addListener(() => count++);

      token.cancel();

      expect(count, 3);
    });

    test('should call listener immediately if already cancelled', () {
      final token = CancelToken();
      token.cancel();

      var notified = false;
      token.addListener(() => notified = true);

      expect(notified, isTrue);
    });

    test('removeListener should prevent notification', () {
      final token = CancelToken();
      var notified = false;
      void listener() => notified = true;

      token.addListener(listener);
      token.removeListener(listener);
      token.cancel();

      expect(notified, isFalse);
    });

    test('whenCancelled should throw CancelException when cancelled', () async {
      final token = CancelToken();

      Future.delayed(const Duration(milliseconds: 10), () {
        token.cancel('async');
      });

      await expectLater(
        token.whenCancelled,
        throwsA(
          isA<CancelException>().having((e) => e.message, 'message', 'async'),
        ),
      );
    });

    test('throwIfCancelled should throw when cancelled', () {
      final token = CancelToken();
      token.cancel('reason');

      expect(
        token.throwIfCancelled,
        throwsA(isA<CancelException>()),
      );
    });

    test('throwIfCancelled should not throw when not cancelled', () {
      final token = CancelToken();

      expect(
        token.throwIfCancelled,
        returnsNormally,
      );
    });

    test('toString should include cancellation state', () {
      final token = CancelToken();
      expect(token.toString(), contains('isCancelled: false'));

      token.cancel('reason');
      expect(token.toString(), contains('isCancelled: true'));
      expect(token.toString(), contains('reason'));
    });

    group('timeout factory', () {
      test('should not be cancelled initially', () {
        final token = CancelToken.timeout(const Duration(seconds: 10));
        expect(token.isCancelled, isFalse);
      });

      test('should auto-cancel after duration', () async {
        final token = CancelToken.timeout(const Duration(milliseconds: 50));
        expect(token.isCancelled, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(token.isCancelled, isTrue);
      });

      test('should not cancel if already cancelled manually', () async {
        final token = CancelToken.timeout(const Duration(milliseconds: 100));
        token.cancel('Manual');

        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(token.cancelException?.message, 'Manual');
      });
    });
  });

  group('CancelException', () {
    test('should have message', () {
      const exception = CancelException('test message');
      expect(exception.message, 'test message');
    });

    test('should allow null message', () {
      const exception = CancelException();
      expect(exception.message, isNull);
    });

    test('toString should include message', () {
      const exception = CancelException('test');
      expect(exception.toString(), contains('test'));
    });

    test('toString should have default message when null', () {
      const exception = CancelException();
      expect(exception.toString(), contains('Request cancelled'));
    });

    test('equality should be based on message', () {
      const a = CancelException('same');
      const b = CancelException('same');
      const c = CancelException('different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode should be based on message', () {
      const a = CancelException('same');
      const b = CancelException('same');

      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
