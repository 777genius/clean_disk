import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppEnvironment', () {
    test('parses supported flavors', () {
      expect(AppEnvironment.parseFlavor('dev'), AppFlavor.development);
      expect(AppEnvironment.parseFlavor('staging'), AppFlavor.staging);
      expect(AppEnvironment.parseFlavor('prod'), AppFlavor.production);
    });

    test('rejects unsupported flavor', () {
      expect(
        () => AppEnvironment.parseFlavor('qa'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses http and https API base URLs', () {
      expect(
        AppEnvironment.parseApiBaseUri('https://api.example.test'),
        Uri.parse('https://api.example.test'),
      );
      expect(
        AppEnvironment.parseApiBaseUri('http://127.0.0.1:8080'),
        Uri.parse('http://127.0.0.1:8080'),
      );
    });

    test('normalizes backend PUBLIC_API_URL with terminal api path', () {
      expect(
        AppEnvironment.parseApiBaseUri('https://api.example.test/api'),
        Uri.parse('https://api.example.test'),
      );
      expect(
        AppEnvironment.parseApiBaseUri('https://api.example.test/api/'),
        Uri.parse('https://api.example.test'),
      );
    });

    test('keeps non-api base paths when explicitly configured', () {
      expect(
        AppEnvironment.parseApiBaseUri('https://api.example.test/gateway'),
        Uri.parse('https://api.example.test/gateway'),
      );
    });

    test('rejects malformed API base URLs', () {
      expect(
        () => AppEnvironment.parseApiBaseUri('api.example.test'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppEnvironment.parseApiBaseUri('ftp://api.example.test'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses optional storage base URL', () {
      expect(
        AppEnvironment.parseOptionalBaseUri(
          'https://cdn.example.test/storage?token=secret#fragment',
          fieldName: 'storage base URL',
        ),
        Uri.parse('https://cdn.example.test/storage'),
      );
      expect(
        AppEnvironment.parseOptionalBaseUri('', fieldName: 'storage base URL'),
        isNull,
      );
    });

    test('rejects malformed storage base URL', () {
      expect(
        () => AppEnvironment.parseOptionalBaseUri(
          'cdn.example.test/storage',
          fieldName: 'storage base URL',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppEnvironment.parseOptionalBaseUri(
          'ftp://cdn.example.test',
          fieldName: 'storage base URL',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('builds environment from raw values', () {
      final environment = AppEnvironment.fromValues(
        flavor: 'production',
        apiBaseUrl: 'https://api.example.test',
        storageBaseUrl: 'https://cdn.example.test/storage',
      );

      expect(environment.flavor, AppFlavor.production);
      expect(environment.apiBaseUri, Uri.parse('https://api.example.test'));
      expect(
        environment.storageBaseUri,
        Uri.parse('https://cdn.example.test/storage'),
      );
      expect(
        environment.mediaUrlResolver.resolveString('/storage/avatar.png'),
        'https://cdn.example.test/storage/avatar.png',
      );
      expect(environment.isProduction, isTrue);
      expect(environment.isDevelopment, isFalse);
    });
  });
}
