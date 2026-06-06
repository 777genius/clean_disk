import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:test/test.dart';

void main() {
  group('MediaUrlResolver', () {
    test('keeps absolute HTTP URLs unchanged', () {
      final resolver = MediaUrlResolver(
        baseUri: Uri.parse('https://cdn.example.test/storage'),
      );

      expect(
        resolver.resolveString('https://static.example.test/a.png'),
        'https://static.example.test/a.png',
      );
    });

    test(
      'resolves root-relative media paths against the configured origin',
      () {
        final resolver = MediaUrlResolver(
          baseUri: Uri.parse('https://cdn.example.test/storage'),
        );

        expect(
          resolver.resolveString('/storage/categories/hair.png'),
          'https://cdn.example.test/storage/categories/hair.png',
        );
      },
    );

    test('resolves relative media paths against storage directory base', () {
      final resolver = MediaUrlResolver(
        baseUri: Uri.parse('https://cdn.example.test/storage'),
      );

      expect(
        resolver.resolveString('categories/hair.png'),
        'https://cdn.example.test/storage/categories/hair.png',
      );
    });

    test('identity resolver preserves backend values without a base URL', () {
      const resolver = MediaUrlResolver.identity();

      expect(
        resolver.resolveString('/storage/categories/hair.png'),
        '/storage/categories/hair.png',
      );
    });

    test('drops unsupported URI schemes', () {
      final resolver = MediaUrlResolver(
        baseUri: Uri.parse('https://cdn.example.test'),
      );

      expect(resolver.resolveString('file:///tmp/image.png'), isNull);
    });
  });
}
