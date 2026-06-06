import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMethod', () {
    test('should have seven methods', () {
      expect(HttpMethod.values.length, 7);
    });

    group('value', () {
      test('get should have value GET', () {
        expect(HttpMethod.get.value, 'GET');
      });

      test('post should have value POST', () {
        expect(HttpMethod.post.value, 'POST');
      });

      test('put should have value PUT', () {
        expect(HttpMethod.put.value, 'PUT');
      });

      test('patch should have value PATCH', () {
        expect(HttpMethod.patch.value, 'PATCH');
      });

      test('delete should have value DELETE', () {
        expect(HttpMethod.delete.value, 'DELETE');
      });

      test('head should have value HEAD', () {
        expect(HttpMethod.head.value, 'HEAD');
      });

      test('options should have value OPTIONS', () {
        expect(HttpMethod.options.value, 'OPTIONS');
      });
    });

    group('isSafe', () {
      test('GET should be safe', () {
        expect(HttpMethod.get.isSafe, isTrue);
      });

      test('HEAD should be safe', () {
        expect(HttpMethod.head.isSafe, isTrue);
      });

      test('OPTIONS should be safe', () {
        expect(HttpMethod.options.isSafe, isTrue);
      });

      test('POST should not be safe', () {
        expect(HttpMethod.post.isSafe, isFalse);
      });

      test('PUT should not be safe', () {
        expect(HttpMethod.put.isSafe, isFalse);
      });

      test('PATCH should not be safe', () {
        expect(HttpMethod.patch.isSafe, isFalse);
      });

      test('DELETE should not be safe', () {
        expect(HttpMethod.delete.isSafe, isFalse);
      });
    });

    group('isIdempotent', () {
      test('GET should be idempotent', () {
        expect(HttpMethod.get.isIdempotent, isTrue);
      });

      test('HEAD should be idempotent', () {
        expect(HttpMethod.head.isIdempotent, isTrue);
      });

      test('OPTIONS should be idempotent', () {
        expect(HttpMethod.options.isIdempotent, isTrue);
      });

      test('PUT should be idempotent', () {
        expect(HttpMethod.put.isIdempotent, isTrue);
      });

      test('DELETE should be idempotent', () {
        expect(HttpMethod.delete.isIdempotent, isTrue);
      });

      test('POST should not be idempotent', () {
        expect(HttpMethod.post.isIdempotent, isFalse);
      });

      test('PATCH should not be idempotent', () {
        expect(HttpMethod.patch.isIdempotent, isFalse);
      });
    });

    group('parse', () {
      test('should parse uppercase GET', () {
        expect(HttpMethod.parse('GET'), HttpMethod.get);
      });

      test('should parse lowercase get', () {
        expect(HttpMethod.parse('get'), HttpMethod.get);
      });

      test('should parse mixed case Get', () {
        expect(HttpMethod.parse('GeT'), HttpMethod.get);
      });

      test('should parse all methods', () {
        expect(HttpMethod.parse('POST'), HttpMethod.post);
        expect(HttpMethod.parse('PUT'), HttpMethod.put);
        expect(HttpMethod.parse('PATCH'), HttpMethod.patch);
        expect(HttpMethod.parse('DELETE'), HttpMethod.delete);
        expect(HttpMethod.parse('HEAD'), HttpMethod.head);
        expect(HttpMethod.parse('OPTIONS'), HttpMethod.options);
      });

      test('should throw ArgumentError for unknown method', () {
        expect(
          () => HttpMethod.parse('UNKNOWN'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown HTTP method'),
          )),
        );
      });

      test('should throw ArgumentError for empty string', () {
        expect(
          () => HttpMethod.parse(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('tryParse', () {
      test('should parse uppercase GET', () {
        expect(HttpMethod.tryParse('GET'), HttpMethod.get);
      });

      test('should parse lowercase get', () {
        expect(HttpMethod.tryParse('get'), HttpMethod.get);
      });

      test('should parse mixed case Get', () {
        expect(HttpMethod.tryParse('GeT'), HttpMethod.get);
      });

      test('should parse all methods', () {
        expect(HttpMethod.tryParse('POST'), HttpMethod.post);
        expect(HttpMethod.tryParse('PUT'), HttpMethod.put);
        expect(HttpMethod.tryParse('PATCH'), HttpMethod.patch);
        expect(HttpMethod.tryParse('DELETE'), HttpMethod.delete);
        expect(HttpMethod.tryParse('HEAD'), HttpMethod.head);
        expect(HttpMethod.tryParse('OPTIONS'), HttpMethod.options);
      });

      test('should return null for unknown method', () {
        expect(HttpMethod.tryParse('UNKNOWN'), isNull);
      });

      test('should return null for empty string', () {
        expect(HttpMethod.tryParse(''), isNull);
      });

      test('should return null for CONNECT (not supported)', () {
        expect(HttpMethod.tryParse('CONNECT'), isNull);
      });

      test('should return null for TRACE (not supported)', () {
        expect(HttpMethod.tryParse('TRACE'), isNull);
      });
    });

    group('toString', () {
      test('should return method value', () {
        expect(HttpMethod.get.toString(), 'GET');
        expect(HttpMethod.post.toString(), 'POST');
        expect(HttpMethod.put.toString(), 'PUT');
        expect(HttpMethod.patch.toString(), 'PATCH');
        expect(HttpMethod.delete.toString(), 'DELETE');
        expect(HttpMethod.head.toString(), 'HEAD');
        expect(HttpMethod.options.toString(), 'OPTIONS');
      });
    });

    group('safe and idempotent relationship', () {
      test('all safe methods should be idempotent', () {
        for (final method in HttpMethod.values) {
          if (method.isSafe) {
            expect(
              method.isIdempotent,
              isTrue,
              reason: '$method is safe but not idempotent',
            );
          }
        }
      });

      test('not all idempotent methods are safe', () {
        // PUT and DELETE are idempotent but not safe
        expect(HttpMethod.put.isIdempotent, isTrue);
        expect(HttpMethod.put.isSafe, isFalse);
        expect(HttpMethod.delete.isIdempotent, isTrue);
        expect(HttpMethod.delete.isSafe, isFalse);
      });
    });
  });
}
