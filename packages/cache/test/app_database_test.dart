import 'package:clean_disk_cache/clean_disk_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores, reads, and expires cache entries', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await database.putCacheEntry(key: 'scan.session.1', value: '{"id":"1"}');
    await database.putCacheEntry(
      key: 'expired',
      value: 'old',
      ttl: const Duration(milliseconds: -1),
    );

    expect(await database.readCacheEntry('scan.session.1'), '{"id":"1"}');
    expect(await database.readCacheEntry('expired'), isNull);
  });

  test('deletes cache entries by key prefix', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await database.putCacheEntry(key: 'scan.node.1', value: 'first');
    await database.putCacheEntry(key: 'scan.node.2', value: 'second');
    await database.putCacheEntry(key: 'scan.session.1', value: 'session');

    final deleted = await database.deleteCacheEntriesWithPrefix('scan.node.');

    expect(deleted, 2);
    expect(await database.readCacheEntry('scan.node.1'), isNull);
    expect(await database.readCacheEntry('scan.node.2'), isNull);
    expect(await database.readCacheEntry('scan.session.1'), 'session');
  });
}
