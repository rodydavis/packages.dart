import 'package:flutter/foundation.dart';
import '../auth_service.dart';
import '../utils.dart';

class UpdateProfileViewModel extends ChangeNotifier {
  final AuthService _authService;

  UpdateProfileViewModel(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _success = false;
  bool get success => _success;

  Future<void> updateProfile({String? name, String? avatar}) async {
    _isLoading = true;
    _errorMessage = null;
    _success = false;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatar != null) body['avatar'] = avatar;

      await _authService.updateProfile(body);
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
