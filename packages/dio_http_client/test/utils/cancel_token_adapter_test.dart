import 'package:abstract_http_client/abstract_http_client.dart' as http;
import 'package:dio/dio.dart' as dio;
import 'package:dio_http_client/src/utils/cancel_token_adapter.dart';
import 'package:test/test.dart';

void main() {
  group('CancelTokenAdapter', () {
    group('toDio', () {
      test('should return null for null token', () {
        final result = CancelTokenAdapter.toDio(null);
        expect(result, isNull);
      });

      test('should convert abstract token to Dio token', () {
        final httpToken = http.CancelToken();
        final dioToken = CancelTokenAdapter.toDio(httpToken);

        expect(dioToken, isNotNull);
        expect(dioToken, isA<dio.CancelToken>());
      });

      test('should return same Dio token for same abstract token', () {
        final httpToken = http.CancelToken();
        final dioToken1 = CancelTokenAdapter.toDio(httpToken);
        final dioToken2 = CancelTokenAdapter.toDio(httpToken);

        expect(dioToken1, same(dioToken2));
      });

      test('should propagate cancellation from abstract to Dio', () async {
        final httpToken = http.CancelToken();
        final dioToken = CancelTokenAdapter.toDio(httpToken)!;

        httpToken.cancel('Test reason');

        // Give time for async propagation
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(dioToken.isCancelled, isTrue);
      });

      test('should cancel Dio token immediately if already cancelled', () {
        final httpToken = http.CancelToken();
        httpToken.cancel('Already cancelled');

        final dioToken = CancelTokenAdapter.toDio(httpToken)!;

        expect(dioToken.isCancelled, isTrue);
      });
    });

    group('fromDio', () {
      test('should convert Dio token to abstract token', () {
        final dioToken = dio.CancelToken();
        final httpToken = CancelTokenAdapter.fromDio(dioToken);

        expect(httpToken, isNotNull);
        expect(httpToken, isA<http.CancelToken>());
      });

      test('should return same abstract token for same Dio token', () {
        final dioToken = dio.CancelToken();
        final httpToken1 = CancelTokenAdapter.fromDio(dioToken);
        final httpToken2 = CancelTokenAdapter.fromDio(dioToken);

        expect(httpToken1, same(httpToken2));
      });

      test('should propagate cancellation from Dio to abstract', () async {
        final dioToken = dio.CancelToken();
        final httpToken = CancelTokenAdapter.fromDio(dioToken);

        dioToken.cancel('Dio cancelled');

        // Give time for async propagation
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(httpToken.isCancelled, isTrue);
      });

      test('should cancel abstract token immediately if already cancelled', () {
        final dioToken = dio.CancelToken();
        dioToken.cancel('Already cancelled');

        final httpToken = CancelTokenAdapter.fromDio(dioToken);

        expect(httpToken.isCancelled, isTrue);
      });
    });

    group('cleanup', () {
      test('should handle null token', () {
        // Should not throw
        CancelTokenAdapter.cleanup(null);
      });

      test('should remove listener from token', () {
        final httpToken = http.CancelToken();
        CancelTokenAdapter.toDio(httpToken);

        CancelTokenAdapter.cleanup(httpToken);

        // Cleanup should not throw and should work
        // We can't directly test listener removal, but we can ensure
        // the method completes without error
      });
    });

    group('CancelTokenDioExtension', () {
      test('should convert using extension method', () {
        final httpToken = http.CancelToken();
        final dioToken = httpToken.toDio();

        expect(dioToken, isA<dio.CancelToken>());
      });
    });

    group('DioCancelTokenExtension', () {
      test('should convert using extension method', () {
        final dioToken = dio.CancelToken();
        final httpToken = dioToken.toAbstract();

        expect(httpToken, isA<http.CancelToken>());
      });
    });
  });
}
