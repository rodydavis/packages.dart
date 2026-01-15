import 'dart:convert';
import 'package:drift/drift.dart';
import '../sync_repository.dart';
import 'schema.dart'; // Will export schema.g.dart artifacts via internal generation users

/// A Drift (SQLite) implementation of SyncRepository.
/// Requires a [SyncDatabase] interface which exposes the underlying tables.
class DriftSyncRepository<T> implements SyncRepository<T> {
  final SyncDatabase dbWrapper;
  final String collectionName;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  DriftSyncRepository({
    required this.dbWrapper,
    required this.collectionName,
    required this.toJson,
    required this.fromJson,
  });

  GeneratedDatabase get db => dbWrapper.db;

  @override
  Future<List<SyncRecord<T>>> getAll() async {
    // Explicitly type the select to ensure 't' is 'SyncEntries'
    final query = db.select<SyncEntries, SyncEntry>(dbWrapper.syncEntries)
      ..where((t) => t.collection.equals(collectionName));

    final rows = await query.get();

    return rows.map((row) {
      return SyncRecord<T>(
        id: row.id,
        data: fromJson(jsonDecode(row.data)),
        baseData:
            row.baseData != null ? fromJson(jsonDecode(row.baseData!)) : null,
        serverUpdatedAt: row.serverUpdatedAt,
        isDirty: row.isDirty,
        isDeleted: row.isDeleted,
        deletedAt: row.deletedAt,
      );
    }).toList();
  }

  @override
  Future<SyncRecord<T>?> get(String id) async {
    final query = db.select<SyncEntries, SyncEntry>(dbWrapper.syncEntries)
      ..where((t) => t.collection.equals(collectionName) & t.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return SyncRecord<T>(
      id: row.id,
      data: fromJson(jsonDecode(row.data)),
      baseData:
          row.baseData != null ? fromJson(jsonDecode(row.baseData!)) : null,
      serverUpdatedAt: row.serverUpdatedAt,
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
    );
  }

  @override
  Future<void> save(SyncRecord<T> record) async {
    // Note: SyncEntriesCompanion is generated in schema.g.dart
    await db.into(dbWrapper.syncEntries).insertOnConflictUpdate(
          SyncEntriesCompanion(
            collection: Value(collectionName),
            id: Value(record.id),
            data: Value(jsonEncode(toJson(record.data))),
            baseData: Value(
              record.baseData != null
                  ? jsonEncode(toJson(record.baseData as T))
                  : null,
            ),
            serverUpdatedAt: Value(record.serverUpdatedAt),
            isDirty: Value(record.isDirty),
            isDeleted: Value(record.isDeleted),
            deletedAt: Value(record.deletedAt),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (db.delete<SyncEntries, SyncEntry>(dbWrapper.syncEntries)
          ..where((t) => t.collection.equals(collectionName) & t.id.equals(id)))
        .go();
  }

  @override
  Future<DateTime> getLastSyncTime() async {
    final query = db.select<SyncMeta, SyncMetaData>(dbWrapper.syncMeta)
      ..where((t) => t.collection.equals(collectionName));

    final row = await query.getSingleOrNull();
    return row?.lastSync ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    await db.into(dbWrapper.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion(
            collection: Value(collectionName),
            lastSync: Value(time),
          ),
        );
  }
}
