import 'package:drift/drift.dart';

part 'schema.g.dart';

/// Stores the actual data records + sync metadata
/// We use a composite primary key of (collection, id) to store multiple collections in one table
class SyncEntries extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();

  /// serialized JSON of the current local data
  TextColumn get data => text()();

  /// serialized JSON of the base data (snapshot)
  TextColumn get baseData => text().nullable()();

  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {collection, id};
}

/// Stores global sync state per collection (e.g. last sync time)
class SyncMeta extends Table {
  TextColumn get collection => text()();
  DateTimeColumn get lastSync => dateTime().withDefault(
        Constant(DateTime.fromMillisecondsSinceEpoch(0)),
      )();

  @override
  Set<Column> get primaryKey => {collection};
}

/// Dummy database class to trigger generation of Companions and Data classes
/// which are used by DriftSyncRepository.
@DriftDatabase(tables: [SyncEntries, SyncMeta])
class PackageDatabase extends _$PackageDatabase implements SyncDatabase {
  PackageDatabase(super.e);
  @override
  int get schemaVersion => 1;

  @override
  GeneratedDatabase get db => this;
}

/// Interface that your AppDatabase must implement to be used with DriftSyncRepository.
/// This allows the repository to be agnostic of the specific generated database class.
abstract class SyncDatabase {
  GeneratedDatabase get db;
  TableInfo<SyncEntries, SyncEntry> get syncEntries;
  TableInfo<SyncMeta, SyncMetaData> get syncMeta;
}
