import 'dart:convert';
import 'dart:math';
import 'package:diff_algorithims/object_transform.dart';
import 'package:test/test.dart';

// =============================================================================
// --- HELPER: PATCH APPLICATOR ---
// =============================================================================
// Since the provided code only included the Generator and UI, we need
// this helper in the test suite to verify the Diff actually works "Round Trip".

Map<String, dynamic> applyPatchHelper(
  Map<String, dynamic> original,
  Map<String, dynamic> diff,
) {
  final clone = Map<String, dynamic>.from(original);

  for (final key in diff.keys) {
    var diffVal = diff[key];
    final originalVal = clone[key];

    // Handle Deserialized JSON objects from serializeDiff
    if (diffVal is Map && diffVal.containsKey('_op')) {
      if (diffVal['_op'] == 'd') {
        diffVal = const Deleted();
      } else if (diffVal['_op'] == 's') {
        diffVal = TextSplice(diffVal['i'], diffVal['d'], diffVal['t']);
      }
    }

    if (diffVal is Deleted) {
      clone.remove(key);
    } else if (diffVal is TextSplice && originalVal is String) {
      clone[key] = diffVal.apply(originalVal);
    } else if (diffVal is Map<String, dynamic> &&
        originalVal is Map<String, dynamic>) {
      clone[key] = applyPatchHelper(originalVal, diffVal);
    } else {
      clone[key] = diffVal;
    }
  }
  return clone;
}

// =============================================================================
// --- THE TEST SUITE ---
// =============================================================================

void main() {
  group('1. TextSplice Logic', () {
    test('Correctly splices into the middle of a string', () {
      final splice = TextSplice(6, 0, "Dart "); // Insert at index 6
      final original = "Hello World";
      final result = splice.apply(original);
      expect(result, "Hello Dart World");
    });

    test('Correctly handles deletions', () {
      final splice = TextSplice(0, 5, ""); // Delete first 5 chars
      final original = "Hello World";
      final result = splice.apply(original);
      expect(result, " World");
    });

    test('Correctly handles replacements', () {
      // "brown" starts at 10, length 5. Replace with "red".
      final splice = TextSplice(10, 5, "red");
      final original = "The quick brown fox";
      final result = splice.apply(original);
      expect(result, "The quick red fox");
    });

    test('Handles index out of bounds gracefully (Append)', () {
      final splice = TextSplice(100, 0, "!");
      final original = "Hi";
      final result = splice.apply(original);
      expect(result, "Hi!");
    });
  });

  group('2. DiffEngine Basic Logic', () {
    test('Detects Added Keys', () {
      final oldMap = {'a': 1};
      final newMap = {'a': 1, 'b': 2};
      final diff = DiffEngine.generateDiff(oldMap, newMap);
      expect(diff, {'b': 2});
    });

    test('Detects Deleted Keys', () {
      final oldMap = {'a': 1, 'b': 2};
      final newMap = {'a': 1};
      final diff = DiffEngine.generateDiff(oldMap, newMap);
      expect(diff['b'], isA<Deleted>());
    });

    test('Detects Value Changes (Primitives)', () {
      final oldMap = {'a': 1};
      final newMap = {'a': 99};
      final diff = DiffEngine.generateDiff(oldMap, newMap);
      expect(diff, {'a': 99});
    });

    test('Treats Lists as Atomic Replacements', () {
      // The engine is designed to replace lists entirely, not diff indices
      final oldMap = {
        'tags': ['a', 'b'],
      };
      final newMap = {
        'tags': ['a', 'c'],
      };
      final diff = DiffEngine.generateDiff(oldMap, newMap);
      expect(diff['tags'], ['a', 'c']);
    });

    test('Recursively Diffs Nested Maps', () {
      final oldMap = {
        'meta': {'v': 1, 'active': true},
      };
      final newMap = {
        'meta': {'v': 2, 'active': true},
      };
      final diff = DiffEngine.generateDiff(oldMap, newMap);

      expect(diff.containsKey('meta'), true);
      expect(diff['meta'], {'v': 2}); // Should NOT contain 'active'
    });
  });

  group('3. Emoji & Unicode Safety (Crucial)', () {
    test('Does NOT split a surrogate pair when deleting', () {
      // 👋 is \uD83D\uDC4B (2 code units)
      final oldMap = {'msg': "Hi 👋"};
      final newMap = {'msg': "Hi "};

      final diff = DiffEngine.generateDiff(oldMap, newMap);
      final splice = diff['msg'] as TextSplice;

      // It should delete 2 units (the whole emoji), not 1
      expect(splice.deleteCount, 2, reason: "Should delete full emoji");
      expect(splice.index, 3);
    });

    test(
      'Handles changing one emoji to another (Surrogate boundary check)',
      () {
        // 👋 (\uD83D\uDC4B) -> 🤚 (\uD83E\uDD1A)
        // Note: They share the high surrogate \uD83... in some encodings,
        // or simply look similar. The algorithm must not get confused.
        final oldMap = {'msg': "A 👋 B"};
        final newMap = {'msg': "A 🤚 B"};

        final diff = DiffEngine.generateDiff(oldMap, newMap);
        final splice = diff['msg'] as TextSplice;

        // Should recognize the change at the emoji
        expect(splice.insertText, "🤚");
        // Applying it should result in valid string
        final patched = applyPatchHelper(oldMap, diff);
        expect(patched['msg'], "A 🤚 B");
      },
    );

    test('Handles Complex ZWJ Emojis (Family)', () {
      // 👨‍👩‍👧‍👦 is 11 chars long
      final family = "👨‍👩‍👧‍👦";
      final oldMap = {'icon': "Family: $family"};
      final newMap = {'icon': "Family: "}; // Deleted

      final diff = DiffEngine.generateDiff(oldMap, newMap);
      final splice = diff['icon'] as TextSplice;

      // Should delete exactly the length of the emoji + space
      // Length of "Family: " is 8.
      expect(splice.index, 8);
      expect(splice.deleteCount, family.length);
    });
  });

  group('4. Serialization', () {
    test('Serializes TextSplice and Deleted correctly', () {
      final diff = {
        'bio': TextSplice(5, 1, "a"),
        'oldField': const Deleted(),
        'simple': 123,
      };

      final jsonStr = serializeDiff(diff);
      final decoded = jsonDecode(jsonStr);

      expect(decoded['bio']['_op'], 's');
      expect(decoded['bio']['i'], 5);
      expect(decoded['oldField']['_op'], 'd');
      expect(decoded['simple'], 123);
    });

    test('Round Trip: Serialize -> Deserialize -> Apply', () {
      final oldState = {'text': "Hello"};
      final diff = {'text': TextSplice(5, 0, " World")};

      final jsonStr = serializeDiff(diff);
      final decodedDiff = jsonDecode(jsonStr); // Raw JSON Maps

      // Our helper must handle the raw JSON maps with _op
      final patched = applyPatchHelper(oldState, decodedDiff);
      expect(patched['text'], "Hello World");
    });
  });

  group('5. Fuzz Testing (Chaos Monkey)', () {
    // This generates random maps, mutates them, calculates diff,
    // and verifies that Old + Diff == New.
    test('Randomized Property Test (1000 iterations)', () {
      final r = Random(42); // Seed for reproducibility

      for (int i = 0; i < 1000; i++) {
        final stateA = _generateRandomMap(r, depth: 3);
        final stateB = _mutateMap(r, stateA);

        try {
          // 1. Generate
          final diff = DiffEngine.generateDiff(stateA, stateB);

          // 2. Simulate Network (Serialize/Deserialize)
          final jsonStr = serializeDiff(diff);
          final decodedDiff = jsonDecode(jsonStr);

          // 3. Patch
          final reconstructedB = applyPatchHelper(stateA, decodedDiff);

          // 4. Verify
          final isEqual = jsonEncode(stateB) == jsonEncode(reconstructedB);
          if (!isEqual) {
            fail('''
Fuzz Failure at iteration $i
Original: $stateA
Target:   $stateB
Diff:     $decodedDiff
Result:   $reconstructedB
''');
          }
        } catch (e, stack) {
          fail('Crash at iteration $i: $e\n$stack');
        }
      }
    });
  });
}

