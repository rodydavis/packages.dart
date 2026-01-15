import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';
import 'package:pocketbase_sync/sync_managers/drift.dart';

// part 'drift_sync_repository_test.g.dart';

// Test Model
class Note {
  final String id;
  final String content;
  Note({required this.id, required this.content});

  Map<String, dynamic> toJson() => {'id': id, 'content': content};
  static Note fromJson(Map<String, dynamic> json) =>
      Note(id: json['id'], content: json['content']);

  @override
  bool operator ==(Object other) =>
      other is Note && other.id == id && other.content == content;

  @override
  int get hashCode => Object.hash(id, content);
}

void main() {
  late PackageDatabase database;
  late DriftSyncRepository<Note> repository;

  setUp(() {
    // In-memory database for testing
    database = PackageDatabase(NativeDatabase.memory());
    repository = DriftSyncRepository<Note>(
      dbWrapper: database,
      collectionName: 'notes',
      toJson: (n) => n.toJson(),
      fromJson: (j) => Note.fromJson(j),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Save and Get', () async {
    final note = Note(id: '1', content: 'Test');
    final record = SyncRecord(id: '1', data: note, isDirty: true);

    await repository.save(record);
    final fetched = await repository.get('1');

    expect(fetched, isNotNull);
    expect(fetched!.data, equals(note));
    expect(fetched.isDirty, isTrue);
  });

  test('Update updates existing record', () async {
    final note1 = Note(id: '1', content: 'Test 1');
    await repository.save(SyncRecord(id: '1', data: note1));

    final note2 = Note(id: '1', content: 'Test 2');
    await repository.save(SyncRecord(id: '1', data: note2, isDirty: true));

    final fetched = await repository.get('1');
    expect(fetched!.data.content, equals('Test 2'));
    expect(fetched.isDirty, isTrue);
  });

  test('GetAll returns filtered by collection', () async {
    // Add note to correct collection
    await repository.save(
      SyncRecord(
        id: '1',
        data: Note(id: '1', content: 'A'),
      ),
    );

    // Add note to OTHER collection (using a different repo instance)
    final otherRepo = DriftSyncRepository<Note>(
      dbWrapper: database,
      collectionName: 'other_notes',
      toJson: (n) => n.toJson(),
      fromJson: (j) => Note.fromJson(j),
    );
    await otherRepo.save(
      SyncRecord(
        id: '2',
        data: Note(id: '2', content: 'B'),
      ),
    );

    final all = await repository.getAll();
    expect(all.length, equals(1));
    expect(all.first.id, equals('1'));
  });

  test('LastSyncTime persistence', () async {
    final time = DateTime.now();
    await repository.setLastSyncTime(time);

    final fetched = await repository.getLastSyncTime();
    // Precision might be lost in DB, check difference
    expect(
      fetched.difference(time).inMilliseconds.abs(),
      lessThan(1000),
    ); // allow small diff
  });

  test('Delete removes record', () async {
    await repository.save(
      SyncRecord(
        id: '1',
        data: Note(id: '1', content: 'A'),
      ),
    );
    await repository.delete('1');

    expect(await repository.get('1'), isNull);
  });
}
