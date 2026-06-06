import 'dart:async';
import 'dart:typed_data';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('HttpBody', () {
    group('JsonBody', () {
      test('should create with data', () {
        const body = HttpBody.json({'key': 'value'});
        expect(body, isA<JsonBody>());
        expect((body as JsonBody).data, {'key': 'value'});
      });

      test('should support nested data', () {
        const body = HttpBody.json({
          'user': {
            'name': 'John',
            'tags': ['admin', 'user'],
          },
        });
        expect(body, isA<JsonBody>());
      });

      test('should have correct content type', () {
        const body = HttpBody.json({'key': 'value'});
        expect((body as JsonBody).contentType, startsWith('application/json'));
      });
    });

    group('FormBody', () {
      test('should create with fields', () {
        const body = HttpBody.form({'username': 'john', 'password': 'secret'});
        expect(body, isA<FormBody>());
        expect((body as FormBody).fields, {
          'username': 'john',
          'password': 'secret',
        });
      });

      test('should have correct content type', () {
        const body = HttpBody.form({'key': 'value'});
        expect(
          (body as FormBody).contentType,
          startsWith('application/x-www-form-urlencoded'),
        );
      });
    });

    group('MultipartBody', () {
      test('should create with parts', () {
        const body = HttpBody.multipart(
          parts: [
            HttpPart.field(name: 'name', value: 'John'),
          ],
        );
        expect(body, isA<MultipartBody>());
        expect((body as MultipartBody).parts.length, 1);
      });

      test('should support file parts', () {
        final body = HttpBody.multipart(
          parts: [
            const HttpPart.field(name: 'name', value: 'file'),
            HttpPart.file(
              name: 'file',
              filename: 'test.txt',
              stream: Stream.value([1, 2, 3]),
            ),
          ],
        );
        expect((body as MultipartBody).parts.length, 2);
      });

      test('should support bytes parts', () {
        final body = HttpBody.multipart(
          parts: [
            HttpPart.bytes(
              name: 'file',
              filename: 'test.bin',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        );
        final part = (body as MultipartBody).parts.first;
        expect(part, isA<BytesPart>());
      });
    });

    group('BinaryBody', () {
      test('should create with bytes', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final body = HttpBody.binary(bytes);
        expect(body, isA<BinaryBody>());
        expect((body as BinaryBody).bytes, bytes);
      });

      test('should support custom content type', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final body = HttpBody.binary(bytes, contentType: 'image/png');
        expect((body as BinaryBody).contentType, 'image/png');
      });
    });

    group('StreamBody', () {
      test('should create with stream', () {
        final stream = Stream.value([1, 2, 3]);
        final body = HttpBody.stream(stream);
        expect(body, isA<StreamBody>());
      });

      test('should support content length', () {
        final stream = Stream.value([1, 2, 3]);
        final body = HttpBody.stream(stream, contentLength: 100);
        expect((body as StreamBody).contentLength, 100);
      });

      test('should support custom content type', () {
        final stream = Stream.value([1, 2, 3]);
        final body = HttpBody.stream(
          stream,
          contentType: 'application/octet-stream',
        );
        expect((body as StreamBody).contentType, 'application/octet-stream');
      });
    });

    group('TextBody', () {
      test('should create with text', () {
        const body = HttpBody.text('Hello, World!');
        expect(body, isA<TextBody>());
        expect((body as TextBody).text, 'Hello, World!');
      });

      test('should support custom content type', () {
        const body = HttpBody.text('<html></html>', contentType: 'text/html');
        expect((body as TextBody).contentType, 'text/html');
      });
    });

    group('EmptyBody', () {
      test('should create empty body', () {
        const body = HttpBody.empty();
        expect(body, isA<EmptyBody>());
      });
    });

    group('LazyBody', () {
      test('should create with encoder function', () {
        final body = HttpBody.lazy(() => {'key': 'value'});
        expect(body, isA<LazyBody>());
      });

      test('should support async encoder', () {
        final body = HttpBody.lazy(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return {'key': 'value'};
        });
        expect(body, isA<LazyBody>());
      });
    });
  });

  group('HttpPart', () {
    group('FieldPart', () {
      test('should create field part', () {
        const part = HttpPart.field(name: 'username', value: 'john');
        expect(part, isA<FieldPart>());
        expect((part as FieldPart).name, 'username');
        expect(part.value, 'john');
      });
    });

    group('FilePart', () {
      test('should create file part', () {
        final stream = Stream.value([1, 2, 3]);
        final part = HttpPart.file(
          name: 'document',
          filename: 'file.pdf',
          stream: stream,
          length: 3,
          contentType: 'application/pdf',
        );

        expect(part, isA<FilePart>());
        expect((part as FilePart).name, 'document');
        expect(part.filename, 'file.pdf');
        expect(part.length, 3);
        expect(part.contentType, 'application/pdf');
      });
    });

    group('BytesPart', () {
      test('should create bytes part', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final part = HttpPart.bytes(
          name: 'file',
          filename: 'data.bin',
          bytes: bytes,
          contentType: 'application/octet-stream',
        );

        expect(part, isA<BytesPart>());
        expect((part as BytesPart).name, 'file');
        expect(part.filename, 'data.bin');
        expect(part.bytes, bytes);
        expect(part.contentType, 'application/octet-stream');
      });
    });
  });
}
