import 'dart:typed_data';
import 'package:collection/collection.dart';

enum DiffType { insert, delete, equal }

class DiffOperation<T> {
  final DiffType type;
  final T data;
  final int
      index; // Index in newList (for insert) or oldList (for delete/equal)

  DiffOperation(this.type, this.data, this.index);

  @override
  String toString() =>
      '$type: ${data.toString().substring(0, 20)}... (@$index)';
}

/// A generic-free typedef for the custom hasher to maximize performance
typedef JsonHasher = int Function(Map<String, dynamic> item);

class FastJsonDiffer {
  static const _deepEquality = DeepCollectionEquality();

  // POOLING: Reusable buffers to prevent GC thrashing during high-freq updates
  Int32List _vBuffer = Int32List(1024);

  // Storing history for the traceback
  // We reuse the list container, but we must allocate new Int32Lists for snapshots
  final List<Int32List> _traceBuffer = [];

  /// Main Diff Method.
  ///
  /// [keyGenerator] (Optional): Provide this for maximum speed.
  /// instead of comparing every field, return a hash of specific fields
  /// (e.g., `(i) => Object.hash(i['id'], i['version'])`).
  List<DiffOperation<Map<String, dynamic>>> diff(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList, {
    JsonHasher? keyGenerator,
  }) {
    // 1. Identity Check (Optimization)
    if (identical(oldList, newList)) return [];
    if (oldList.isEmpty && newList.isEmpty) return [];

    // 2. Generate Proxies (Hashes)
    // If no keyGenerator is provided, we default to expensive Deep Equality
    final hasher = keyGenerator ?? (item) => _deepEquality.hash(item);

    final oldHashes = _generateHashes(oldList, hasher);
    final newHashes = _generateHashes(newList, hasher);

    // 3. Run Myers Algorithm on Ints
    final rawOps = _diffInts(oldHashes, newHashes);

    // 4. Rehydrate (Map indices back to actual Objects)
    return rawOps.map((op) {
      switch (op.type) {
        case DiffType.insert:
          return DiffOperation(DiffType.insert, newList[op.index], op.index);
        case DiffType.delete:
          return DiffOperation(DiffType.delete, oldList[op.index], op.index);
        case DiffType.equal:
          return DiffOperation(DiffType.equal, oldList[op.index], op.index);
      }
    }).toList();
  }

  Int32List _generateHashes(
    List<Map<String, dynamic>> list,
    JsonHasher hasher,
  ) {
    final int len = list.length;
    final buffer = Int32List(len);
    for (var i = 0; i < len; i++) {
      buffer[i] = hasher(list[i]);
    }
    return buffer;
  }

  /// The Core Myers Logic specialized for Int32List.
  /// This runs purely on stack primitives and typed arrays.
  List<DiffOperation<int>> _diffInts(Int32List oldList, Int32List newList) {
    final n = oldList.length;
    final m = newList.length;
    final max = n + m;
    final requiredSize = 2 * max + 1;

    // Grow buffer if necessary
    if (_vBuffer.length < requiredSize) {
      _vBuffer = Int32List(requiredSize);
    }

    _vBuffer.fillRange(0, requiredSize, -1);
    _traceBuffer.clear();

    _vBuffer[max] = 0;

    for (var d = 0; d <= max; d++) {
      // Snapshot current V state for traceback.
      _traceBuffer.add(Int32List.fromList(_vBuffer.sublist(0, requiredSize)));

      for (var k = -d; k <= d; k += 2) {
        final kIndex = max + k;
        int x;

        // Choose move: Down (Insertion) or Right (Deletion)
        if (d == 0) {
          x = 0;
        } else if (k == -d ||
            (k != d && _vBuffer[kIndex - 1] < _vBuffer[kIndex + 1])) {
          x = _vBuffer[kIndex + 1];
        } else {
          x = _vBuffer[kIndex - 1] + 1;
        }

        int y = x - k;

        // Snake: Move diagonal as long as hashes match
        while (x < n && y < m && oldList[x] == newList[y]) {
          x++;
          y++;
        }

        _vBuffer[kIndex] = x;

        // Check for completion
        if (x >= n && y >= m) {
          return _buildScript(oldList, newList, d, max);
        }
      }
    }
    return [];
  }

