import 'package:flutter/material.dart';
import '../../pocketbase_auth.dart';

class PocketBaseLoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onSignup;
  final VoidCallback? onForgotPassword;

  const PocketBaseLoginScreen({
    super.key,
    required this.authService,
    this.onSignup,
    this.onForgotPassword,
  });

  @override
  State<PocketBaseLoginScreen> createState() => _PocketBaseLoginScreenState();
}

class _PocketBaseLoginScreenState extends State<PocketBaseLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(widget.authService);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _viewModel.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Navigation is handled by auth state stream
    } catch (_) {
      // Error is handled in ViewModel and UI updates via listener
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _viewModel.isLoading ? null : _login,
                      child: _viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                    if (widget.onForgotPassword != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : widget.onForgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                    if (widget.onSignup != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _viewModel.isLoading
                            ? null
                            : widget.onSignup,
                        child: const Text('Create an account'),
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
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }
}
