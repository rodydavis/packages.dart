import 'dart:math';
import 'dart:typed_data';

enum ChangeOp { insert, delete, modify, equal }

class DiffNode {
  final ChangeOp op;
  final String key;
  final Object? oldValue;
  final Object? newValue;
  final List<DiffNode>? children;
  final TextSplice? splice;

  DiffNode.insert(this.key, this.newValue)
      : op = ChangeOp.insert,
        oldValue = null,
        children = null,
        splice = null;

  DiffNode.delete(this.key, this.oldValue)
      : op = ChangeOp.delete,
        newValue = null,
        children = null,
        splice = null;

  DiffNode.equal(this.key, this.newValue)
      : op = ChangeOp.equal,
        oldValue = newValue,
        children = null,
        splice = null;

  DiffNode.modify(
    this.key,
    this.oldValue,
    this.newValue, {
    this.children,
    this.splice,
  }) : op = ChangeOp.modify;

  @override
  String toString() => '$op: $key';
}

class TextSplice {
  final int index;
  final int deleteCount;
  final String insertText;

  TextSplice(this.index, this.deleteCount, this.insertText);

  Map<String, dynamic> toJson() => {
        'i': index,
        'd': deleteCount,
        't': insertText,
      };
}

class HybridDiffer {
  static List<DiffNode> diff(
    List<Map<String, Object?>> oldList,
    List<Map<String, Object?>> newList, {
    required String idField,
  }) {
    final oldIds = oldList.map((e) => e[idField]).toList();
    final newIds = newList.map((e) => e[idField]).toList();

    final structuralOps = _myersDiff(oldIds, newIds);
    final results = <DiffNode>[];

    for (final op in structuralOps) {
      if (op.type == _MyersOpType.delete) {
        final item = oldList[op.oldIndex!];
        results.add(DiffNode.delete(item[idField].toString(), item));
      } else if (op.type == _MyersOpType.insert) {
        final item = newList[op.newIndex!];
        results.add(DiffNode.insert(item[idField].toString(), item));
      } else {
        // Equal ID: Check Content
        final oldItem = oldList[op.oldIndex!];
        final newItem = newList[op.newIndex!];
        final key = newItem[idField].toString();

        if (_areDeepEqual(oldItem, newItem)) {
          results.add(DiffNode.equal(key, newItem));
        } else {
          final fieldChanges = _generateObjectDiff(oldItem, newItem);
          results.add(
            DiffNode.modify(key, oldItem, newItem, children: fieldChanges),
          );
        }
      }
    }
    return results;
  }

  static List<DiffNode> _generateObjectDiff(
    Map<String, Object?> oldObj,
    Map<String, Object?> newObj,
  ) {
    final diffs = <DiffNode>[];
    final allKeys = {...oldObj.keys, ...newObj.keys}.toList()..sort();

    for (final key in allKeys) {
      final oldVal = oldObj[key];
      final newVal = newObj[key];

      if (!oldObj.containsKey(key)) {
        diffs.add(DiffNode.insert(key, newVal));
      } else if (!newObj.containsKey(key)) {
        diffs.add(DiffNode.delete(key, oldVal));
      } else if (oldVal is Map<String, Object?> &&
          newVal is Map<String, Object?>) {
        final nested = _generateObjectDiff(oldVal, newVal);
        if (nested.isNotEmpty) {
          diffs.add(DiffNode.modify(key, oldVal, newVal, children: nested));
        }
      } else if (oldVal is String && newVal is String) {
        if (oldVal != newVal) {
          final splice = _calculateStringSplice(oldVal, newVal);
          diffs.add(DiffNode.modify(key, oldVal, newVal, splice: splice));
        }
      } else {
        if (!_areDeepEqual(oldVal, newVal)) {
          diffs.add(DiffNode.modify(key, oldVal, newVal));
        }
      }
    }
    return diffs;
  }

  static bool _areDeepEqual(Object? a, Object? b) {
    if (a == b) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_areDeepEqual(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_areDeepEqual(a[key], b[key])) return false;
      }
      return true;
    }
    return false;
  }

  static TextSplice? _calculateStringSplice(String oldText, String newText) {
    if (oldText == newText) return null;
    int start = 0;
    final minLen = min(oldText.length, newText.length);
    while (start < minLen &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start++;
    }

    if (start > 0 &&
        start < oldText.length &&
        _isSurrogate(oldText.codeUnitAt(start - 1))) {
      start--;
    }

    int oldEnd = oldText.length;
    int newEnd = newText.length;
    while (oldEnd > start &&
        newEnd > start &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }

    return TextSplice(start, oldEnd - start, newText.substring(start, newEnd));
  }

  static bool _isSurrogate(int code) => (code >= 0xD800 && code <= 0xDFFF);

  // --- MYERS ALGORITHM ---

  static List<_MyersOp> _myersDiff(List oldIds, List newIds) {
    final n = oldIds.length;
    final m = newIds.length;
    final max = n + m;
    final v = Int32List(2 * max + 1)..fillRange(0, 2 * max + 1, -1);
    final trace = <Int32List>[];

    v[max] = 0;

    for (var d = 0; d <= max; d++) {
      trace.add(Int32List.fromList(v));
      for (var k = -d; k <= d; k += 2) {
        final indexK = max + k;
        int x;
        if (d == 0) {
          x = 0;
        } else if (k == -d || (k != d && v[indexK - 1] < v[indexK + 1])) {
          x = v[indexK + 1];
        } else {
          x = v[indexK - 1] + 1;
        }
        int y = x - k;
        while (x < n && y < m && oldIds[x] == newIds[y]) {
          x++;
          y++;
        }
        v[indexK] = x;
        if (x >= n && y >= m) {
          return _buildMyersScript(oldIds, newIds, trace, d, max);
        }
      }
    }
    return [];
  }

  static List<_MyersOp> _buildMyersScript(
    List oldIds,
    List newIds,
    List<Int32List> trace,
    int d,
    int maxOffset,
  ) {
    var script = <_MyersOp>[];
    var x = oldIds.length;
    var y = newIds.length;

    for (var i = d; i > 0; i--) {
      final k = x - y;
      final kIndex = maxOffset + k;
      final prevV = trace[i];
      final kMinus1 = kIndex - 1;
      final kPlus1 = kIndex - 1 + 2; // kIndex + 1

      int prevKIndex;
      final bool pickInsert;

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
      final isInsert = prevKIndex == kPlus1;
      final startX = isInsert ? prevX : prevX + 1;

      while (x > startX) {
        // Snake loop logic
        script.add(
          _MyersOp(_MyersOpType.equal, oldIndex: x - 1, newIndex: y - 1),
        );
        x--;
        y--;
      }

      if (isInsert) {
        // Moved down (Insert)
        script.add(_MyersOp(_MyersOpType.insert, newIndex: y - 1));
        y--;
      } else {
        // Moved right (Delete)
        script.add(_MyersOp(_MyersOpType.delete, oldIndex: x - 1));
        x--;
      }
    }

    // Flush remaining snakes
    while (x > 0 && y > 0) {
      script.add(
        _MyersOp(_MyersOpType.equal, oldIndex: x - 1, newIndex: y - 1),
      );
      x--;
      y--;
    }
    return script.reversed.toList();
  }
}

enum _MyersOpType { insert, delete, equal }

class _MyersOp {
  final _MyersOpType type;
  final int? oldIndex;
  final int? newIndex;
  _MyersOp(this.type, {this.oldIndex, this.newIndex});
}
