import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryTokenStore', () {
    late InMemoryTokenStore store;

    setUp(() {
      store = InMemoryTokenStore();
    });

    test('getTokens should return null initially', () async {
      final tokens = await store.getTokens();
      expect(tokens, isNull);
    });

    test('saveTokens should store tokens', () async {
      const pair = TokenPair(
        accessToken: 'access123',
        refreshToken: 'refresh456',
      );

      await store.saveTokens(pair);
      final retrieved = await store.getTokens();

      expect(retrieved, equals(pair));
    });

    test('saveTokens should overwrite existing tokens', () async {
      const first = TokenPair(accessToken: 'first');
      const second = TokenPair(accessToken: 'second');

      await store.saveTokens(first);
      await store.saveTokens(second);

      final retrieved = await store.getTokens();
      expect(retrieved?.accessToken, 'second');
    });

    test('clearTokens should remove tokens', () async {
      const pair = TokenPair(accessToken: 'access123');

      await store.saveTokens(pair);
      await store.clearTokens();

      final retrieved = await store.getTokens();
      expect(retrieved, isNull);
    });

    group('tokenChanges stream', () {
      test('should emit when tokens are saved', () async {
        const pair = TokenPair(accessToken: 'access123');

        // ignore: unawaited_futures
        expectLater(
          store.tokenChanges,
          emits(pair),
        );

        await store.saveTokens(pair);
      });

      test('should emit null when tokens are cleared', () async {
        const pair = TokenPair(accessToken: 'access123');
        await store.saveTokens(pair);

        // ignore: unawaited_futures
        expectLater(
          store.tokenChanges,
          emits(isNull),
        );

        await store.clearTokens();
      });

      test('should emit multiple changes', () async {
        const first = TokenPair(accessToken: 'first');
        const second = TokenPair(accessToken: 'second');

        // ignore: unawaited_futures
        expectLater(
          store.tokenChanges.take(3).toList(),
          completion([first, second, null]),
        );

        await store.saveTokens(first);
        await store.saveTokens(second);
        await store.clearTokens();
      });

      test('should be broadcast stream', () async {
        const pair = TokenPair(accessToken: 'access123');

        // Multiple listeners should work
        final listener1 = store.tokenChanges.first;
        final listener2 = store.tokenChanges.first;

        await store.saveTokens(pair);

        expect(await listener1, equals(pair));
        expect(await listener2, equals(pair));
      });
    });

    test('dispose should close the stream', () async {
      await store.dispose();

      expect(
        store.tokenChanges.listen((_) {}).asFuture<void>(),
        completes,
      );
    });

    test('should work with initial tokens', () async {
      const initial = TokenPair(accessToken: 'initial');
      final storeWithInitial = InMemoryTokenStore(initial);

      final retrieved = await storeWithInitial.getTokens();
      expect(retrieved, equals(initial));
    });
  });
}
