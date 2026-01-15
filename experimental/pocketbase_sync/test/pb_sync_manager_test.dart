import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';
import 'package:pocketbase_sync/sync_managers/in_memory.dart';

// Generate Mocks
@GenerateNiceMocks([MockSpec<PocketBase>(), MockSpec<RecordService>()])
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

  group('Sync Logic', () {
    test('Push Update: Sends minimal PATCH using HybridDiffer', () async {
      // 1. Setup Synced State
      final base = Note(id: 'n1', content: 'Base Content', category: 'Work');
      await repository.save(
        SyncRecord(
          id: 'n1',
          data: base,
          baseData: base,
          serverUpdatedAt: DateTime.parse('2023-01-01 10:00:00'),
          isDirty: false,
        ),
      );

      // 2. Local Update (Only change category)
      await manager.update(
        'n1',
        Note(id: 'n1', content: 'Base Content', category: 'Home'),
      );

      // 3. Mock Response
      when(mockCollection.update(any, body: anyNamed('body'))).thenAnswer(
        (_) async => RecordModel.fromJson(
            {'id': 'n1', 'updated': '2023-01-01 10:05:00'}),
      );

      // Mock ID List (Server has n1)
      when(mockCollection.getFullList(fields: 'id')).thenAnswer(
        (_) async => [
          RecordModel.fromJson({'id': 'n1'})
        ],
      );

      // 4. Sync
      await manager.sync();

      // 5. Verify Payload
      final captured = verify(
        mockCollection.update('n1', body: captureAnyNamed('body')),
      ).captured;
      final patch = captured.first as Map<String, dynamic>;

      expect(patch.containsKey('category'), isTrue);
      expect(
        patch.containsKey('content'),
        isFalse,
        reason: "Content didn't change",
      );
    });

    test('First Pull: Fetches ALL records (getFullList)', () async {
      // 1. Mock Server returning list
      final remoteItems = [
        RecordModel.fromJson({
          'id': 'n1',
          'updated': '2023-01-01 10:00:00',
          'content': 'A',
        }),
      ];

      when(
        mockCollection.getFullList(filter: anyNamed('filter')),
      ).thenAnswer((_) async => remoteItems);

      // Mock ID List (Server has n1)
      when(mockCollection.getFullList(fields: 'id')).thenAnswer(
        (_) async => [
          RecordModel.fromJson({'id': 'n1'})
        ],
      );

      // 2. Sync
      await manager.sync();

      // 3. Verify Repository Populated
      final all = await repository.getAll();
      expect(all.length, equals(1));
      expect(all.first.data.content, equals('A'));
    });
  });

  group('Retention Policy', () {
    test('Cleanup: Removes expired tombstones', () async {
      // Expired Tombstone
      await repository.save(
        SyncRecord(
          id: 'del',
          data: Note(id: 'del', content: '', category: ''),
          serverUpdatedAt: DateTime.now(),
          isDeleted: true,
          isDirty: false,
          deletedAt: DateTime.now().subtract(const Duration(days: 31)),
        ),
      );

      // Active Tombstone
      await repository.save(
        SyncRecord(
          id: 'active',
          data: Note(id: 'active', content: '', category: ''),
          serverUpdatedAt: DateTime.now(),
          isDeleted: true,
          isDirty: false,
          deletedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await manager.sync(); // Triggers cleanup at end

      expect(
        await repository.get('del'),
        isNull,
        reason: "Should be hard deleted",
      );
      expect(
        await repository.get('active'),
        isNotNull,
        reason: "Should be kept",
      );
    });
  });
}
