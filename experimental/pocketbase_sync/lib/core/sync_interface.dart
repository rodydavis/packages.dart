import 'dart:async';

abstract class ISyncManager {
  /// Syncs data with the remote source.
  /// Should handle push (local -> remote) and pull (remote -> local).
  Future<void> sync();
}
