import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CacheEntries extends Table {
  TextColumn get cacheKey => text().named('cache_key')();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get expiresAt => dateTime().named('expires_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DriftDatabase(tables: [CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'clean_disk_cache',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  Future<void> putCacheEntry({
    required String key,
    required String value,
    Duration? ttl,
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = ttl == null ? null : now.add(ttl);

    await into(cacheEntries).insertOnConflictUpdate(
      CacheEntriesCompanion.insert(
        cacheKey: key,
        value: value,
        updatedAt: now,
        expiresAt: Value(expiresAt),
      ),
    );
  }

  Future<String?> readCacheEntry(String key) async {
    final entry = await (select(
      cacheEntries,
    )..where((table) => table.cacheKey.equals(key))).getSingleOrNull();

    if (entry == null) {
      return null;
    }

    final expiresAt = entry.expiresAt;
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      await deleteCacheEntry(key);
      return null;
    }

    return entry.value;
  }

  Future<int> deleteCacheEntry(String key) {
    return (delete(
      cacheEntries,
    )..where((table) => table.cacheKey.equals(key))).go();
  }

  Future<int> deleteCacheEntriesWithPrefix(String prefix) {
    final escapedPrefix = _escapeLikePattern(prefix);

    return (delete(cacheEntries)..where(
          (table) => table.cacheKey.like('$escapedPrefix%', escapeChar: '\\'),
        ))
        .go();
  }

  String _escapeLikePattern(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