  List<DiffOperation<int>> _buildScript(
    Int32List oldList,
    Int32List newList,
    int d,
    int maxOffset,
  ) {
    var script = <DiffOperation<int>>[];
    var x = oldList.length;
    var y = newList.length;

    for (var i = d; i > 0; i--) {
      final k = x - y;
      final kIndex = maxOffset + k;
      final prevV = _traceBuffer[i]; // FIXED: Use trace[i]

      final kMinus1 = kIndex - 1;
      final kPlus1 = kIndex + 1;

      int prevKIndex;
      final bool pickInsert;

      // Robust selection logic
      if (k == -i) {
        pickInsert = true;
      } else if (k == i) {
        pickInsert = false;
      } else if (prevV[kMinus1] == -1) {
        pickInsert = true;
      } else if (prevV[kPlus1] == -1) {
        pickInsert = false;
      } else {
        pickInsert = prevV[kMinus1] < prevV[kPlus1];
      }

      if (pickInsert) {
        prevKIndex = kPlus1;
      } else {
        prevKIndex = kMinus1;
      }

      final prevX = prevV[prevKIndex];
      // Assert specific invariants
      assert(
        prevX >= 0,
        "Myers invariant violated: prevX should effectively never be -1 (sentinel) when accessed from valid path.",
      );
      assert(
        x >= prevX,
        "Myers invariant violated: x ($x) cannot be less than prevX ($prevX)",
      );

      final isInsert = prevKIndex == kPlus1;
      final startX = isInsert ? prevX : prevX + 1;

      // Add Snakes (Equal)
      while (x > startX) {
        assert(x > 0, "Backtracking snake cannot go below 0 for x");
        script.add(DiffOperation(DiffType.equal, 0, x - 1));
        x--;
        y--;
      }

      // Add Edit
      if (isInsert) {
        assert(y > 0, "Insert operation must have y index > 0 (y=$y)");
        script.add(DiffOperation(DiffType.insert, 0, y - 1));
        y--;
      } else {
        assert(x > 0, "Delete operation must have x index > 0 (x=$x)");
        script.add(DiffOperation(DiffType.delete, 0, x - 1));
        x--;
      }
    }

    // Flush remaining snakes
    while (x > 0 && y > 0) {
      script.add(DiffOperation(DiffType.equal, 0, x - 1));
      x--;
      y--;
    }

    assert(
      x == 0 && y == 0,
      "Backtrack should end at 0,0. Ended at x=$x, y=$y. Traceback logic is flowed.",
    );

    return script.reversed.toList();
  }
}

void main() {
  final differ = FastJsonDiffer();

  // Scenario: API Response or Game State
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

  print('--- 1. Default (Deep Equality) ---');
  // Good for correctness, slower for large lists.
  final opsDefault = differ.diff(oldData, newData);

  for (var op in opsDefault) {
    if (op.type != DiffType.equal) print(op);
  }
  // Expected:
  // Delete: {id: 2...}
  // Delete: {id: 3, val: C...} (Because val changed, hash changed)
  // Insert: {id: 3, val: Z...}
  // Insert: {id: 4...}

  print('\n--- 2. Optimized (ID + Val Check) ---');
  // Great for high-frequency. We tell the differ EXACTLY what constitutes a change.
  // Here we ignore the 'meta' field entirely.
  final opsFast = differ.diff(
    oldData,
    newData,
    keyGenerator: (map) => Object.hash(map['id'], map['val']),
  );

  for (var op in opsFast) {
    if (op.type != DiffType.equal) print(op);
  }

  print('\n--- 3. Ultra Fast (ID Only - Move Detection) ---');
  // If we only care if the ID exists (e.g. for list animations where content updates later)
  final opsIdOnly = differ.diff(
    oldData,
    newData,
    keyGenerator: (map) => map['id'] as int, // Direct int cast is fastest
  );

  for (var op in opsIdOnly) {
    if (op.type != DiffType.equal) print(op);
  }
}
