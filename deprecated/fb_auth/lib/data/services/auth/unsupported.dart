import '../../classes/index.dart';
import 'impl.dart';

class FBAuth implements FBAuthImpl {
  final FbApp app;

  FBAuth(this.app);

  @override
  Future<AuthUser> login(String username, String password) async {
    throw 'Platform Not Supported';
  }

  @override
  Future<AuthUser> createAccount(String username, String password,
      {String displayName, String photoUrl}) async {
    throw 'Platform Not Supported';
  }

  @override
  Future logout() async {
    throw 'Platform Not Supported';
  }

  @override
  Future<AuthUser> currentUser() async {
    throw 'Platform Not Supported';
  }

  @override
  Future<AuthUser> startAsGuest() async {
    throw 'Platform Not Supported';
  }

  @override
  Stream<AuthUser> onAuthChanged() {
    throw 'Platform Not Supported';
  }

  @override
  Future editInfo({String displayName, String photoUrl}) async {
    throw 'Platform Not Supported';
  }

  @override
  Future forgotPassword(String email) async {
    throw 'Platform Not Supported';
  }

  @override
  Future sendEmailVerification() async {
    throw 'Platform Not Supported';
  }

  @override
  Future loginCustomToken(String token) async {
    throw 'Platform Not Supported';
  }

  @override
  Future loginGoogle({String idToken, String accessToken}) async {
    throw 'Platform Not Supported';
  }
}
