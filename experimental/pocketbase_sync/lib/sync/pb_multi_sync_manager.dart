import 'dart:async';
import 'package:logging/logging.dart';
import 'pb_sync_manager.dart';
import '../core/sync_interface.dart';

class PocketBaseMultiSyncManager implements ISyncManager {
  final Map<Type, PocketBaseSyncManager> _managers = {};
  final _logger = Logger('PocketBaseMultiSyncManager');

  /// Registers a manager for a specific type [T].
  void register<T>(PocketBaseSyncManager<T> manager) {
    _managers[T] = manager;
  }

  /// Retrieves the manager for type [T].
  PocketBaseSyncManager<T> managerFor<T>() {
    final manager = _managers[T];
    if (manager == null) {
      throw StateError('No SyncManager registered for type $T');
    }
    return manager as PocketBaseSyncManager<T>;
  }

  @override
  Future<void> sync() async {
    _logger.info('Starting multi-sync for ${_managers.length} managers');
    // Run syncs sequentially to avoid overwhelming network/device resources.
    // Could be parallelized with Future.wait if needed.
    for (final manager in _managers.values) {
      try {
        await manager.sync();
      } catch (e, stack) {
        // Log error but continue syncing other collections
        _logger.severe(
            'Error syncing manager for type ${manager.runtimeType}', e, stack);
      }
    }
    _logger.info('Multi-sync completed');
  }
}
