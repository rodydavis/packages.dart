import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../view_models/verify_email_view_model.dart';

class PocketBaseVerifyEmailScreen extends StatefulWidget {
  final AuthService authService;

  const PocketBaseVerifyEmailScreen({super.key, required this.authService});

  @override
  State<PocketBaseVerifyEmailScreen> createState() =>
      _PocketBaseVerifyEmailScreenState();
}

class _PocketBaseVerifyEmailScreenState
    extends State<PocketBaseVerifyEmailScreen> {
  late final VerifyEmailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VerifyEmailViewModel(widget.authService);
  }

  Future<void> _requestVerification() async {
    try {
      await _viewModel.requestVerification();
    } catch (_) {
      // Error handled by view model
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need to re-fetch the user to check verification status, or rely on auth state updates.
    // However, for this simple screen, we might just use the current user from authService.
    // Ideally, the ViewModel should also expose the user or verification status if it changes.
    // For now, let's keep using widget.authService.currentUser but maybe we should move that to VM too?
    // Let's stick to the screen accessing authService for user info as it was doing.
    final user = widget.authService.currentUser;
    final isVerified = user?.getBoolValue('verified') ?? false;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.success) {
          return Scaffold(
            appBar: AppBar(title: const Text('Verify Email')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verification email sent!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your email for instructions to verify your account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Verify Email')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isVerified) ...[
                    const Icon(Icons.verified, color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Your email is verified!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your email is not verified.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email: ${user?.getStringValue('email')}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_viewModel.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _viewModel.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _viewModel.isLoading
                          ? null
                          : _requestVerification,
                      child: _viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Verification Email'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
