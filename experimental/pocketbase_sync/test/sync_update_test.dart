import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';
import 'package:pocketbase_sync/repo/in_memory_repository.dart';

import 'pb_sync_manager_test.mocks.dart';

// Test Model
class Note {
  final String id;
  final String content;
  final String category;
  Note({required this.id, required this.content, required this.category});

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'category': category,
      };
  static Note fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        content: json['content'],
        category: json['category'] ?? 'General',
      );
}

void main() {
  late MockPocketBase mockPb;
  late MockRecordService mockCollection;
  late InMemoryRepository<Note> repository;
  late PocketBaseSyncManager<Note> manager;

  setUp(() {
    mockPb = MockPocketBase();
    mockCollection = MockRecordService();
    repository = InMemoryRepository<Note>();

    when(mockPb.collection('notes')).thenReturn(mockCollection);

    manager = PocketBaseSyncManager<Note>(
      pb: mockPb,
      collection: 'notes',
      toJson: (n) => n.toJson(),
      fromJson: (j) => Note.fromJson(j),
      repository: repository,
      retentionPeriod: const Duration(days: 30),
    );
  });

  test('Reproduction: Server update should reflect locally after sync',
      () async {
    // 1. Setup Initial State (Already Synced)
    final initialTime = DateTime.parse('2023-01-01 10:00:00Z');
    final note = Note(id: 'n1', content: 'Initial Content', category: 'Work');

    await repository.save(
      SyncRecord(
        id: 'n1',
        data: note,
        baseData: note,
        serverUpdatedAt: initialTime,
        isDirty: false,
      ),
    );

    // Simulate we have synced up to this time
    await repository.setLastSyncTime(initialTime);

    // 2. Mock Server having a newer version
    final updatedTime = initialTime.add(const Duration(minutes: 5));
    final updatedNoteJson = {
      'id': 'n1',
      'content': 'Updated Content', // Changed content
      'category': 'Work',
      'updated': updatedTime.toIso8601String(),
    };

    // Expect the sync manager to ask for records updated after the last sync time
    // capture the filter to verify what is being sent
    when(mockCollection.getFullList(filter: anyNamed('filter')))
        .thenAnswer((invocation) async {
      final filter =
          invocation.namedArguments[const Symbol('filter')] as String?;
      print('Filter used: $filter'); // Debug print

      // precise verification of the filter format
      if (filter != null) {
        if (filter.contains('T')) {
          throw TestFailure('Filter should not contain T separator: $filter');
        }
        if (!filter.contains('>=')) {
          throw TestFailure('Filter should use >= operator: $filter');
        }
      }

      // Return the updated record simulating server response
      return [RecordModel.fromJson(updatedNoteJson)];
    });

    // Mock ID List for Reconciliation (Server still has the item)
    when(mockCollection.getFullList(fields: 'id')).thenAnswer((_) async => [
          RecordModel.fromJson({'id': 'n1'})
        ]);

    // 3. Run Sync
    await manager.sync();

    // 4. Verify Local Update
    final localRecord = await repository.get('n1');
    expect(localRecord, isNotNull);
    expect(localRecord!.data.content, equals('Updated Content'),
        reason: "Local content should match server content after sync");
    expect(localRecord.serverUpdatedAt, equals(updatedTime));
  });

  test('Reproduction: Conflict (Server Wins on same field)', () async {
    // 1. Setup Initial State
    final initialTime = DateTime.parse('2023-01-01 10:00:00Z');
    final baseNote = Note(id: 'n1', content: 'Base', category: 'Work');

    // 2. Local Edit (Dirty) - Content: "Local Edit"
    final localNote = Note(id: 'n1', content: 'Local Edit', category: 'Work');
    await repository.save(
      SyncRecord(
        id: 'n1',
        data: localNote,
        baseData: baseNote,
        serverUpdatedAt: initialTime,
        isDirty: true,
      ),
    );
    await repository.setLastSyncTime(initialTime);

    // 3. Server Edit - Content: "Server Edit"
    final updatedTime = initialTime.add(const Duration(minutes: 5));
    final remoteNoteJson = {
      'id': 'n1',
      'content': 'Server Edit',
      'category': 'Work',
      'updated': updatedTime.toIso8601String(),
    };

    when(mockCollection.getFullList(filter: anyNamed('filter')))
        .thenAnswer((_) async => [RecordModel.fromJson(remoteNoteJson)]);

    // Mock ID List (Item exists)
    when(mockCollection.getFullList(fields: 'id')).thenAnswer((_) async => [
          RecordModel.fromJson({'id': 'n1'})
        ]);

    // 4. Sync
    await manager.sync();

    // 5. Verify Conflict Resolution
    final localRecord = await repository.get('n1');
    expect(localRecord!.data.content, equals('Server Edit'),
        reason: "Server edit should win on collision");
    expect(localRecord.isDirty, isTrue,
        reason: "Merged record should remain dirty to push back merged state");
    expect(localRecord.serverUpdatedAt, equals(updatedTime));
  });

  test(
      'Reproduction: Remote Deletion (Item missing on server should delete local)',
      () async {
    // 1. Setup Initial State (Synced)
    final initialTime = DateTime.parse('2023-01-01 10:00:00Z');
    final note = Note(id: 'n1', content: 'To Be Deleted', category: 'Work');

    await repository.save(
      SyncRecord(
        id: 'n1',
        data: note,
        baseData: note,
        serverUpdatedAt: initialTime,
        isDirty: false,
      ),
    );
    await repository.setLastSyncTime(initialTime);

    // 2. Mock Server State
    // Incremental Pull: Returns nothing (no updates)
    when(mockCollection.getFullList(filter: anyNamed('filter')))
        .thenAnswer((_) async => []);

    // Full ID List Pull (Reconciliation): Returns empty list (Item n1 is GONE)
    when(mockCollection.getFullList(fields: 'id')).thenAnswer((_) async => []);

    // 3. Sync
    await manager.sync();

    // 4. Verify Local Deletion
    final localRecord = await repository.get('n1');
    expect(localRecord, isNull,
        reason:
            "Record should be deleted locally because it is missing on server");
  });
}
