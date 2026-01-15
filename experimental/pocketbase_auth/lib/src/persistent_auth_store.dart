import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';

/// Abstract contract for authentication persistence.
/// Implement this to use different storage solutions (e.g., Hive, SecureStorage).
abstract class AuthPersistence {
  Future<void> saveAuthData(String data);
  Future<String?> loadAuthData();
  Future<void> clearAuthData();
}

/// SharedPreferences implementation of [AuthPersistence].
class SharedPrefsAuthPersistence implements AuthPersistence {
  final SharedPreferences _prefs;
  static const String _kAuthKey = 'pb_auth_token';

  SharedPrefsAuthPersistence(this._prefs);

  @override
  Future<void> saveAuthData(String data) async {
    await _prefs.setString(_kAuthKey, data);
  }

  @override
  Future<String?> loadAuthData() async {
    return _prefs.getString(_kAuthKey);
  }

  @override
  Future<void> clearAuthData() async {
    await _prefs.remove(_kAuthKey);
  }
}

/// The custom AuthStore that connects PocketBase to any [AuthPersistence] implementation.
class PersistentAuthStore extends AsyncAuthStore {
  PersistentAuthStore({required AuthPersistence persistence, super.initial})
    : super(
        save: (String data) => persistence.saveAuthData(data),
        clear: () => persistence.clearAuthData(),
      );
}
