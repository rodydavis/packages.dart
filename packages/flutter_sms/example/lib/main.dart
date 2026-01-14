import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sms/flutter_sms.dart';

void main() {
  runApp(const SmsApp());
}

class SmsApp extends StatelessWidget {
  const SmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SmsHomePage(),
    );
  }
}

class SmsViewModel extends ChangeNotifier {
  final List<String> _recipients = [];
  String _message = '';
  String? _status;
  bool _canSendSms = false;
  bool _isLoading = false;

  List<String> get recipients => List.unmodifiable(_recipients);
  String get message => _message;
  String? get status => _status;
  bool get canSendSms => _canSendSms;
  bool get isLoading => _isLoading;

  SmsViewModel() {
    _init();
  }

  Future<void> _init() async {
    _setLoading(true);
    try {
      _canSendSms = await canSendSMS();
    } catch (e, t) {
      debugPrint('Error checking capability: $e\n$t');
      _status = 'Error checking capability: $e';
    } finally {
      _setLoading(false);
    }
  }

  void addRecipient(String recipient) {
    if (recipient.trim().isNotEmpty &&
        !_recipients.contains(recipient.trim())) {
      _recipients.add(recipient.trim());
      notifyListeners();
    }
  }

  void removeRecipient(String recipient) {
    _recipients.remove(recipient);
    notifyListeners();
  }

  void updateMessage(String newMessage) {
    _message = newMessage;
    notifyListeners();
  }

  Future<void> send() async {
    if (_recipients.isEmpty || _message.isEmpty) {
      _status = 'Please add at least one recipient and a message.';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _status = null;
    notifyListeners();

    try {
      final result = await sendSMS(
        message: _message,
        recipients: _recipients,
      );
      _status = result;
    } catch (e, t) {
      debugPrint('Error sending SMS: $e\n$t');
      _status = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});

  @override
  State<SmsHomePage> createState() => _SmsHomePageState();
}

class _SmsHomePageState extends State<SmsHomePage> {
  late final SmsViewModel _viewModel;
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = SmsViewModel();
    // Sync text controller with view model just in case, though mainly one-way here
    _messageController.addListener(() {
      _viewModel.updateMessage(_messageController.text);
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _addRecipient() {
    _viewModel.addRecipient(_recipientController.text);
    _recipientController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, child) {
            return CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: const Text('Flutter SMS'),
                  centerTitle: true,
                  actions: [
                    if (_viewModel.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Capability Status
                        _StatusCard(
                          canSend: _viewModel.canSendSms,
                          statusMessage: _viewModel.status,
                        ),
                        const SizedBox(height: 24),

                        // Recipients Section
                        Text(
                          'Recipients',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _recipientController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter phone number',
                                  prefixIcon: Icon(Icons.person_add_outlined),
                                ),
                                keyboardType: TextInputType.phone,
                                onSubmitted: (_) => _addRecipient(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _addRecipient,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _viewModel.recipients
                              .map((r) => InputChip(
                                    label: Text(r),
                                    onDeleted: () =>
                                        _viewModel.removeRecipient(r),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
                                  ))
                              .toList(),
                        ),

                        const SizedBox(height: 24),

                        // Message Section
                        Text(
                          'Message',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Type your message here...',
                            alignLabelWithHint: true,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        FilledButton.icon(
                          onPressed: _viewModel.isLoading
                              ? null
                              : () => _viewModel.send(),
                          icon: const Icon(Icons.send),
                          label: const Text('Send SMS'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool canSend;
  final String? statusMessage;

  const _StatusCard({required this.canSend, this.statusMessage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  canSend ? Icons.check_circle : Icons.error,
                  color: canSend ? Colors.green : colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    canSend
                        ? 'Device is capable of sending SMS'
                        : 'Device cannot send SMS',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            if (statusMessage != null) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
