# undo

A clean, robust, and easy-to-use Undo/Redo library for Dart and Flutter. It leverages the Command Pattern to manage state changes, allowing you to easily roll back or replay actions in your application.

## Features

*   🔄 **Undo/Redo**: Simple stack-based undo/redo history.
*   📦 **Batched Changes**: Group multiple changes into a single undoable action (e.g., a multi-field form update).
*   🎨 **Flexible**: Works with any architecture (ChangeNotifier, Bloc, Riverpod, etc.).
*   ⚡ **Lightweight**: Minimal overhead, zero dependencies.

## Installation

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  undo: ^1.6.0
```

Run `pub get` or `flutter pub get`.

## Usage

### Basic Usage

Create a `ChangeStack` to manage your changes. A `Change` consists of:
1.  The **old state** (to revert to).
2.  The **execute** logic (to perform the change).
3.  The **undo** logic (to revert the change).

```dart
import 'package:undo/undo.dart';

void main() {
  final changes = ChangeStack();
  var count = 0;

  // Perform a change
  changes.add(
    Change<int>(
      count, // Old value (0)
      () => count++, // Execute: increment
      (oldVal) => count = oldVal, // Undo: set back to old val
      description: 'Increment count',
    ),
  );

  print(count); // 1

  // Undo the change
  changes.undo();
  print(count); // 0
  
  // Redo the change
  changes.redo();
  print(count); // 1
}
```

### Working with Objects

When modifying objects, capture the specific field value *before* the change so you can restore it.

```dart
class User {
  String name = 'John';
}

void main() {
  final user = User();
  final changes = ChangeStack();

  // Capture the OLD name before changing it
  final oldName = user.name;

  changes.add(
    Change<String>(
      oldName,
      () => user.name = 'Jane', // New name
      (val) => user.name = val, // Restore old name
      description: 'Update name',
    ),
  );
  
  print(user.name); // Jane
  changes.undo();
  print(user.name); // John
}
```

### SimpleStack (Quick Start)

`SimpleStack` is a wrapper around `ChangeStack` that makes it easier to track a single state object. It's great for simple use cases.

```dart
final stack = SimpleStack<int>(0); // Initial state is 0

// Modifying state automatically creates a change history
stack.modify(1); 
print(stack.state); // 1

stack.undo();
print(stack.state); // 0
```

### Grouping Changes

Sometimes you want multiple operations to be undone as a single step. Use `addGroup` (or manual `group` logic in 1.6.0+).

```dart
changes.add(
  Change.group([
    Change(
      user.firstName,
      () => user.firstName = 'Jane',
      (val) => user.firstName = val,
    ),
    Change(
      user.lastName,
      () => user.lastName = 'Doe',
      (val) => user.lastName = val,
    ),
  ]),
);
```

## Flutter Integration

`ChangeStack` works seamlessly with `ChangeNotifier` to rebuild your UI when undo/redo state changes.

```dart
class MyController extends ChangeNotifier {
  final ChangeStack _changes = ChangeStack();
  int _count = 0;

  int get count => _count;
  bool get canUndo => _changes.canUndo;
  bool get canRedo => _changes.canRedo;

  void increment() {
    _changes.add(
      Change<int>(
        _count,
        () {
           _count++;
           notifyListeners();
        },
        (oldVal) {
           _count = oldVal;
           notifyListeners();
        },
      ),
    );
  }

  void undo() {
    _changes.undo();
    notifyListeners();
  }

  void redo() {
    _changes.redo();
    notifyListeners();
  }
}
```

See the [example](example/lib/main.dart) folder for a complete Flutter Todo List application.
