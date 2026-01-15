import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:pocketbase/pocketbase.dart';

class TokenRetryPolicy extends RetryPolicy {
  final PocketBase _pb;

  TokenRetryPolicy(this._pb);

  @override
  // Limit retries to 1 to prevent infinite loops if the refresh itself fails.
  int get maxRetryAttempts => 1;

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    // Check for 401 Unauthorized status
    if (response.statusCode == 401) {
      // Check if we even have a token to refresh.
      // If we are anonymous, a 401 is valid and shouldn't trigger a refresh.
      if (!_pb.authStore.isValid) return false;

      // print('[Auth] Token expired (401). Attempting refresh...');

      try {
        // PERFORMS THE AUTO REFRESH
        // The SDK's authRefresh method automatically rotates the token
        // and updates the AuthStore via the save() callback we defined earlier.
        await _pb.collection('users').authRefresh();

        return true; // Signal to retry the request
      } catch (e) {
        // print('[Auth] Refresh failed: $e. Logging out.');
        // If refresh fails (e.g., user banned, password changed),
        // we must clear the store to trigger a logout in the UI.
        _pb.authStore.clear();
        return false; // Do not retry
      }
    }
    return false;
  }
}

http.Client clientFactory(PocketBase pb) {
  return InterceptedClient.build(
    interceptors: [
      // Optional: Add logging interceptor here for debugging
    ],
    retryPolicy: TokenRetryPolicy(pb),
  );
}
