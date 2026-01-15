import 'dart:math';
import 'package:diff_algorithims/myers_diff.dart';
import 'package:test/test.dart';

void main() {
  final differ = FastJsonDiffer();

  final oldData = [
    {'id': 1, 'val': 'A', 'meta': 'complex_obj'},
    {'id': 2, 'val': 'B', 'meta': 'complex_obj'},
    {'id': 3, 'val': 'C', 'meta': 'complex_obj'},
  ];

  final newData = [
    {'id': 1, 'val': 'A', 'meta': 'complex_obj'},
    {'id': 3, 'val': 'Z', 'meta': 'complex_obj'}, // Modified (val C -> Z)
    {'id': 4, 'val': 'D', 'meta': 'complex_obj'}, // Inserted
  ];

  group('FastJsonDiffer Scenarios', () {
    test('Default (Deep Equality) detects content changes', () {
      // Good for correctness, slower for large lists.
      final ops = differ.diff(oldData, newData);

      // Filtering out 'equal' ops to check changes
      final changes = ops.where((op) => op.type != DiffType.equal).toList();

      // Expected changes:
      // 1. Delete id:2
      // 2. Delete id:3 (old version)
      // 3. Insert id:3 (new version)
      // 4. Insert id:4

      expect(changes.length, equals(4));

      expect(
        changes.any((op) => op.type == DiffType.delete && op.data['id'] == 2),
        isTrue,
      );
      expect(
        changes.any((op) => op.type == DiffType.insert && op.data['id'] == 4),
        isTrue,
      );

      // ID 3 changed, so it should appear as both delete and insert
      expect(
        changes.any(
          (op) =>
              op.type == DiffType.delete &&
              op.data['id'] == 3 &&
              op.data['val'] == 'C',
        ),
        isTrue,
      );
      expect(
        changes.any(
          (op) =>
              op.type == DiffType.insert &&
              op.data['id'] == 3 &&
              op.data['val'] == 'Z',
        ),
        isTrue,
      );
    });

    test(
      'Optimized (ID + Val Check) behaves like Deep Equality for relevant fields',
      () {
        // Here we ignore the 'meta' field entirely, but 'val' changed so result is same as above.
        final ops = differ.diff(
          oldData,
          newData,
          keyGenerator: (map) => Object.hash(map['id'], map['val']),
        );

        final changes = ops.where((op) => op.type != DiffType.equal).toList();

        expect(changes.length, equals(4));

        expect(
          changes.any((op) => op.type == DiffType.delete && op.data['id'] == 2),
          isTrue,
        );
        expect(
          changes.any((op) => op.type == DiffType.insert && op.data['id'] == 4),
          isTrue,
        );

        // ID 3 changed val
        expect(
          changes.any((op) => op.type == DiffType.delete && op.data['id'] == 3),
          isTrue,
        );
        expect(
          changes.any((op) => op.type == DiffType.insert && op.data['id'] == 3),
          isTrue,
        );
      },
    );

    test('Ultra Fast (ID Only) detects moves/existence only', () {
      // If we only care if the ID exists (e.g. for list animations where content updates later)
      final ops = differ.diff(
        oldData,
        newData,
        keyGenerator: (map) => map['id'] as int,
      );

      final changes = ops.where((op) => op.type != DiffType.equal).toList();

      // Expected changes:
      // 1. Delete id:2
      // 2. Insert id:4
      // Node 3 should be EQUAL because ID matches

      expect(changes.length, equals(2));

      expect(
        changes.any((op) => op.type == DiffType.delete && op.data['id'] == 2),
        isTrue,
      );
      expect(
        changes.any((op) => op.type == DiffType.insert && op.data['id'] == 4),
        isTrue,
      );

      // Ensure id:3 is considered Equal
      final id3Ops = ops.where((op) => op.data['id'] == 3).toList();
      expect(id3Ops.length, equals(1));
      expect(id3Ops.first.type, equals(DiffType.equal));
    });
  });

  group('Fuzz Tests', () {
    test('Randomized Diff/Patch Consistency (500 Iterations)', () {
      final r = Random(42);

      for (var i = 0; i < 500; i++) {
        // 1. Generate two random lists
        // We make listB a mutation of listA to ensure some overlap
        final listA = _generateRandomList(r, size: r.nextInt(50) + 10);
        final listB = _mutateList(r, listA);

        // 2. Diff
        // Using "Ultra Fast" (ID only) mode since it's cleaner for simple integer maps
        // or just standard map equality if we use defaults.
        // Let's use standard map equality for robustness.
        final ops = differ.diff(listA, listB);

        // 3. Reconstruct List B from Ops
        final reconstructed = <Map<String, dynamic>>[];

        for (final op in ops) {
          switch (op.type) {
            case DiffType.equal:
            case DiffType.insert:
              reconstructed.add(op.data);
              break;
            case DiffType.delete:
              // Deletions are skipped in the new list construction
              break;
          }
        }

        // 4. Verify
        try {
          expect(reconstructed, equals(listB));
        } catch (e) {
          print('Fuzz Failure at iteration $i');
          print('List A (len ${listA.length}): $listA');
          print('List B (len ${listB.length}): $listB');
          print('Ops: $ops');
          rethrow;
        }
      }
    });
  });
}

// --- Fuzz Utils ---

List<Map<String, dynamic>> _generateRandomList(Random r, {required int size}) {
  return List.generate(size, (index) {
    return {
      'id': r.nextInt(1000), // Random IDs, duplicates possible
      'val': r.nextInt(100),
      'content': _randomString(r),
    };
  });
}

List<Map<String, dynamic>> _mutateList(
  Random r,
  List<Map<String, dynamic>> original,
) {
  final clone = List<Map<String, dynamic>>.from(original);
  final mutations = r.nextInt(10) + 1; // 1 to 10 mutations

  for (var m = 0; m < mutations; m++) {
    if (clone.isEmpty) {
      clone.add(_generateSingleItem(r));
      continue;
    }

    final action = r.nextInt(3);
    if (action == 0) {
      // Insert
      final index = r.nextInt(clone.length + 1);
      clone.insert(index, _generateSingleItem(r));
    } else if (action == 1) {
      // Delete
      final index = r.nextInt(clone.length);
      clone.removeAt(index);
    } else {
      // Modify (Replace item)
      final index = r.nextInt(clone.length);
      clone[index] = _generateSingleItem(r);
    }
  }
  return clone;
}

Map<String, dynamic> _generateSingleItem(Random r) {
  return {
    'id': r.nextInt(1000),
    'val': r.nextInt(100),
    // 'content': _randomString(r), // Keep simple
  };
}

String _randomString(Random r) {
  const chars = 'abcdefghijklmnopqrstuvwxyz';
  return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
}
