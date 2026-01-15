import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../view_models/delete_account_view_model.dart';

class PocketBaseDeleteAccountScreen extends StatefulWidget {
  final AuthService authService;

  const PocketBaseDeleteAccountScreen({super.key, required this.authService});

  @override
  State<PocketBaseDeleteAccountScreen> createState() =>
      _PocketBaseDeleteAccountScreenState();
}

class _PocketBaseDeleteAccountScreenState
    extends State<PocketBaseDeleteAccountScreen> {
  final _confirmController = TextEditingController();
  late final DeleteAccountViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DeleteAccountViewModel(widget.authService);
  }

  Future<void> _deleteAccount() async {
    if (_confirmController.text != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type DELETE to confirm.')),
      );
      return;
    }

    try {
      await _viewModel.deleteAccount();
      // Navigation handled by auth state change
    } catch (_) {
      // Error handled by view model
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Delete Account'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Are you sure you want to delete your account?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This action is irreversible. All your data will be permanently removed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
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
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE to confirm',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _viewModel.isLoading ? null : _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _viewModel.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Permanently Delete Account'),
                  ),
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
    _confirmController.dispose();
    _viewModel.dispose();
    super.dispose();
  }
}
