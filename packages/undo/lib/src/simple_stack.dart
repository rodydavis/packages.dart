import 'package:undo/undo.dart';

/// Simple stack for tracking state changes with update callbacks.
class SimpleStack<T> extends ChangeStack {
  /// Simple stack for keeping track of changes and easy callback for new state changes.
  SimpleStack(
    this._state, {
    super.limit,
    this.onUpdate,
  }) {
    if (onUpdate != null) {
      onUpdate!(_state);
    }
  }

  late T _state;

  /// Current state.
  T get state => _state;

  set state(T val) => modify(val);

  /// Callback invoked when state is updated.
  void Function(T val)? onUpdate;

  /// Modifies the current state with [val], pushing a new change onto the stack.
  void modify(T val) {
    try {
      add(Change<T>(
        _state,
        () => _newValue(val),
        _newValue,
      ));
    } catch (e) {
      rethrow;
    }
  }

  void _newValue(T val) {
    _state = val;

    if (onUpdate != null) {
      onUpdate!(val);
    }
  }
}
