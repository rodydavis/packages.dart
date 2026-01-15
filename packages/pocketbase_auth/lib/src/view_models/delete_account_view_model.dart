import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class DeleteAccountViewModel extends ChangeNotifier {
  final AuthService _authService;

  DeleteAccountViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
    } catch (e) {
      _errorMessage = parseErrorMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
