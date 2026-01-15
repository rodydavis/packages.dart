import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class ChangeEmailViewModel extends ChangeNotifier {
  final AuthService _authService;

  ChangeEmailViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _success = false;
  bool get success => _success;

  Future<void> requestEmailChange(String newEmail) async {
    _isLoading = true;
    _errorMessage = null;
    _success = false;
    notifyListeners();

    try {
      await _authService.requestEmailChange(newEmail);
      _success = true;
    } catch (e) {
      _errorMessage = parseErrorMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
