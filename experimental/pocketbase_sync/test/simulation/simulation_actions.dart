/// Abstract Base Action
abstract class SimulationAction {
  Future<void> execute(dynamic context);
  String describe();
}

/// Creates a new item in the local sync manager
class CreateAction extends SimulationAction {
  final String id;
  final Map<String, dynamic> data;

  CreateAction(this.id, this.data);

  @override
  Future<void> execute(context) async {
    // context is TestContext { manager, logger }
    await context.manager.create(id, {'id': id, ...data});
  }

  @override
  String describe() => 'Create(id: $id, data: $data)';
}

/// Updates an item
class UpdateAction extends SimulationAction {
  final String id;
  final Map<String, dynamic> data;

  UpdateAction(this.id, this.data);

  @override
  Future<void> execute(context) async {
    // We pass the full record data to update() usually, or partial?
    // SyncManager.update(id, T item). It expects the full item T.
    // But our T is Map<String, dynamic>.
    // So if we pass partial, it might overwrite others with null if not careful.
    // BUT, our generator should probably provide full data or we merge here?
    // Let's assume the generator provides the fields intended to be updated.
    // Wait, if SyncManager replaces the record, we need the OLD data to merge.
    // The test context doesn't expose read access easily unless we use repository.
    // Let's assume the generator tracks the "current state" of the item to produce valid full updates?
    // OR: usage of update() in SyncManager:
    // "await repository.save(record.copyWith(data: item...))"
    // It REPLACES data. So we need to provide the merged state.

    // For simulation simplicity, we can fetch current from repo, merge, and save.
    final current = await context.repository.get(id);
    if (current != null) {
      final merged = Map<String, dynamic>.from(current.data);
      merged.addAll(data);
      await context.manager.update(id, merged);
    }
  }

  @override
  String describe() => 'Update(id: $id, changes: $data)';
}

/// Deletes an item
class DeleteAction extends SimulationAction {
  final String id;

  DeleteAction(this.id);

  @override
  Future<void> execute(context) async {
    await context.manager.delete(id);
  }

  @override
  String describe() => 'Delete(id: $id)';
}

/// Forces a Sync
class SyncAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    try {
      await context.manager.sync();
    } catch (e) {
      // Sync might fail if network is down
    }
  }

  @override
  String describe() => 'Sync()';
}

/// Goes Offline (Airplane Mode + Cable Cut)
class GoOfflineAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    await context.harness.goOffline();
  }

  @override
  String describe() => 'GoOffline()';
}

/// Goes Online
class GoOnlineAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    await context.harness.goOnline();
  }

  @override
  String describe() => 'GoOnline()';
}

/// Adds Latency to the connection
class AddLatencyAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    await context.harness.injectLatency();
  }

  @override
  String describe() => 'AddLatency(1000ms)';
}

/// Removes Latency (Clears Faults)
class RemoveLatencyAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    await context.harness.clearNetworkFaults();
  }

  @override
  String describe() => 'RemoveLatency()';
}

/// Restarts the PocketBase Server
class RestartServerAction extends SimulationAction {
  @override
  Future<void> execute(context) async {
    await context.harness.pocketbase.restart();
  }

  @override
  String describe() => 'RestartServer()';
}

/// Simulates a change happening on the server (Concurrent Modification)
class RemoteUpdateAction extends SimulationAction {
  final String id;
  final Map<String, dynamic> changes;

  RemoteUpdateAction(this.id, this.changes);

  @override
  Future<void> execute(context) async {
    // We use the manager's PB instance which is authenticated.
    // This simulates "User updated record on another device".
    // Bypassing the sync manager to touch the server directly.
    try {
      await context.manager.pb.collection('notes').update(id, body: changes);
    } catch (e) {
      // Ignore errors (e.g. record deleted on server already, or network down)
    }
  }

  @override
  String describe() => 'RemoteUpdate(id: $id, changes: "$changes")';
}
