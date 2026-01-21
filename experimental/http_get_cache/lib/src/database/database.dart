import 'package:drift/drift.dart';
import 'settings.dart';

part 'database.g.dart';

@DriftDatabase(include: {
  "sql/http_cache.drift",
})
class HttpGetCacheDatabase extends _$HttpGetCacheDatabase {
  final DatabaseSettings settings;

  HttpGetCacheDatabase(this.settings, super.e);

  @override
  int get schemaVersion => 2;

  static HttpGetCacheDatabase? instance;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 1) {
          await m.createAll();
        }
        if (from < 2) {
          await m.addColumn(httpCache, httpCache.requestHeaders);
        }
      },
    );
  }
}
