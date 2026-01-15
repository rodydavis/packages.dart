import 'package:diff_algorithims/hybrid_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HybridDiffer Structural Tests (Myers)', () {
    test('Identical lists return no changes', () {
      final list = [
        {'id': 1, 'val': 'a'},
        {'id': 2, 'val': 'b'},
      ];
      final changes = HybridDiffer.diff(list, list, idField: 'id');

      // We expect equal nodes or no nodes depending on filtering.
      // The implementation returns Equal nodes for matches.
      expect(changes.every((c) => c.op == ChangeOp.equal), isTrue);
      expect(changes.length, equals(2));
    });

    test('Detects simple insertion', () {
      final oldList = [
        {'id': 1, 'val': 'a'},
      ];
      final newList = [
        {'id': 1, 'val': 'a'},
        {'id': 2, 'val': 'b'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');

      expect(changes.length, equals(2));
      expect(changes[0].op, equals(ChangeOp.equal));
      expect(changes[1].op, equals(ChangeOp.insert));
      expect(changes[1].key, equals('2'));
    });

    test('Detects simple deletion', () {
      final oldList = [
        {'id': 1, 'val': 'a'},
        {'id': 2, 'val': 'b'},
      ];
      final newList = [
        {'id': 1, 'val': 'a'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');

      expect(changes.length, equals(2));
      expect(changes[0].op, equals(ChangeOp.equal));
      expect(changes[1].op, equals(ChangeOp.delete));
      expect(changes[1].key, equals('2'));
    });

    test('Detects moves (Delete + Insert)', () {
      // Myers detects moves as a delete of the old position and insert at new
      final oldList = [
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ];
      final newList = [
        {'id': 1},
        {'id': 3},
        {'id': 2},
      ]; // 2 moved to end

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');

      // Expected: Equal(1), Equal(3), Insert(2), Delete(2) OR Equal(1), Delete(2), Equal(3), Insert(2)
      // Myers usually prefers deletes first if weights are equal, but let's check operations.
      final ops = changes.map((c) => c.op).toList();

      expect(ops, contains(ChangeOp.insert));
      expect(ops, contains(ChangeOp.delete));

      final insertNode = changes.firstWhere((c) => c.op == ChangeOp.insert);
      final deleteNode = changes.firstWhere((c) => c.op == ChangeOp.delete);

      expect(insertNode.key, equals(deleteNode.key));
      expect(['2', '3'], contains(insertNode.key));
    });
  });

  group('HybridDiffer Content Tests (Deep Diff)', () {
    test('Detects modification in primitive fields', () {
      final oldList = [
        {'id': 1, 'name': 'Alice'},
      ];
      final newList = [
        {'id': 1, 'name': 'Bob'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');

      expect(changes.length, equals(1));
      final mod = changes.first;

      expect(mod.op, equals(ChangeOp.modify));
      expect(mod.children, isNotNull);
      expect(mod.children!.length, equals(1));

      final fieldChange = mod.children!.first;
      expect(fieldChange.key, equals('name'));
      expect(fieldChange.oldValue, equals('Alice'));
      expect(fieldChange.newValue, equals('Bob'));
    });

    test('Detects nested map changes recursively', () {
      final oldList = [
        {
          'id': 1,
          'meta': {'ver': 1, 'author': 'me'},
        },
      ];
      final newList = [
        {
          'id': 1,
          'meta': {'ver': 2, 'author': 'me'},
        },
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');
      final rootMod = changes.first;

      // Look inside the 'meta' field
      final metaMod = rootMod.children!.firstWhere((c) => c.key == 'meta');
      expect(metaMod.op, equals(ChangeOp.modify));

      // Look inside 'ver' field
      final verMod = metaMod.children!.firstWhere((c) => c.key == 'ver');
      expect(verMod.oldValue, equals(1));
      expect(verMod.newValue, equals(2));
    });

    test('Handles null values correctly', () {
      final oldList = [
        {'id': 1, 'val': null},
      ];
      final newList = [
        {'id': 1, 'val': 'not null'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');
      final fieldChange = changes.first.children!.first;

      expect(fieldChange.key, equals('val'));
      expect(fieldChange.oldValue, isNull);
      expect(fieldChange.newValue, equals('not null'));
    });
  });

  group('String Splice Optimization', () {
    test('Generates TextSplice for string changes', () {
      final oldList = [
        {'id': 1, 'text': 'Hello World'},
      ];
      final newList = [
        {'id': 1, 'text': 'Hello Flutter World'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');
      final fieldChange = changes.first.children!.first;

      expect(fieldChange.key, equals('text'));
      expect(fieldChange.splice, isNotNull);

      // "Hello " (len 6) match. Insert "Flutter ".
      expect(fieldChange.splice!.index, equals(6));
      expect(fieldChange.splice!.deleteCount, equals(0));
      expect(fieldChange.splice!.insertText, equals('Flutter '));
    });

    test('Handles Unicode Surrogate Pairs (Emoji Safety)', () {
      // 🤚 is \uD83E\uDD1A (2 code units)
      final oldList = [
        {'id': 1, 'text': 'Hi 🤚'},
      ];
      final newList = [
        {'id': 1, 'text': 'Hi 🤚 there'},
      ];

      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');
      final fieldChange = changes.first.children!.first;

      expect(fieldChange.splice, isNotNull);
      // Ensure we didn't split the emoji. The index should differ by proper length.
      // 'Hi ' is 3. Emoji is 2. Total 5.
      expect(fieldChange.splice!.index, greaterThanOrEqualTo(5));
      expect(fieldChange.splice!.insertText, contains('there'));
    });
  });

  group('Performance / Stress Test', () {
    test('Handles large lists efficiently', () {
      // Generate 5000 items
      final oldList = List<Map<String, dynamic>>.generate(
        5000,
        (i) => {'id': i, 'val': 'item $i'},
      );
      final newList = List<Map<String, dynamic>>.from(oldList);

      // Make 3 changes
      newList.removeAt(100); // Delete
      newList.insert(4000, {'id': 9999, 'val': 'new'}); // Insert
      // Index 2500 shifted to 2499
      newList[2499] = {'id': 2500, 'val': 'CHANGED'}; // Modify

      final stopwatch = Stopwatch()..start();
      final changes = HybridDiffer.diff(oldList, newList, idField: 'id');
      stopwatch.stop();

      print('Diff 5000 items took: ${stopwatch.elapsedMilliseconds}ms');

      final deletes = changes.where((c) => c.op == ChangeOp.delete);
      final inserts = changes.where((c) => c.op == ChangeOp.insert);
      final modifies = changes.where((c) => c.op == ChangeOp.modify);

      expect(deletes.length, equals(1));
      expect(inserts.length, equals(1));
      expect(modifies.length, equals(1));

      // Ensure it's reasonably fast
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
