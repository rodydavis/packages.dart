import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase_auth/pocketbase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final AuthService authService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize PocketBase
  // Replace with your actual PocketBase URL
  final pb = PocketBase('http://127.0.0.1:8090');

  // 2. Initialize Shared Preferences
  final prefs = await SharedPreferences.getInstance();
  final persistence = SharedPrefsAuthPersistence(prefs);

  // 3. Initialize Persistent Store
  // Load initial auth data
  final initialAuth = await persistence.loadAuthData();
  final authStore = PersistentAuthStore(
    persistence: persistence,
    initial: initialAuth,
  );

  // 4. Configure PocketBase with the custom store and httpClient
  final pbRetry = PocketBase(
    'http://127.0.0.1:8090',
    authStore: authStore,
    httpClientFactory: () => clientFactory(pb),
  );

  authService = AuthService(pbRetry);

  runApp(const MyApp());
}

/// Converts a Stream into a Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/login',
          builder: (context, state) => PocketBaseLoginScreen(
            authService: authService,
            onSignup: () => context.push('/register'),
            onForgotPassword: () => context.push('/forgot-password'),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => PocketBaseRegisterScreen(
            authService: authService,
            onLogin: () => context.pop(),
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => PocketBaseForgotPasswordScreen(
            authService: authService,
            onBackToLogin: () => context.pop(),
          ),
        ),
        GoRoute(
          path: '/update-profile',
          builder: (context, state) =>
              PocketBaseUpdateProfileScreen(authService: authService),
        ),
        GoRoute(
          path: '/change-email',
          builder: (context, state) =>
              PocketBaseChangeEmailScreen(authService: authService),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) =>
              PocketBaseVerifyEmailScreen(authService: authService),
        ),
        GoRoute(
          path: '/delete-account',
          builder: (context, state) =>
              PocketBaseDeleteAccountScreen(authService: authService),
        ),
      ],
      redirect: (context, state) {
        final isLoggedIn = authService.currentUser != null;
        final isLoggingIn = state.matchedLocation == '/login';
        final isRegistering = state.matchedLocation == '/register';
        final isForgot = state.matchedLocation == '/forgot-password';

        if (!isLoggedIn && !isLoggingIn && !isRegistering && !isForgot) {
          return '/login';
        }

        if (isLoggedIn && (isLoggingIn || isRegistering || isForgot)) {
          return '/';
        }

        return null;
      },
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PocketBase Auth Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.getStringValue('email') ?? 'User'}!'),
            const SizedBox(height: 20),
            const Text('You are securely logged in.'),
            const SizedBox(height: 40),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.push('/update-profile'),
                  icon: const Icon(Icons.person),
                  label: const Text('Update Profile'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/change-email'),
                  icon: const Icon(Icons.email),
                  label: const Text('Change Email'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/verify-email'),
                  icon: const Icon(Icons.verified),
                  label: const Text('Verify Email'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/delete-account'),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
