import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../view_models/change_email_view_model.dart';

class PocketBaseChangeEmailScreen extends StatefulWidget {
  final AuthService authService;

  const PocketBaseChangeEmailScreen({super.key, required this.authService});

  @override
  State<PocketBaseChangeEmailScreen> createState() =>
      _PocketBaseChangeEmailScreenState();
}

class _PocketBaseChangeEmailScreenState
    extends State<PocketBaseChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final ChangeEmailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ChangeEmailViewModel(widget.authService);
  }

  Future<void> _requestEmailChange() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _viewModel.requestEmailChange(_emailController.text.trim());
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
            appBar: AppBar(title: const Text('Change Email')),
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
                      'Check your new email address for instructions to verify the change.',
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
          appBar: AppBar(title: const Text('Change Email')),
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
                      'Enter your new email address.',
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
                        labelText: 'New Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the new email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _viewModel.isLoading
                          ? null
                          : _requestEmailChange,
                      child: _viewModel.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Request Change'),
                    ),
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
