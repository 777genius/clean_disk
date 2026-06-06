import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('HttpClientConfig', () {
    test('should create with default values', () {
      const config = HttpClientConfig();

      expect(config.baseUrl, isNull);
      expect(config.connectTimeout, const Duration(seconds: 30));
      expect(config.receiveTimeout, const Duration(seconds: 30));
      expect(config.sendTimeout, const Duration(seconds: 30));
      expect(config.defaultHeaders, isEmpty);
      expect(config.interceptors, isEmpty);
      expect(config.retryPolicy, isNull);
      expect(config.validateStatus, isNull);
      expect(config.followRedirects, isTrue);
      expect(config.maxRedirects, 5);
      expect(config.enableLogging, isFalse);
      expect(config.extra, isEmpty);
    });

    test('should create with custom values', () {
      final baseUrl = Uri.parse('https://api.example.com');
      final config = HttpClientConfig(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        defaultHeaders: {'X-Api-Key': 'secret'},
        followRedirects: false,
        maxRedirects: 3,
        enableLogging: true,
        extra: {'key': 'value'},
      );

      expect(config.baseUrl, baseUrl);
      expect(config.connectTimeout, const Duration(seconds: 10));
      expect(config.receiveTimeout, const Duration(seconds: 20));
      expect(config.sendTimeout, const Duration(seconds: 15));
      expect(config.defaultHeaders, {'X-Api-Key': 'secret'});
      expect(config.followRedirects, isFalse);
      expect(config.maxRedirects, 3);
      expect(config.enableLogging, isTrue);
      expect(config.extra, {'key': 'value'});
    });

    group('copyWith', () {
      test('should create copy with no changes when no args', () {
        final original = HttpClientConfig(
          baseUrl: Uri.parse('https://api.example.com'),
          connectTimeout: const Duration(seconds: 10),
        );

        final copy = original.copyWith();

        expect(copy.baseUrl, original.baseUrl);
        expect(copy.connectTimeout, original.connectTimeout);
      });

      test('should create copy with changed values', () {
        const original = HttpClientConfig(
          connectTimeout: Duration(seconds: 10),
          enableLogging: false,
        );

        final copy = original.copyWith(
          connectTimeout: const Duration(seconds: 20),
          enableLogging: true,
        );

        expect(copy.connectTimeout, const Duration(seconds: 20));
        expect(copy.enableLogging, isTrue);
        expect(copy.receiveTimeout, original.receiveTimeout);
      });
    });

    group('withHeaders', () {
      test('should merge headers', () {
        const config = HttpClientConfig(
          defaultHeaders: {'Authorization': 'Bearer token'},
        );

        final newConfig = config.withHeaders({'X-Api-Key': 'secret'});

        expect(newConfig.defaultHeaders, {
          'Authorization': 'Bearer token',
          'X-Api-Key': 'secret',
        });
      });

      test('should override existing headers', () {
        const config = HttpClientConfig(
          defaultHeaders: {'Content-Type': 'application/json'},
        );

        final newConfig = config.withHeaders({'Content-Type': 'text/plain'});

        expect(newConfig.defaultHeaders, {'Content-Type': 'text/plain'});
      });
    });

    group('withInterceptor', () {
      test('should append interceptor', () {
        const config = HttpClientConfig();
        final interceptor = _TestInterceptor();

        final newConfig = config.withInterceptor(interceptor);

        expect(newConfig.interceptors.length, 1);
        expect(newConfig.interceptors.first, interceptor);
      });

      test('should preserve existing interceptors', () {
        final interceptor1 = _TestInterceptor();
        final interceptor2 = _TestInterceptor();
        final config = HttpClientConfig(interceptors: [interceptor1]);

        final newConfig = config.withInterceptor(interceptor2);

        expect(newConfig.interceptors.length, 2);
        expect(newConfig.interceptors[0], interceptor1);
        expect(newConfig.interceptors[1], interceptor2);
      });
    });

    group('defaultValidateStatus', () {
      test('should return true for 2xx status codes', () {
        expect(HttpClientConfig.defaultValidateStatus(200), isTrue);
        expect(HttpClientConfig.defaultValidateStatus(201), isTrue);
        expect(HttpClientConfig.defaultValidateStatus(204), isTrue);
        expect(HttpClientConfig.defaultValidateStatus(299), isTrue);
      });

      test('should return false for non-2xx status codes', () {
        expect(HttpClientConfig.defaultValidateStatus(100), isFalse);
        expect(HttpClientConfig.defaultValidateStatus(199), isFalse);
        expect(HttpClientConfig.defaultValidateStatus(300), isFalse);
        expect(HttpClientConfig.defaultValidateStatus(400), isFalse);
        expect(HttpClientConfig.defaultValidateStatus(404), isFalse);
        expect(HttpClientConfig.defaultValidateStatus(500), isFalse);
      });
    });

    test('toString should include relevant information', () {
      final config = HttpClientConfig(
        baseUrl: Uri.parse('https://api.example.com'),
        enableLogging: true,
      );

      final str = config.toString();

      expect(str, contains('HttpClientConfig'));
      expect(str, contains('baseUrl: https://api.example.com'));
      expect(str, contains('enableLogging: true'));
    });
  });
}

class _TestInterceptor implements HttpInterceptor {
  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    Future<HttpRequest> Function(HttpRequest) next,
  ) => next(request);

  @override
  Future<HttpResponse<dynamic>> onResponse(
    HttpResponse<dynamic> response,
    Future<HttpResponse<dynamic>> Function(HttpResponse<dynamic>) next,
  ) => next(response);

  @override
  Future<HttpResponse<dynamic>> onError(
    HttpError error,
    Future<HttpResponse<dynamic>> Function(HttpError) next,
  ) => next(error);
}
