/// Represents a single reversible change.
class Change<T> {
  /// Creates a change with previous state [_oldValue], execution callback [_execute],
  /// and undo callback [_undo].
  Change(
    this._oldValue,
    this._execute,
    this._undo, {
    this.description = '',
  });

  /// Description of the change.
  final String description;

  final void Function() _execute;
  final T _oldValue;

  final void Function(T oldValue) _undo;

  /// Executes the change.
  void execute() {
    _execute();
  }

  /// Undoes the change, reverting to the previous state.
  void undo() {
    _undo(_oldValue);
  }
}