// =============================================================================
// --- FUZZER UTILITIES ---
// =============================================================================

Map<String, dynamic> _generateRandomMap(Random r, {int depth = 2}) {
  final map = <String, dynamic>{};
  final keyCount = r.nextInt(5);

  for (int i = 0; i < keyCount; i++) {
    final key = 'k$i';
    if (depth > 0 && r.nextBool()) {
      map[key] = _generateRandomMap(r, depth: depth - 1);
    } else {
      map[key] = _generateRandomValue(r);
    }
  }
  return map;
}

dynamic _generateRandomValue(Random r) {
  final type = r.nextInt(4);
  if (type == 0) return r.nextInt(100);
  if (type == 1) return r.nextBool();
  if (type == 2) {
    // Random String with occasional Emoji
    if (r.nextBool()) return "Test ${r.nextInt(100)}";
    return "Hello 👋 ${r.nextInt(10)}";
  }
  if (type == 3) return [1, 2, 3]; // Simple list
  return null;
}

Map<String, dynamic> _mutateMap(Random r, Map<String, dynamic> original) {
  // Deep copy via JSON
  final clone = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  final keys = clone.keys.toList();

  // 1. Add new key
  if (r.nextBool() || keys.isEmpty) {
    clone['new_${r.nextInt(100)}'] = 'added';
    return clone; // Return early to keep mutations simple per step
  }

  // 2. Delete key
  if (r.nextBool()) {
    clone.remove(keys[r.nextInt(keys.length)]);
    return clone;
  }

  // 3. Modify existing
  final key = keys[r.nextInt(keys.length)];
  final val = clone[key];

  if (val is Map<String, dynamic>) {
    clone[key] = _mutateMap(r, val);
  } else if (val is String) {
    // String mutation
    if (val.isNotEmpty) {
      clone[key] = val + " appended";
    } else {
      clone[key] = "New";
    }
  } else {
    clone[key] = "Changed Primitive";
  }

  return clone;
}
