import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../view_models/forgot_password_view_model.dart';

class PocketBaseForgotPasswordScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onBackToLogin;

  const PocketBaseForgotPasswordScreen({
    super.key,
    required this.authService,
    this.onBackToLogin,
  });

  @override
  State<PocketBaseForgotPasswordScreen> createState() =>
      _PocketBaseForgotPasswordScreenState();
}

class _PocketBaseForgotPasswordScreenState
    extends State<PocketBaseForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final ForgotPasswordViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ForgotPasswordViewModel(widget.authService);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _viewModel.resetPassword(_emailController.text.trim());
    } catch (_) {
      // Error handled by view model
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.success) {
          return Scaffold(
            appBar: AppBar(title: const Text('Forgot Password')),
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
                      'Password reset link sent!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your email for instructions to reset your password.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: widget.onBackToLogin,
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Forgot Password')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter your email address to receive a password reset link.',
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
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _viewModel.isLoading ? null : _resetPassword,
                      child: _viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Reset Link'),
                    ),
                    if (widget.onBackToLogin != null) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : widget.onBackToLogin,
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _viewModel.dispose();
    super.dispose();
  }
}
