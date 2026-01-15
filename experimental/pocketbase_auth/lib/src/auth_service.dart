import 'dart:async';
import 'package:pocketbase/pocketbase.dart';

class AuthService {
  final PocketBase _pb;
  // Broadcast controller allows multiple listeners (UI, Router, Analytics)
  final StreamController<RecordModel?> _userController =
      StreamController<RecordModel?>.broadcast();

  AuthService(this._pb) {
    // 1. Emit Initial State
    // We synchronously check the store. If valid, emit the model.
    _emitCurrent();

    // 2. Listen to PocketBase AuthStore changes
    // The onChange stream fires whenever authStore.save() or authStore.clear() is called.
    _pb.authStore.onChange.listen((event) {
      _emitCurrent();
    });
  }

  void _emitCurrent() {
    final model = _pb.authStore.record;
    if (_pb.authStore.isValid && model is RecordModel) {
      _userController.add(model);
    } else {
      _userController.add(null);
    }
  }

  // Expose the stream for the UI to consume.
  // We use .distinct() to ensure the UI only rebuilds if the user object actually changes.
  Stream<RecordModel?> get authStateChanges =>
      _userController.stream.distinct();

  // Current value accessor for synchronous checks (e.g. inside guards)
  RecordModel? get currentUser => _pb.authStore.record;

  // --- Actions ---

  Future<void> login(String email, String password) async {
    await _pb.collection('users').authWithPassword(email, password);
  }

  Future<void> signup(String email, String password) async {
    await _pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'name': email.split('@').first,
          },
        );
    // Auto-login after signup
    await login(email, password);
  }

  Future<void> logout() async {
    _pb.authStore.clear();
  }

  Future<void> resetPassword(String email) async {
    await _pb.collection('users').requestPasswordReset(email);
  }

  Future<RecordModel> updateProfile(Map<String, dynamic> body) async {
    final user = currentUser;
    if (user == null) {
      throw ClientException(
        url: Uri(),
        response: {'message': 'User not logged in'},
      );
    }
    return await _pb.collection('users').update(user.id, body: body);
  }

  Future<void> requestEmailChange(String newEmail) async {
    final user = currentUser;
    if (user == null) {
      throw ClientException(
        url: Uri(),
        response: {'message': 'User not logged in'},
      );
    }
    await _pb.collection('users').requestEmailChange(newEmail);
  }

  Future<void> requestVerification() async {
    final user = currentUser;
    if (user == null) {
      throw ClientException(
        url: Uri(),
        response: {'message': 'User not logged in'},
      );
    }
    await _pb
        .collection('users')
        .requestVerification(user.getStringValue('email'));
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw ClientException(
        url: Uri(),
        response: {'message': 'User not logged in'},
      );
    }
    await _pb.collection('users').delete(user.id);
    _pb.authStore.clear();
  }
}
