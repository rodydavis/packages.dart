import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthService _authService;

  ForgotPasswordViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _success = false;
  bool get success => _success;

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _success = false;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
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
