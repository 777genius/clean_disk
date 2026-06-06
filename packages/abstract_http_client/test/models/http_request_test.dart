import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('HttpRequest', () {
    test('should create with required parameters', () {
      const request = HttpRequest(
        method: HttpMethod.get,
        path: '/users',
      );

      expect(request.method, HttpMethod.get);
      expect(request.path, '/users');
      expect(request.baseUrl, isNull);
      expect(request.queryParameters, isNull);
      expect(request.headers, isNull);
      expect(request.body, isNull);
      expect(request.timeout, isNull);
      expect(request.requiresAuth, isFalse);
      expect(request.extra, isNull);
    });

    test('should create with all parameters', () {
      final baseUrl = Uri.parse('https://api.example.com');
      const body = HttpBody.json({'key': 'value'});

      final request = HttpRequest(
        method: HttpMethod.post,
        path: '/users',
        baseUrl: baseUrl,
        queryParameters: const {'page': 1},
        headers: const {'X-Custom': 'value'},
        body: body,
        timeout: const Duration(seconds: 30),
        requiresAuth: true,
        extra: const {'trace_id': '123'},
      );

      expect(request.method, HttpMethod.post);
      expect(request.path, '/users');
      expect(request.baseUrl, baseUrl);
      expect(request.queryParameters, {'page': 1});
      expect(request.headers, {'X-Custom': 'value'});
      expect(request.body, body);
      expect(request.timeout, const Duration(seconds: 30));
      expect(request.requiresAuth, isTrue);
      expect(request.extra, {'trace_id': '123'});
    });

    group('named constructors', () {
      test('HttpRequest.get should set method to GET', () {
        const request = HttpRequest.get('/users');
        expect(request.method, HttpMethod.get);
        expect(request.body, isNull);
      });

      test('HttpRequest.post should set method to POST', () {
        const request = HttpRequest.post('/users');
        expect(request.method, HttpMethod.post);
      });

      test('HttpRequest.put should set method to PUT', () {
        const request = HttpRequest.put('/users/1');
        expect(request.method, HttpMethod.put);
      });

      test('HttpRequest.patch should set method to PATCH', () {
        const request = HttpRequest.patch('/users/1');
        expect(request.method, HttpMethod.patch);
      });

      test('HttpRequest.delete should set method to DELETE', () {
        const request = HttpRequest.delete('/users/1');
        expect(request.method, HttpMethod.delete);
      });
    });

    group('resolveUri', () {
      test('should resolve with baseUrl', () {
        final request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          baseUrl: Uri.parse('https://api.example.com'),
        );

        final uri = request.resolveUri();
        expect(uri.toString(), startsWith('https://api.example.com/users'));
      });

      test('should use defaultBaseUrl when baseUrl is null', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
        );

        final uri = request.resolveUri(
          defaultBaseUrl: Uri.parse('https://default.example.com'),
        );
        expect(uri.toString(), startsWith('https://default.example.com/users'));
      });

      test('should prefer baseUrl over defaultBaseUrl', () {
        final request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          baseUrl: Uri.parse('https://api.example.com'),
        );

        final uri = request.resolveUri(
          defaultBaseUrl: Uri.parse('https://default.example.com'),
        );
        expect(uri.toString(), startsWith('https://api.example.com/users'));
      });

      test('should include query parameters', () {
        final request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          baseUrl: Uri.parse('https://api.example.com'),
          queryParameters: const {'page': 1, 'limit': 10},
        );

        final uri = request.resolveUri();
        expect(uri.queryParameters['page'], '1');
        expect(uri.queryParameters['limit'], '10');
      });

      test('should handle path without leading slash', () {
        final request = HttpRequest(
          method: HttpMethod.get,
          path: 'users',
          baseUrl: Uri.parse('https://api.example.com'),
        );

        final uri = request.resolveUri();
        expect(uri.path, '/users');
      });

      test('should work without baseUrl', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users?existing=param',
          queryParameters: {'new': 'param'},
        );

        final uri = request.resolveUri();
        expect(uri.path, '/users');
        expect(uri.queryParameters['new'], 'param');
      });
    });

    group('copyWith', () {
      test('should create copy with changed values', () {
        const original = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
        );

        final copy = original.copyWith(
          method: HttpMethod.post,
          path: '/posts',
          requiresAuth: true,
        );

        expect(copy.method, HttpMethod.post);
        expect(copy.path, '/posts');
        expect(copy.requiresAuth, isTrue);
      });

      test('should preserve unchanged values', () {
        const original = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          headers: {'X-Custom': 'value'},
        );

        final copy = original.copyWith(path: '/posts');

        expect(copy.method, HttpMethod.get);
        expect(copy.headers, {'X-Custom': 'value'});
      });
    });

    group('withHeaders', () {
      test('should add headers to existing', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          headers: {'X-Original': 'value'},
        );

        final result = request.withHeaders({'X-New': 'new'});

        expect(result.headers, {
          'X-Original': 'value',
          'X-New': 'new',
        });
      });

      test('should override existing headers', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          headers: {'X-Header': 'old'},
        );

        final result = request.withHeaders({'X-Header': 'new'});

        expect(result.headers?['X-Header'], 'new');
      });

      test('should work when no existing headers', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
        );

        final result = request.withHeaders({'X-New': 'value'});

        expect(result.headers, {'X-New': 'value'});
      });
    });

    group('withQueryParameters', () {
      test('should add query parameters to existing', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          queryParameters: {'page': 1},
        );

        final result = request.withQueryParameters({'limit': 10});

        expect(result.queryParameters, {
          'page': 1,
          'limit': 10,
        });
      });

      test('should work when no existing query parameters', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
        );

        final result = request.withQueryParameters({'page': 1});

        expect(result.queryParameters, {'page': 1});
      });
    });

    group('withExtra', () {
      test('should add extra data', () {
        const request = HttpRequest(
          method: HttpMethod.get,
          path: '/users',
          extra: {'trace_id': '123'},
        );

        final result = request.withExtra({'request_id': '456'});

        expect(result.extra, {
          'trace_id': '123',
          'request_id': '456',
        });
      });
    });

    test('toString should include method and path', () {
      const request = HttpRequest(
        method: HttpMethod.post,
        path: '/users',
      );

      final str = request.toString();
      expect(str, contains('POST'));
      expect(str, contains('/users'));
    });

    test('equality should be based on all fields', () {
      const a = HttpRequest(
        method: HttpMethod.get,
        path: '/users',
        headers: {'X-Test': 'value'},
      );

      const b = HttpRequest(
        method: HttpMethod.get,
        path: '/users',
        headers: {'X-Test': 'value'},
      );

      const c = HttpRequest(
        method: HttpMethod.post,
        path: '/users',
        headers: {'X-Test': 'value'},
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
