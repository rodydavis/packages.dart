import 'dart:math';
import 'package:logging/logging.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';
import 'package:pocketbase/pocketbase.dart' as client;
import 'package:drift/native.dart';
import 'package:pocketbase_sync/sync_managers/drift.dart';

import 'simulation/simulation_harness.dart';
import 'simulation/simulation_actions.dart';
import 'simulation/pocketbase_controller.dart';
import 'simulation/state_verifier.dart';

// --- Test Context ---
class TestContext {
  final PocketBaseSyncManager<Map<String, dynamic>> manager;
  final SimulationHarness harness;
  final DriftSyncRepository<Map<String, dynamic>> repository;

  TestContext({
    required this.manager,
    required this.harness,
    required this.repository,
  });
}

// --- Generator Logic (Simplified Glados) ---
// Since Glados integration might require code generation or specific test runner setup,
// we will implement a lightweight generator here for immediate execution.
// This allows us to run "flutter test" directly without extra steps.

// Helper to generate valid 15-char IDs
String generateValidId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rnd = Random();
  return List.generate(15, (index) => chars[rnd.nextInt(chars.length)]).join();
}

List<SimulationAction> generateScenario(int count) {
  final actions = <SimulationAction>[];
  final rnd = Random(42); // Fixed seed for reproducibility
  final activeIds = <String>[];

  // Helper inside to keep consistent
  String nextId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(15, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  for (var i = 0; i < count; i++) {
    final type = rnd.nextDouble();
    if (type < 0.05) {
      // Toggle Network (5%)
      if (rnd.nextBool()) {
        actions.add(GoOfflineAction());
      } else {
        actions.add(GoOnlineAction());
      }
    } else if (type < 0.1) {
      // Latency (5%)
      if (rnd.nextBool()) {
        actions.add(AddLatencyAction());
      } else {
        actions.add(RemoveLatencyAction());
      }
    } else if (type < 0.15) {
      // Restart Server (5%)
      actions.add(RestartServerAction());
    } else if (type < 0.3) {
      // Sync (15%)
      actions.add(SyncAction());
    } else if (type < 0.5) {
      // Create (20%)
      final id = nextId();
      activeIds.add(id);

      actions.add(CreateAction(id, {
        'content': 'Content for $id',
        'priority': rnd.nextInt(100),
        'active': true,
      }));
    } else if (type < 0.7 && activeIds.isNotEmpty) {
      // Update (20%)
      final id = activeIds[rnd.nextInt(activeIds.length)];

      // Randomly update one or more fields
      final changes = <String, dynamic>{};
      final subType = rnd.nextDouble();

      if (subType < 0.4) {
        // Text Edit: Append or Replace
        // Simple append to test diffing
        changes['content'] =
            'Updated content for $id at ${i} [${rnd.nextInt(1000)}]';
      } else if (subType < 0.7) {
        // Number change
        changes['priority'] = rnd.nextInt(100);
      } else {
        // Bool change
        changes['active'] = rnd.nextBool();
      }

      actions.add(UpdateAction(id, changes));
    } else if (type < 0.9 && activeIds.isNotEmpty) {
      // Remote Update (Conflict) (20%)
      final id = activeIds[rnd.nextInt(activeIds.length)];
      actions.add(RemoteUpdateAction(id, {'content': 'Remote Conflict $i'}));
    } else if (activeIds.isNotEmpty) {
      // Delete (10%)
      final id = activeIds[rnd.nextInt(activeIds.length)];
      activeIds.remove(id);
      actions.add(DeleteAction(id));
    }
  }

  // Ensure we end online, clear faults, and sync to converge
  actions.add(RemoveLatencyAction());
  actions.add(GoOnlineAction());

  return actions;
}

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('STACK: ${record.stackTrace}');
    }
  });

  group('Simulation Tests', skip: true, () {
    late SimulationHarness harness;
    late PackageDatabase database;
    late DriftSyncRepository<Map<String, dynamic>> repository;
    late PocketBaseSyncManager<Map<String, dynamic>> manager;

    setUp(() async {
      harness = SimulationHarness(
        pocketbase: PocketBaseController(
          executablePath: './example/pocketbase',
          managed: true,
          dataDir: './example/pb_data',
        ),
        toxiproxyBinary: './toxiproxy-server',
      );
      await harness.setUp();

      // Setup Client
      final pb = client.PocketBase(harness.proxyUrl);

      // 1. Auth as Admin to create 'notes' collection if needed
      try {
        // Try new superuser auth
        try {
          await pb.collection('_superusers').authWithPassword(
              'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
        } catch (_) {
          // Fallback to old admin auth
          await pb.admins.authWithPassword(
              'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
        }

        // Proactively delete 'notes' to ensure fresh schema/rules
        try {
          await pb.collections.delete('notes');
        } catch (_) {}

        // Create 'notes' collection with public rules
        await pb.collections.create(body: {
          'name': 'notes',
          'type': 'base',
          'schema': [
            {
              'name': 'content',
              'type': 'text',
              'required': true, // Make content required as per original plan
            },
            {
              'name': 'priority',
              'type': 'number',
              'required': false,
            },
            {
              'name': 'active',
              'type': 'bool',
              'required': false,
            }
          ],
          'listRule': '@request.auth.id != ""',
          'viewRule': '@request.auth.id != ""',
          'createRule': '@request.auth.id != ""',
          'updateRule': '@request.auth.id != ""',
          'deleteRule': '@request.auth.id != ""',
        });
        print(
            'Created "notes" collection with expanded schema and public rules');

        // Clear admin auth
        pb.authStore.clear();
      } catch (e) {
        print('Admin setup failed (Notes collection might be missing): $e');
      }

      // 2. Create a random user for this test run to ensure isolation/valid auth

      final email = 'test_${Random().nextInt(10000)}@example.com';
      final password = 'password123456';

      try {
        await pb.collection('users').create(body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'username': 'user_${Random().nextInt(10000)}',
        });
        await pb.collection('users').authWithPassword(email, password);
        print('Authenticated as $email');
      } catch (e) {
        print('Failed to auth: $e');
        // If fail, we might proceed but sync will likely fail
      }

      database = PackageDatabase(NativeDatabase.memory());
      repository = DriftSyncRepository<Map<String, dynamic>>(
        dbWrapper: database,
        collectionName: 'notes',
        toJson: (m) => m,
        fromJson: (m) => m,
      );

      manager = PocketBaseSyncManager(
        pb: pb, // Point to Proxy
        collection: 'notes',
        repository: repository,
        toJson: (m) => m,
        fromJson: (m) => m,
      );
    });

    tearDown(() async {
      // Cleanup: Delete 'notes' collection (requires admin)
      try {
        // We need a fresh client or auth the existing one as admin
        final adminPb =
            client.PocketBase('http://127.0.0.1:${harness.pocketbase.port}');

        // Try new superuser auth first
        try {
          await adminPb.collection('_superusers').authWithPassword(
              'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
        } catch (_) {
          // Fallback
          await adminPb.admins.authWithPassword(
              'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
        }

        await adminPb.collections.delete('notes');
        print('Cleanup: Deleted "notes" collection');
      } catch (e) {
        print('Cleanup warning: Failed to delete "notes" collection: $e');
      }

      manager.dispose();
      await database.close();
      await harness.tearDown();
    });

    test('Chaos Scenario: Random actions lead to eventual consistency',
        () async {
      const seed = 12345;
      final actions = generateScenario(100);

      final context = TestContext(
        manager: manager,
        harness: harness,
        repository: repository,
      );

      print('Running scenario with seed $seed (${actions.length} actions)');

      for (var action in actions) {
        print('Executing: ${action.describe()}');
        await action.execute(context);
        // Add valid jitter between actions?
        // await Future.delayed(Duration(milliseconds: 10));
      }

      // Allow final sync to settle
      await Future.delayed(const Duration(seconds: 2));

      // Verify
      final verifyPb = client.PocketBase(
          'http://127.0.0.1:${harness.pocketbase.port}'); // Bypass proxy for verification
      try {
        await verifyPb.collection('_superusers').authWithPassword(
            'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
      } catch (_) {
        await verifyPb.admins.authWithPassword(
            'rody.davis.jr@gmail.com', 'razroq-hedne5-cafdaT');
      }

      final verifier = StateVerifier(
        pb: verifyPb,
        collection: 'notes',
        repository: repository,
      );

      final diffs = await verifier.verifyConvergence();
      if (diffs.isNotEmpty) {
        fail('State diverged:\n${diffs.join('\n')}');
      } else {
        print('✓ State Converged!');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
