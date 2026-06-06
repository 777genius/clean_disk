import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('TokenPair', () {
    test('should create with required access token', () {
      const pair = TokenPair(accessToken: 'access123');

      expect(pair.accessToken, 'access123');
      expect(pair.refreshToken, isNull);
      expect(pair.accessTokenExpiresAt, isNull);
      expect(pair.refreshTokenExpiresAt, isNull);
    });

    test('should create with all parameters', () {
      final accessExpiry = DateTime.now().add(const Duration(hours: 1));
      final refreshExpiry = DateTime.now().add(const Duration(days: 7));

      final pair = TokenPair(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        accessTokenExpiresAt: accessExpiry,
        refreshTokenExpiresAt: refreshExpiry,
      );

      expect(pair.accessToken, 'access123');
      expect(pair.refreshToken, 'refresh456');
      expect(pair.accessTokenExpiresAt, accessExpiry);
      expect(pair.refreshTokenExpiresAt, refreshExpiry);
    });

    group('isAccessTokenExpired', () {
      test('should return false when no expiry set', () {
        const pair = TokenPair(accessToken: 'access123');
        expect(pair.isAccessTokenExpired, isFalse);
      });

      test('should return false when not expired', () {
        final pair = TokenPair(
          accessToken: 'access123',
          accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(pair.isAccessTokenExpired, isFalse);
      });

      test('should return true when expired', () {
        final pair = TokenPair(
          accessToken: 'access123',
          accessTokenExpiresAt: DateTime.now().subtract(
            const Duration(hours: 1),
          ),
        );
        expect(pair.isAccessTokenExpired, isTrue);
      });
    });

    group('isRefreshTokenExpired', () {
      test('should return false when no expiry set', () {
        const pair = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
        );
        expect(pair.isRefreshTokenExpired, isFalse);
      });

      test('should return false when not expired', () {
        final pair = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
          refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        expect(pair.isRefreshTokenExpired, isFalse);
      });

      test('should return true when expired', () {
        final pair = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
          refreshTokenExpiresAt: DateTime.now().subtract(
            const Duration(days: 1),
          ),
        );
        expect(pair.isRefreshTokenExpired, isTrue);
      });
    });

    group('copyWith', () {
      test('should create copy with changed values', () {
        const original = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
        );

        final copy = original.copyWith(
          accessToken: 'newAccess',
          refreshToken: 'newRefresh',
        );

        expect(copy.accessToken, 'newAccess');
        expect(copy.refreshToken, 'newRefresh');
      });

      test('should preserve unchanged values', () {
        final expiry = DateTime.now().add(const Duration(hours: 1));
        final original = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
          accessTokenExpiresAt: expiry,
        );

        final copy = original.copyWith(accessToken: 'newAccess');

        expect(copy.accessToken, 'newAccess');
        expect(copy.refreshToken, 'refresh456');
        expect(copy.accessTokenExpiresAt, expiry);
      });
    });

    group('fromJson', () {
      test('should parse JSON with all fields', () {
        final json = {
          'access_token': 'access123',
          'refresh_token': 'refresh456',
          'expires_in': 3600, // 1 hour
        };

        final pair = TokenPair.fromJson(json);

        expect(pair.accessToken, 'access123');
        expect(pair.refreshToken, 'refresh456');
        expect(pair.accessTokenExpiresAt, isNotNull);
      });

      test('should parse JSON with minimal fields', () {
        final json = {
          'access_token': 'access123',
        };

        final pair = TokenPair.fromJson(json);

        expect(pair.accessToken, 'access123');
        expect(pair.refreshToken, isNull);
      });

      test('should handle custom keys', () {
        final json = {
          'token': 'access123',
          'refresh': 'refresh456',
        };

        final pair = TokenPair.fromJson(
          json,
          accessTokenKey: 'token',
          refreshTokenKey: 'refresh',
        );

        expect(pair.accessToken, 'access123');
        expect(pair.refreshToken, 'refresh456');
      });
    });

    group('toJson', () {
      test('should convert to JSON', () {
        const pair = TokenPair(
          accessToken: 'access123',
          refreshToken: 'refresh456',
        );

        final json = pair.toJson();

        expect(json['access_token'], 'access123');
        expect(json['refresh_token'], 'refresh456');
      });

      test('should include token_type by default', () {
        const pair = TokenPair(
          accessToken: 'access123',
        );

        final json = pair.toJson();

        expect(json['access_token'], 'access123');
        expect(json['token_type'], 'Bearer');
      });
    });

    test('toString should include access token', () {
      const pair = TokenPair(accessToken: 'access123');
      final str = pair.toString();
      expect(str, contains('TokenPair'));
    });

    test('equality should be based on all fields', () {
      const a = TokenPair(accessToken: 'access123', refreshToken: 'refresh456');
      const b = TokenPair(accessToken: 'access123', refreshToken: 'refresh456');
      const c = TokenPair(accessToken: 'different', refreshToken: 'refresh456');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
