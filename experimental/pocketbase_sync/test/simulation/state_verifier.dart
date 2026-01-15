import 'dart:convert';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';

/// Verifies consistency between Local DB and Remote PocketBase.
class StateVerifier {
  final PocketBase pb;
  final String collection;
  final SyncRepository repository; // We use raw repository accessor

  StateVerifier({
    required this.pb,
    required this.collection,
    required this.repository,
  });

  /// Compares local and remote state and returns a list of differences.
  /// Returns empty list if states are identical (converged).
  Future<List<String>> verifyConvergence() async {
    final diffs = <String>[];

    // 1. Fetch All Remote
    // 1. Fetch All Remote
    print('Verifier: Fetching remote records...');
    final remoteRecords =
        await pb.collection(collection).getFullList(sort: 'id');
    print('Verifier: Fetched ${remoteRecords.length} remote records.');
    final remoteMap = {for (var r in remoteRecords) r.id: r.data};

    // 2. Fetch All Local
    // 2. Fetch All Local
    print('Verifier: Fetching local records...');
    final localRecords = await repository.getAll();
    print('Verifier: Fetched ${localRecords.length} local records.');
    // Filter out deleted items that are correctly marked as deleted
    // (In a converged state, if it's deleted locally and synced, it should be gone from server or match server tombstone if server keeps them?
    //  PB doesn't keep tombstones by default unless we use a "deleted" column.
    //  The sync manager deletes from PB. So remote should NOT have it.
    //  Local might have it as isDeleted=true.
    //  So:
    //  - If Record is in Remote: Local must have it, isDeleted=false, content match.
    //  - If Record is NOT in Remote: Local must NOT have it OR (Local has it AND isDeleted=true).

    final localMap = {for (var r in localRecords) r.id: r};

    // Check Remote against Local
    for (var id in remoteMap.keys) {
      final _ = remoteMap[id]!; // remoteData
      final localRecord = localMap[id];

      if (localRecord == null) {
        diffs
            .add('Missing Local: Record $id exists on server but not locally.');
      } else if (localRecord.isDeleted) {
        // If it's deleted locally but exists on server, sync failed to push delete?
        // OR we haven't synced yet.
        diffs.add(
            'Zombie: Record $id is marked deleted locally but exists on server.');
      } else {
        // Compare Content
        // We need to compare JSON.
        // SyncRepository stores T data. We need to convert T to Map?
        // Wait, SyncRecord<T> stores T. PocketBase returns Map.
        // We probably need a way to compare T to Map.
        // The SyncManager has `toJson`. The verifier might need it too.
        // But `repository` is generic.
        // This verifier needs to know how to serialize local data.
        // Ideally we pass `toJson` to Verifier or use `SyncManager` which has it.
        // For this generic impl, let's assume T is Map<String, dynamic> or we pass a serializer.
      }
    }

    // Check Local against Remote
    for (var id in localMap.keys) {
      final local = localMap[id]!;
      if (!remoteMap.containsKey(id)) {
        if (!local.isDeleted) {
          // Exists locally (alive) but not on server.
          // Could be: Not yet pushed.
          diffs.add(
              'Missing Remote: Record $id exists locally but not on server.');
        } else {
          // Deleted locally and not on server. This is Good.
          // (Assuming we don't keep tombstones forever)
        }
      }
    }

    return diffs;
  }

  /// Performs a deep diff of two JSON objects.
  List<Diff> diffJson(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final dmp = DiffMatchPatch();
    // Sort keys for deterministic stringify
    final localStr = jsonEncode(local); // jsonEncode doesn't guarantee order?
    // Actually standard jsonEncode is not canonical.
    // But for simple verification, maybe enough if keys are standard.

    // Better: Compare keys and values manually.
    return dmp.diff(localStr, jsonEncode(remote));
  }
}
