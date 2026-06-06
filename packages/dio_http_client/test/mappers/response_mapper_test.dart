import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_client/src/mappers/response_mapper.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(
    method: HttpMethod.get,
    path: '/test',
  );

  group('DioResponseMapper', () {
    group('toHttpResponse', () {
      test('should map basic response', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          statusMessage: 'OK',
          data: {'key': 'value'},
        );

        final response = DioResponseMapper.toHttpResponse<Map<String, dynamic>>(
          dioResponse,
          request: testRequest,
        );

        expect(response.statusCode, 200);
        expect(response.statusMessage, 'OK');
        expect(response.data, {'key': 'value'});
        expect(response.request, testRequest);
      });

      test('should use decoder when provided', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'name': 'John', 'age': 30},
        );

        final response = DioResponseMapper.toHttpResponse<String>(
          dioResponse,
          request: testRequest,
          decoder: (data) => (data as Map)['name'] as String,
        );

        expect(response.data, 'John');
      });

      test('should handle null data', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 204,
        );

        final response = DioResponseMapper.toHttpResponse<String>(
          dioResponse,
          request: testRequest,
        );

        expect(response.statusCode, 204);
        expect(response.data, isNull);
      });

      test('should extract headers', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          headers: Headers.fromMap({
            'Content-Type': ['application/json'],
            'X-Custom': ['value1', 'value2'],
          }),
        );

        final response = DioResponseMapper.toHttpResponse<dynamic>(
          dioResponse,
          request: testRequest,
        );

        expect(response.headers['Content-Type'], 'application/json');
        expect(response.headers['X-Custom'], 'value1, value2');
      });

      test('should preserve raw body', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: '{"raw": "json"}',
        );

        final response = DioResponseMapper.toHttpResponse<dynamic>(
          dioResponse,
          request: testRequest,
        );

        expect(response.rawBody, '{"raw": "json"}');
      });

      test('should preserve extra', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          extra: {'cached': true},
        );

        final response = DioResponseMapper.toHttpResponse<dynamic>(
          dioResponse,
          request: testRequest,
        );

        expect(response.extra, {'cached': true});
      });

      test('should handle null status code', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
        );

        final response = DioResponseMapper.toHttpResponse<dynamic>(
          dioResponse,
          request: testRequest,
        );

        expect(response.statusCode, 0);
      });

      test('should pass data through when type matches', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: 'string data',
        );

        final response = DioResponseMapper.toHttpResponse<String>(
          dioResponse,
          request: testRequest,
        );

        expect(response.data, 'string data');
      });

      test('should return null when type does not match', () {
        final dioResponse = Response<dynamic>(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 200,
          data: {'key': 'value'},
        );

        final response = DioResponseMapper.toHttpResponse<String>(
          dioResponse,
          request: testRequest,
        );

        expect(response.data, isNull);
      });
    });
  });
}
