import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthService _authService;

  RegisterViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> signup(
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (password != confirmPassword) {
      _errorMessage = "Passwords do not match";
      notifyListeners();
      return; // Or throw custom error
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signup(email, password);
    } catch (e) {
      _errorMessage = parseErrorMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
