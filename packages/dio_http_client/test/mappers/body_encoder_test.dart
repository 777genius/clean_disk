import 'dart:typed_data';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_client/src/mappers/body_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('DioBodyEncoder', () {
    group('encode', () {
      test('should return null for null body', () async {
        final result = await DioBodyEncoder.encode(null);
        expect(result, isNull);
      });

      test('should encode JsonBody to map', () async {
        const body = HttpBody.json({'key': 'value', 'number': 42});
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Map<String, dynamic>>());
        expect((result as Map)['key'], 'value');
        expect(result['number'], 42);
      });

      test('should encode FormBody to map', () async {
        const body = HttpBody.form({'username': 'john', 'password': 'secret'});
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Map<String, String>>());
        expect((result as Map)['username'], 'john');
        expect(result['password'], 'secret');
      });

      test('should encode BinaryBody to bytes', () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final body = HttpBody.binary(bytes);
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Uint8List>());
        expect(result, bytes);
      });

      test('should encode TextBody to string', () async {
        const body = HttpBody.text('Hello, World!');
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<String>());
        expect(result, 'Hello, World!');
      });

      test('should encode EmptyBody to null', () async {
        const body = HttpBody.empty();
        final result = await DioBodyEncoder.encode(body);

        expect(result, isNull);
      });

      test('should encode StreamBody to stream', () async {
        final stream = Stream<List<int>>.value([1, 2, 3]);
        final body = HttpBody.stream(stream);
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Stream<List<int>>>());
      });

      test('should encode MultipartBody to FormData', () async {
        final body = HttpBody.multipart(
          parts: [
            const HttpPart.field(name: 'name', value: 'John'),
            HttpPart.bytes(
              name: 'file',
              filename: 'test.txt',
              bytes: Uint8List.fromList([72, 101, 108, 108, 111]),
            ),
          ],
        );
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<FormData>());
        final formData = result! as FormData;
        expect(formData.fields.length, 1);
        expect(formData.files.length, 1);
      });

      test('should encode MultipartBody with field parts', () async {
        const body = HttpBody.multipart(
          parts: [
            HttpPart.field(name: 'key1', value: 'value1'),
            HttpPart.field(name: 'key2', value: 'value2'),
          ],
        );
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<FormData>());
        final formData = result! as FormData;
        expect(formData.fields.length, 2);
        expect(formData.fields[0].key, 'key1');
        expect(formData.fields[0].value, 'value1');
        expect(formData.fields[1].key, 'key2');
        expect(formData.fields[1].value, 'value2');
      });

      test('should encode MultipartBody with bytes parts', () async {
        final body = HttpBody.multipart(
          parts: [
            HttpPart.bytes(
              name: 'file',
              filename: 'data.bin',
              bytes: Uint8List.fromList([1, 2, 3]),
              contentType: 'application/octet-stream',
            ),
          ],
        );
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<FormData>());
        final formData = result! as FormData;
        expect(formData.files.length, 1);
        expect(formData.files[0].key, 'file');
        expect(formData.files[0].value.filename, 'data.bin');
      });

      test('should encode LazyBody with map result', () async {
        final body = HttpBody.lazy(() => {'lazy': 'data'});
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Map<String, dynamic>>());
        expect((result as Map)['lazy'], 'data');
      });

      test('should encode LazyBody with string result', () async {
        final body = HttpBody.lazy(() => 'lazy string');
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<String>());
        expect(result, 'lazy string');
      });

      test('should encode LazyBody with async encoder', () async {
        final body = HttpBody.lazy(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return {'async': 'data'};
        });
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<Map<String, dynamic>>());
        expect((result as Map)['async'], 'data');
      });

      test('should encode LazyBody with list result', () async {
        final body = HttpBody.lazy(() => [1, 2, 3]);
        final result = await DioBodyEncoder.encode(body);

        expect(result, isA<List<dynamic>>());
        expect(result, [1, 2, 3]);
      });

      test('should encode LazyBody with null result', () async {
        final body = HttpBody.lazy(() => null);
        final result = await DioBodyEncoder.encode(body);

        expect(result, isNull);
      });
    });
  });
}
