import 'dart:async';
import 'dart:math';
import 'package:diff_algorithims/hybrid_diff.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:pocketbase/pocketbase.dart';

import '../repo/sync_repository.dart';
import '../repo/in_memory_repository.dart';
import '../core/sync_interface.dart';

class PocketBaseSyncManager<T> implements ISyncManager {
  final PocketBase pb;
  final String collection;
  final SyncRepository<T> repository;
  final _logger = Logger('PocketBaseSyncManager');

  // Serialization Helpers
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  // Config
  final Duration retentionPeriod;
  final String Function() idGenerator;
  Timer? _autoSyncTimer;
  Duration? _autoSyncInterval;

  // Connection Status (Reactive)
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);
  bool get _isConnected => isConnectedNotifier.value;
  set _isConnected(bool value) => isConnectedNotifier.value = value;

  // Update Stream
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get onUpdate => _updateController.stream;

  PocketBaseSyncManager({
    required this.pb,
    required this.collection,
    required this.toJson,
    required this.fromJson,
    SyncRepository<T>? repository,
    this.retentionPeriod = const Duration(days: 30),
    String Function()? idGenerator,
    Duration? autoSyncInterval,
  })  : repository = repository ?? InMemoryRepository<T>(),
        idGenerator = idGenerator ?? _defaultIdGenerator,
        _autoSyncInterval = autoSyncInterval {
    if (autoSyncInterval != null) {
      startAutoSync(autoSyncInterval);
    }
  }

  static String _defaultIdGenerator() {
    return List.generate(
      15,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(36)],
    ).join();
  }

  String generateId() => idGenerator();

  Duration? get autoSyncInterval => _autoSyncInterval;

  set autoSyncInterval(Duration? value) {
    if (value == _autoSyncInterval) return;
    _autoSyncInterval = value;
    if (value != null) {
      startAutoSync(value);
    } else {
      stopAutoSync();
    }
  }

  void startAutoSync(Duration interval) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) {
      sync().catchError((e) {
        _logger.warning('Auto-sync failed', e);
      });
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  // ===========================================================================
  // --- 1. CRUD API (Local First) ---
  // ===========================================================================

  Future<void> create(String id, T item) async {
    await repository.save(
      SyncRecord(
        id: id,
        data: item,
        isDirty: true,
        // serverUpdatedAt null implies "New"
      ),
    );
    _updateController.add(null);
  }

  Future<void> update(String id, T item) async {
    final record = await repository.get(id);
    if (record == null) return;

    await repository.save(
      record.copyWith(
        data: item,
        isDirty: true,
        // Snapshot baseData ONLY if this is the first edit since sync
        baseData: record.baseData ?? record.data,
      ),
    );
    _updateController.add(null);
  }

  Future<void> delete(String id) async {
    final record = await repository.get(id);
    if (record == null) return;

    if (record.serverUpdatedAt == null) {
      // Never synced? Hard delete immediately.
      await repository.delete(id);
    } else {
      // Synced? Soft delete (Tombstone).
      await repository.save(
        record.copyWith(
          isDeleted: true,
          isDirty: true,
          deletedAt: DateTime.now(),
        ),
      );
    }
    _updateController.add(null);
  }

  // ===========================================================================
  // --- 2. SYNC LOGIC ---
  // ===========================================================================

  @override
  Future<void> sync() async {
    if (_isConnected) {
      _logger.info('Starting sync (Push Only) for collection: $collection');
    } else {
      _logger.info('Starting sync (Full) for collection: $collection');
    }

    try {
      await _pushChanges();

      // smart-poll: only pull if we are NOT connected to realtime
      if (!_isConnected) {
        await _pullChanges();
      } else {
        _logger.fine('Skipping pull (Realtime connected)');
      }

      await _performCleanup();
      _logger.info('Sync completed for collection: $collection');
    } catch (e, stack) {
      _logger.severe('Sync failed for collection: $collection', e, stack);
      rethrow;
    }
  }

  // ===========================================================================
  // --- 3. REALTIME SYNC ---
  // ===========================================================================

  bool _isSubscribed = false;

  Future<void> subscribe() async {
    _isSubscribed = true;
    _subscribeWithRetry(0);
  }

  Future<void> _subscribeWithRetry(int attempt) async {
    if (!_isSubscribed) return;

    try {
      _logger.info(
          'Subscribing to realtime updates for $collection (Attempt: $attempt)');
      await pb.collection(collection).subscribe('*', _handleRealtimeEvent);
      _isConnected = true;
      _logger.info('Successfully subscribed to $collection');

      // Catch up on anything we missed while disconnected
      await _pullChanges();
    } catch (e) {
      _isConnected = false;
      if (!_isSubscribed) return;

      _logger.warning('Realtime subscription failed for $collection', e);
      if (e is ClientException) {
        // from package:pocketbase
        _logger.warning(
            '  Status: ${e.statusCode}\n  Response: ${e.response}\n  Original: ${e.originalError}');
      }

      // Exponential Backoff: 1s, 2s, 4s, 8s, 16s, 30s (cap)
      final delaySeconds = min(30, pow(2, attempt).toInt());
      final delay = Duration(seconds: delaySeconds);

      _logger.info('Retrying subscription in ${delay.inSeconds}s...');
      await Future.delayed(delay);

      if (_isSubscribed) {
        // Recursive retry call
        _subscribeWithRetry(attempt + 1);
      }
    }
  }

  Future<void> unsubscribe() async {
    _isSubscribed = false;
    _isConnected = false;
    _logger.info('Unsubscribing from realtime updates for $collection');
    try {
      await pb.collection(collection).unsubscribe('*');
    } catch (_) {
      // Ignore unsubscribe errors
    }
  }

  Future<void> _pushChanges() async {
    final all = await repository.getAll();
    final dirty = all.where((r) => r.isDirty).toList();

    for (var record in dirty) {
      try {
        // --- A. DELETE ---
        if (record.isDeleted) {
          try {
            await pb.collection(collection).delete(record.id);
          } catch (e) {
            // Ignore 404 (already deleted)
          }
          await repository.save(record.copyWith(isDirty: false));
          continue;
        }

        // --- B. CREATE ---
        if (record.serverUpdatedAt == null) {
          final body = toJson(record.data);
          body['id'] = record.id;
          final result = await pb.collection(collection).create(body: body);

          await repository.save(
            record.copyWith(
              isDirty: false,
              serverUpdatedAt: DateTime.parse(result.getStringValue('updated')),
              baseData: null,
              // Update local ID if needed? No, ID is client-generated.
            ),
          );
          continue;
        }

        // --- C. UPDATE (PATCHING) ---
        final baseJson = record.baseData != null
            ? toJson(record.baseData as T)
            : <String, Object?>{};
        final currentJson = toJson(record.data);

        // Use HybridDiffer to send MINIMAL changes
        final diffs = HybridDiffer.diff(
          <Map<String, Object?>>[baseJson],
          <Map<String, Object?>>[currentJson],
          idField: 'id',
        );

        final Map<String, dynamic> patch = {};
        if (diffs.isNotEmpty && diffs.first.children != null) {
          for (var change in diffs.first.children!) {
            patch[change.key] = change.newValue;
          }
        }

        if (patch.isEmpty) {
          await repository.save(
            record.copyWith(isDirty: false, baseData: null),
          );
          continue;
        }

        try {
          final result =
              await pb.collection(collection).update(record.id, body: patch);
          await repository.save(
            record.copyWith(
              isDirty: false,
              serverUpdatedAt: DateTime.parse(result.getStringValue('updated')),
              baseData: null,
            ),
          );
        } catch (e, stack) {
          _logger.warning("Push conflict/error for ${record.id}", e, stack);
          // Leave dirty to force merge on next pull
        }
      } catch (e, stack) {
        _logger.warning("Sync Error for record ${record.id}", e, stack);
      }
    }
  }

  Future<void> _pullChanges() async {
    final lastSync = await repository.getLastSyncTime();
    _logger.info('Pulling changes since: ${lastSync.toIso8601String()}');

    // Pagination: getFullList ensures we get ALL pages on first pull (Epoch 0)
    // PocketBase uses space separator for dates, not T
    final isEpoch = lastSync.year <= 1970;
    final dateStr = lastSync.toUtc().toIso8601String().replaceFirst('T', ' ');
    final filter = isEpoch ? '' : "updated >= '$dateStr'";
    final items = await pb.collection(collection).getFullList(filter: filter);
    _logger.info('Fetched ${items.length} remote items using filter: $filter');

    for (var item in items) {
      final remoteJson = item.toJson();
      final remoteUpdated = DateTime.parse(item.getStringValue('updated'));
      final local = await repository.get(item.id);

      _logger
          .info('Processing remote item ${item.id} (Updated: $remoteUpdated)');

      if (local == null) {
        // New Item
        _logger.info('Creating new local item ${item.id}');
        await repository.save(
          SyncRecord(
            id: item.id,
            data: fromJson(remoteJson),
            serverUpdatedAt: remoteUpdated,
          ),
        );
      } else {
        if (local.isDirty) {
          // Conflict: We changed it, Server changed it.
          _logger.warning('Conflict detected for ${item.id}');
          await _resolveConflict(local, remoteJson, remoteUpdated);
        } else {
          // Fast Forward
          _logger.info('Fast-forwarding item ${item.id}');
          await repository.save(
            local.copyWith(
              data: fromJson(remoteJson),
              serverUpdatedAt: remoteUpdated,
            ),
          );
        }
      }
    }

    if (items.isNotEmpty) {
      final maxTime = items
          .map((e) => DateTime.parse(e.getStringValue('updated')))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      _logger.info('Updating last sync time to: $maxTime');
      await repository.setLastSyncTime(maxTime);
      _updateController.add(null);
    }

    // --- RECONCILIATION ---
    // Detect Remote Deletions
    _logger.info('Starting reconciliation for remote deletions...');
    try {
      // Fetch ALL IDs from server (lightweight)
      final allRemoteRecords =
          await pb.collection(collection).getFullList(fields: 'id');
      final remoteIds = allRemoteRecords.map((e) => e.id).toSet();
      _logger.info('Fetched ${remoteIds.length} active IDs from server');

      final allLocal = await repository.getAll();
      for (var local in allLocal) {
        // failed to sync or purely local -> skip
        if (local.serverUpdatedAt == null) continue;

        // If local thinks it exists (not deleted), but server doesn't have it -> Delete it
        if (!local.isDeleted && !remoteIds.contains(local.id)) {
          _logger.info(
              'Detected remote deletion for ${local.id}. Deleting locally.');
          await repository.delete(local.id);
        }
      }
    } catch (e, stack) {
      _logger.warning('Reconciliation failed', e, stack);
      // Non-fatal: just means we might not catch deletions this run
    }
  }

  Future<void> _handleRealtimeEvent(RecordSubscriptionEvent e) async {
    _logger.info('Realtime event received: ${e.action} for ${e.record?.id}');

    if (e.record == null) return;
    final id = e.record!.id;

    try {
      if (e.action == 'delete') {
        _logger.info("Realtime delete for $id");
        await repository.delete(id);
        _updateController.add(null);
      } else {
        // Create or Update
        final remoteJson = e.record!.toJson();
        final remoteUpdated =
            DateTime.parse(e.record!.getStringValue('updated'));
        final local = await repository.get(id);

        if (local == null) {
          _logger.info("Realtime create for $id");
          await repository.save(
            SyncRecord(
              id: id,
              data: fromJson(remoteJson),
              serverUpdatedAt: remoteUpdated,
            ),
          );
        } else {
          if (local.isDirty) {
            _logger.info("Realtime conflict check for $id");
            await _resolveConflict(local, remoteJson, remoteUpdated);
          } else {
            _logger.info("Realtime update for $id");
            await repository.save(
              local.copyWith(
                data: fromJson(remoteJson),
                serverUpdatedAt: remoteUpdated,
              ),
            );
          }
        }
        _updateController.add(null);
      }
    } catch (err, stack) {
      _logger.warning('Error handling realtime event for $id', err, stack);
    }
  }

  /// 3-Way Merge Strategy (Server Wins on Collision, Client Wins on Non-Collision)
  Future<void> _resolveConflict(
    SyncRecord<T> local,
    Map<String, dynamic> remoteJson,
    DateTime remoteUpdated,
  ) async {
    final baseJson = local.baseData != null
        ? toJson(local.baseData as T)
        : <String, dynamic>{};
    final localJson = toJson(local.data);

    final myChanges = HybridDiffer.diff(
      <Map<String, Object?>>[baseJson],
      <Map<String, Object?>>[localJson],
      idField: 'id',
    );
    final theirChanges = HybridDiffer.diff(
      <Map<String, Object?>>[baseJson],
      <Map<String, Object?>>[remoteJson],
      idField: 'id',
    );

    final mergedJson = Map<String, dynamic>.from(remoteJson);

    // Get keys modified by server
    Set<String> theirKeys = {};
    if (theirChanges.isNotEmpty && theirChanges.first.children != null) {
      theirKeys = theirChanges.first.children!.map((c) => c.key).toSet();
    }

    // Apply my changes if no collision
    if (myChanges.isNotEmpty && myChanges.first.children != null) {
      for (var change in myChanges.first.children!) {
        if (!theirKeys.contains(change.key)) {
          mergedJson[change.key] = change.newValue;
        }
      }
    }

    // Save Merged State (Keep Dirty so we push the merge back up)
    await repository.save(
      local.copyWith(
        data: fromJson(mergedJson),
        baseData: fromJson(remoteJson), // Rebase
        serverUpdatedAt: remoteUpdated,
        isDirty: true,
      ),
    );
  }

  Future<void> _performCleanup() async {
    final now = DateTime.now();
    final all = await repository.getAll();

    for (var record in all) {
      // Only delete if: Deleted + Synced + Expired
      if (record.isDeleted &&
          !record.isDirty &&
          record.deletedAt != null &&
          now.difference(record.deletedAt!) > retentionPeriod) {
        await repository.delete(record.id);
      }
    }
  }

  void dispose() {
    unsubscribe();
    stopAutoSync();
    _updateController.close();
    isConnectedNotifier.dispose();
  }
}
