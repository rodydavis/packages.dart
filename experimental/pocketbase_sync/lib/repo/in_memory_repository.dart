import 'sync_repository.dart';

/// Default In-Memory Implementation (Good for testing/prototyping)
class InMemoryRepository<T> implements SyncRepository<T> {
  final Map<String, SyncRecord<T>> _db = {};
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<List<SyncRecord<T>>> getAll() async => _db.values.toList();
  @override
  Future<SyncRecord<T>?> get(String id) async => _db[id];
  @override
  Future<void> save(SyncRecord<T> record) async => _db[record.id] = record;
  @override
  Future<void> delete(String id) async => _db.remove(id);
  @override
  Future<DateTime> getLastSyncTime() async => _lastSync;
  @override
  Future<void> setLastSyncTime(DateTime time) async => _lastSync = time;
}
