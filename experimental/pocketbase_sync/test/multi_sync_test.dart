import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';

// Generate Mocks
@GenerateNiceMocks([MockSpec<PocketBaseSyncManager>()])
import 'multi_sync_test.mocks.dart';

// Test Models
class ModelA {}

class ModelB {}

void main() {
  late PocketBaseMultiSyncManager multiManager;
  late MockPocketBaseSyncManager<ModelA> mockManagerA;
  late MockPocketBaseSyncManager<ModelB> mockManagerB;

  setUp(() {
    multiManager = PocketBaseMultiSyncManager();
    mockManagerA = MockPocketBaseSyncManager<ModelA>();
    mockManagerB = MockPocketBaseSyncManager<ModelB>();
  });

  test('Register and Retrieve Manager', () {
    multiManager.register<ModelA>(mockManagerA);

    expect(multiManager.managerFor<ModelA>(), equals(mockManagerA));
    expect(() => multiManager.managerFor<ModelB>(), throwsStateError);
  });

  test('SyncAll calls sync on all managers', () async {
    multiManager.register<ModelA>(mockManagerA);
    multiManager.register<ModelB>(mockManagerB);

    await multiManager.sync();

    verify(mockManagerA.sync()).called(1);
    verify(mockManagerB.sync()).called(1);
  });

  test('SyncAll continues even if one manager fails', () async {
    multiManager.register<ModelA>(mockManagerA);
    multiManager.register<ModelB>(mockManagerB);

    when(mockManagerA.sync()).thenThrow(Exception('Sync Failed'));

    await multiManager.sync();

    verify(mockManagerA.sync()).called(1);
    verify(mockManagerB.sync()).called(1); // Should still execute
  });
}
