import 'dart:async';

/// Wraps your data with sync metadata (Dirty flags, tombstones, versions)
class SyncRecord<T> {
  final String id;
  final T data;

  /// Server's timestamp. Null if created locally and never synced.
  final DateTime? serverUpdatedAt;

  /// Snapshot of data before local edits (Critical for 3-way merge).
  final T? baseData;

  /// True if local data differs from server data.
  final bool isDirty;

  /// True if marked for deletion (Soft Delete).
  final bool isDeleted;

  /// When the soft delete happened (For Retention Policy).
  final DateTime? deletedAt;

  SyncRecord({
    required this.id,
    required this.data,
    this.serverUpdatedAt,
    this.baseData,
    this.isDirty = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  SyncRecord<T> copyWith({
    T? data,
    DateTime? serverUpdatedAt,
    T? baseData,
    bool? isDirty,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return SyncRecord<T>(
      id: id,
      data: data ?? this.data,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      baseData: baseData ?? this.baseData,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

/// Abstract Storage Interface
abstract class SyncRepository<T> {
  Future<List<SyncRecord<T>>> getAll();
  Future<SyncRecord<T>?> get(String id);
  Future<void> save(SyncRecord<T> record);
  Future<void> delete(String id); // Hard Delete
  Future<DateTime> getLastSyncTime();
  Future<void> setLastSyncTime(DateTime time);
}
