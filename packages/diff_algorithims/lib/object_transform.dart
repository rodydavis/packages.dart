import 'dart:convert';

// =============================================================================
// --- CORE ALGORITHM (The Diff Engine) ---
// =============================================================================

/// Sentinel value for deleted keys
class Deleted {
  const Deleted();
  Map<String, dynamic> toJson() => {'_op': 'd'};
  @override
  String toString() => '<Deleted>';
}

const deleted = Deleted();

/// Represents a precise text edit (Splice)
class TextSplice {
  final int index;
  final int deleteCount;
  final String insertText;

  TextSplice(this.index, this.deleteCount, this.insertText);

  /// Applies the splice to a string
  String apply(String original) {
    if (index > original.length) return original + insertText;
    final start = original.substring(0, index);
    final end = original.substring(index + deleteCount);
    return '$start$insertText$end';
  }

  Map<String, dynamic> toJson() => {
    '_op': 's',
    'i': index,
    'd': deleteCount,
    't': insertText,
  };
}

class DiffEngine {
  /// Generates a recursive diff between two JSON-like maps
  static Map<String, dynamic> generateDiff(
    Map<String, dynamic> oldObj,
    Map<String, dynamic> newObj,
  ) {
    final diff = <String, dynamic>{};

    // 1. Walk new keys
    for (final key in newObj.keys) {
      final oldVal = oldObj[key];
      final newVal = newObj[key];

      // New Key Added
      if (!oldObj.containsKey(key)) {
        diff[key] = newVal;
        continue;
      }

      // Recursive Map Diff
      if (oldVal is Map<String, dynamic> && newVal is Map<String, dynamic>) {
        final nested = generateDiff(oldVal, newVal);
        if (nested.isNotEmpty) diff[key] = nested;
        continue;
      }

      // Smart String Diff (Splice)
      if (oldVal is String && newVal is String) {
        final splice = _calculateStringSplice(oldVal, newVal);
        if (splice != null) diff[key] = splice;
        continue;
      }

      // Standard Value Replacement (Primitives or Lists)
      if (!_areValuesEqual(oldVal, newVal)) {
        diff[key] = newVal;
      }
    }

    // 2. Walk old keys to find Deletions
    for (final key in oldObj.keys) {
      if (!newObj.containsKey(key)) diff[key] = deleted;
    }

    return diff;
  }

  /// Calculates the minimal edit (splice) with EMOJI SAFETY
  static TextSplice? _calculateStringSplice(String oldText, String newText) {
    if (oldText == newText) return null;

    // A. Find Common Prefix
    int start = 0;
    final minLen = (oldText.length < newText.length)
        ? oldText.length
        : newText.length;

    while (start < minLen &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start++;
    }

    // SAFETY: If we stopped inside a Surrogate Pair (High Surrogate), backtrack.
    if (start > 0 && start < oldText.length && start < newText.length) {
      final prevCode = oldText.codeUnitAt(start - 1);
      if (prevCode >= 0xD800 && prevCode <= 0xDBFF) {
        start--;
      }
    }

    // B. Find Common Suffix
    int oldEnd = oldText.length;
    int newEnd = newText.length;

    while (oldEnd > start &&
        newEnd > start &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }

    // SAFETY: If we stopped inside a Surrogate Pair (Low Surrogate), expand the change area.
    if (oldEnd < oldText.length && newEnd < newText.length) {
      final code = oldText.codeUnitAt(oldEnd);
      if (code >= 0xDC00 && code <= 0xDFFF) {
        oldEnd++;
        newEnd++;
      }
    }

    final deleteCount = oldEnd - start;
    final insertText = newText.substring(start, newEnd);

    return TextSplice(start, deleteCount, insertText);
  }

  static bool _areValuesEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
      return true;
    }
    return false;
  }
}

/// Helper to serialize the diff for the UI/Network
String serializeDiff(Map<String, dynamic> diff) {
  // We use a custom encoder to handle our TextSplice and Deleted objects
  return const JsonEncoder.withIndent('  ').convert(
    jsonDecode(
      jsonEncode(
        diff,
        toEncodable: (obj) {
          if (obj is TextSplice) return obj.toJson();
          if (obj is Deleted) return obj.toJson();
          return obj;
        },
      ),
    ),
  );
}