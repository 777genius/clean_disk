import 'dart:io';
import 'dart:typed_data';

import 'package:dio_http_client/dio_http_client.dart';
import 'package:test/test.dart';

import 'test_http_server.dart';

void main() {
  late TestHttpServer server;
  late DioHttpClient client;

  setUp(() async {
    server = TestHttpServer();
    await server.start();

    client = DioHttpClient(
      config: DioHttpClientConfig(
        baseUrl: server.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    await client.initialize();
  });

  tearDown(() async {
    await client.dispose();
    await server.stop();
  });

  group('DioHttpClient E2E', () {
    group('GET requests', () {
      test('should make successful GET request', () async {
        server.addHandler(
          '/users',
          TestHttpServer.jsonResponse({'id': 1, 'name': 'John'}),
        );

        final response = await client.get<Map<String, dynamic>>(
          '/users',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.data, equals({'id': 1, 'name': 'John'}));
      });

      test('should include query parameters', () async {
        server.addHandler('/search', (request) async {
          final query = request.uri.queryParameters;
          await request.response.json({
            'query': query['q'],
            'page': query['page'],
          });
        });

        final response = await client.get<Map<String, dynamic>>(
          '/search',
          queryParameters: {'q': 'test', 'page': '1'},
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['query'], equals('test'));
        expect(response.data?['page'], equals('1'));
      });

      test('should include custom headers', () async {
        server.addHandler('/headers', (request) async {
          await request.response.json({
            'x-custom': request.header('X-Custom'),
            'accept': request.header('Accept'),
          });
        });

        final response = await client.get<Map<String, dynamic>>(
          '/headers',
          headers: {
            'X-Custom': 'custom-value',
            'Accept': 'application/json',
          },
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['x-custom'], equals('custom-value'));
        expect(response.data?['accept'], equals('application/json'));
      });

      test('should extract response headers', () async {
        server.addHandler('/with-headers', (request) async {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.add('X-Request-Id', 'abc123')
            ..headers.add('X-Rate-Limit', '100');
          await request.response.json({'success': true});
        });

        final response = await client.get<Map<String, dynamic>>(
          '/with-headers',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.headers['x-request-id'], equals('abc123'));
        expect(response.headers['x-rate-limit'], equals('100'));
      });
    });

    group('POST requests', () {
      test('should send JSON body', () async {
        server.addHandler('/users', (request) async {
          final body = await request.readAsJson();
          await request.response.json({
            'id': 1,
            'received': body,
          }, statusCode: HttpStatus.created);
        });

        final response = await client.post<Map<String, dynamic>>(
          '/users',
          body: JsonBody({'name': 'John', 'email': 'john@example.com'}),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.statusCode, equals(HttpStatus.created));
        expect(response.data?['received']['name'], equals('John'));
        expect(response.data?['received']['email'], equals('john@example.com'));
      });

      test('should send form body', () async {
        server.addHandler('/login', (request) async {
          final body = await request.readAsString();
          // Form data comes as URL encoded
          await request.response.json({
            'received': body,
            'contentType': request.headers.contentType?.toString(),
          });
        });

        final response = await client.post<Map<String, dynamic>>(
          '/login',
          body: FormBody({'username': 'john', 'password': 'secret'}),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.statusCode, equals(HttpStatus.ok));
        final received = response.data?['received'] as String;
        expect(received, contains('username=john'));
        expect(received, contains('password=secret'));
      });

      test('should send text body', () async {
        server.addHandler('/text', (request) async {
          final body = await request.readAsString();
          await request.response.json({'received': body});
        });

        final response = await client.post<Map<String, dynamic>>(
          '/text',
          body: TextBody('Hello, World!'),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['received'], equals('Hello, World!'));
      });

      test('should send binary body', () async {
        server.addHandler('/binary', (request) async {
          final bytes = await request.fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
          await request.response.json({
            'length': bytes.length,
            'first': bytes.first,
            'last': bytes.last,
          });
        });

        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final response = await client.post<Map<String, dynamic>>(
          '/binary',
          body: BinaryBody(bytes),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['length'], equals(5));
        expect(response.data?['first'], equals(1));
        expect(response.data?['last'], equals(5));
      });
    });

    group('PUT requests', () {
      test('should make PUT request with JSON body', () async {
        server.addHandler('/users/1', (request) async {
          expect(request.method, equals('PUT'));
          final body = await request.readAsJson();
          await request.response.json({
            'id': 1,
            'updated': body,
          });
        });

        final response = await client.put<Map<String, dynamic>>(
          '/users/1',
          body: JsonBody({'name': 'Jane'}),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['updated']['name'], equals('Jane'));
      });
    });

    group('PATCH requests', () {
      test('should make PATCH request with JSON body', () async {
        server.addHandler('/users/1', (request) async {
          expect(request.method, equals('PATCH'));
          final body = await request.readAsJson();
          await request.response.json({
            'id': 1,
            'patched': body,
          });
        });

        final response = await client.patch<Map<String, dynamic>>(
          '/users/1',
          body: JsonBody({'email': 'new@example.com'}),
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['patched']['email'], equals('new@example.com'));
      });
    });

    group('DELETE requests', () {
      test('should make DELETE request', () async {
        server.addHandler('/users/1', (request) async {
          expect(request.method, equals('DELETE'));
          await request.response.json({'deleted': true});
        });

        final response = await client.delete<Map<String, dynamic>>(
          '/users/1',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['deleted'], isTrue);
      });

      test('should handle 204 No Content response', () async {
        server.addHandler('/users/1', (request) async {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
        });

        final response = await client.delete<Map<String, dynamic>?>('/users/1');

        expect(response.statusCode, equals(HttpStatus.noContent));
        expect(response.data, isNull);
      });
    });

    group('HEAD requests', () {
      test('should make HEAD request', () async {
        server.addHandler('/resource', (request) async {
          expect(request.method, equals('HEAD'));
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.add('Content-Length', '1024')
            ..headers.add('Last-Modified', 'Mon, 01 Jan 2024 00:00:00 GMT');
          await request.response.close();
        });

        final response = await client.head<void>('/resource');

        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.headers['content-length'], equals('1024'));
      });
    });

    group('Response status codes', () {
      test('should handle 201 Created', () async {
        server.addHandler(
          '/resources',
          TestHttpServer.jsonResponse(
            {'id': 1},
            statusCode: HttpStatus.created,
          ),
        );

        final response = await client.post<Map<String, dynamic>>(
          '/resources',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.statusCode, equals(HttpStatus.created));
      });

      test('should handle 202 Accepted', () async {
        server.addHandler(
          '/jobs',
          TestHttpServer.jsonResponse(
            {'jobId': 'abc123'},
            statusCode: HttpStatus.accepted,
          ),
        );

        final response = await client.post<Map<String, dynamic>>(
          '/jobs',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.statusCode, equals(HttpStatus.accepted));
        expect(response.data?['jobId'], equals('abc123'));
      });
    });

    group('Response decoder', () {
      test('should apply decoder to response data', () async {
        server.addHandler(
          '/user',
          TestHttpServer.jsonResponse({'id': 1, 'name': 'John', 'age': 30}),
        );

        final response = await client.get<String>(
          '/user',
          decoder: (data) {
            final map = data as Map<String, dynamic>;
            return '${map['name']} (${map['age']})';
          },
        );

        expect(response.data, equals('John (30)'));
      });

      test('should preserve rawBody alongside decoded data', () async {
        server.addHandler(
          '/data',
          TestHttpServer.jsonResponse({'value': 42}),
        );

        final response = await client.get<int>(
          '/data',
          decoder: (data) => (data as Map<String, dynamic>)['value'] as int,
        );

        expect(response.data, equals(42));
        expect(response.rawBody, isNotNull);
        expect((response.rawBody as Map)['value'], equals(42));
      });
    });

    group('Client lifecycle', () {
      test('should throw if not initialized', () async {
        final uninitializedClient = DioHttpClient(
          config: DioHttpClientConfig(baseUrl: server.baseUrl),
        );

        expect(
          () => uninitializedClient.get<void>('/test'),
          throwsA(isA<StateError>()),
        );
      });

      test('should be idempotent on multiple initialize calls', () async {
        // Already initialized in setUp, call again
        await client.initialize();
        await client.initialize();

        server.addHandler('/test', TestHttpServer.jsonResponse({'ok': true}));

        final response = await client.get<Map<String, dynamic>>(
          '/test',
          decoder: (data) => data as Map<String, dynamic>,
        );

        expect(response.data?['ok'], isTrue);
      });

      test('should throw if sending request after dispose', () async {
        await client.dispose();

        expect(
          () => client.get<void>('/test'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
