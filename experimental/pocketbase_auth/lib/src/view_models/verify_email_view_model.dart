import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class VerifyEmailViewModel extends ChangeNotifier {
  final AuthService _authService;

  VerifyEmailViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _success = false;
  bool get success => _success;

  Future<void> requestVerification() async {
    _isLoading = true;
    _errorMessage = null;
    _success = false;
    notifyListeners();

    try {
      await _authService.requestVerification();
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
