import 'dart:async';
import 'dart:math';

import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_sync/pocketbase_sync.dart';
import 'package:pocketbase_sync/sync_managers/in_memory.dart';

import '../models/message.dart';
import '../services/log_service.dart' as app_logs;
import 'logs_page.dart';

class SyncHomePage extends StatefulWidget {
  const SyncHomePage({super.key});

  @override
  State<SyncHomePage> createState() => _SyncHomePageState();
}

class _SyncHomePageState extends State<SyncHomePage> {
  late final PocketBase pb;
  late final InMemoryRepository<Message> repository;
  late final PocketBaseSyncManager<Message> manager;
  final _logger = Logger('SyncHomePage');

  bool _isLoading = true; // Initial full-screen load
  bool _isSyncing = false; // Background sync indicator
  List<SyncRecord<Message>> _records = [];
  String? _currentUserEmail;

  // Editing State
  String? _editingId;
  late final TextEditingController _editController;

  // New State Variables
  bool _autoSync = true;
  bool _isOffline = false;
  StreamSubscription? _updateSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    app_logs.LogService().init(); // Initialize Logger

    // Initialize synchronously to avoid LateInitializationError in build()
    pb = PocketBase(
      'http://127.0.0.1:8090',
      httpClientFactory: kIsWeb
          ? () => FetchClient(streamRequests: true)
          : null,
    );
    repository = InMemoryRepository<Message>();
    manager = PocketBaseSyncManager<Message>(
      pb: pb,
      collection: 'messages',
      fromJson: (j) => MessageMapper.fromMap(j),
      toJson: (m) => m.toMap(),
      repository: repository,
      autoSyncInterval: const Duration(seconds: 5),
    );

    _updateSubscription = manager.onUpdate.listen((_) {
      _refreshList();
    });

    _editController = TextEditingController();

    _init();
  }

  @override
  void dispose() {
    _editController.dispose();
    _updateSubscription?.cancel();
    manager.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // 1. Authenticate (Anonymous/Dummy for demo, or real auth)
    try {
      final id = Random().nextInt(10000);
      final email = 'test_sync_$id}@example.com';
      final password = 'password123456';
      final name = 'Test User $id';

      try {
        await pb
            .collection('users')
            .create(
              body: {
                'email': email,
                'password': password,
                'passwordConfirm': password,
                'name': name,
              },
            );
      } catch (_) {}

      final auth = await pb
          .collection('users')
          .authWithPassword(email, password);
      _currentUserEmail = auth.record.getStringValue('email');
    } catch (e, stack) {
      _logger.warning('Auth failed', e, stack);
    }

    // Init Realtime Subscription
    try {
      manager.subscribe();
    } catch (e) {
      _logger.warning('Realtime subscription failed', e);
    }

    // Load initial empty state
    await _refreshList();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshList() async {
    final records = await repository.getAll();
    setState(() {
      _records = records.where((r) => !r.isDeleted).toList();
    });
  }

  Future<void> _sync() async {
    if (_isOffline) {
      return;
    }

    setState(() => _isSyncing = true); // Show linear progress
    try {
      await manager.sync();
      await _refreshList();
    } catch (e, stack) {
      _logger.severe('Sync failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _toggleAutoSync(bool value) {
    setState(() {
      _autoSync = value;
    });

    if (_autoSync) {
      manager.autoSyncInterval = const Duration(seconds: 5);
      _sync(); // Initial sync
    } else {
      manager.autoSyncInterval = null;
    }
  }

  Future<void> _addMessage() async {
    final id = manager.generateId();
    final message = Message(
      id: id,
      message: 'Hello at ${DateTime.now().toIso8601String()}',
      author: pb.authStore.model?.id ?? 'anon',
    );

    await manager.create(id, message);
    await _refreshList();
    _refresh();
  }

  void _refresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), _sync);
  }

  void _handleEdit(SyncRecord<Message> record) {
    setState(() {
      _editingId = record.id;
      _editController.text = record.data.message;
    });
  }

  Future<void> _saveEdit(String id, Message original) async {
    final newText = _editController.text.trim();
    if (newText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message cannot be empty')));
      return;
    }

    if (newText == original.message) {
      _cancelEdit();
      return;
    }

    try {
      // Create updated copy
      final updated = Message(
        id: original.id,
        message: newText,
        author: original.author,
      );

      await manager.update(id, updated);
      await _refreshList();
      _cancelEdit();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _editController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PB Sync Example'),
        actions: [
          if (_isSyncing || _isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: (_isLoading || _isOffline) ? null : _sync,
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Sync Settings',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: manager.isConnectedNotifier,
              builder: (context, isConnected, child) {
                String modeText;
                Color statusColor;
                IconData icon;

                if (isConnected) {
                  modeText = 'Mode: Realtime';
                  statusColor = Colors.green;
                  icon = Icons.bolt;
                } else if (_autoSync) {
                  modeText = 'Mode: Polling (5s)';
                  statusColor = Colors.orange;
                  icon = Icons.sync;
                } else {
                  modeText = 'Mode: Manual';
                  statusColor = Colors.grey;
                  icon = Icons.touch_app;
                }

                return ListTile(
                  title: Text(
                    modeText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: Icon(icon, color: statusColor),
                  trailing: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Auto-Sync (5s)'),
              value: _autoSync,
              onChanged: _toggleAutoSync,
              secondary: const Icon(Icons.autorenew),
            ),
            SwitchListTile(
              title: const Text('Offline Mode'),
              subtitle: const Text('Simulate network disconnect'),
              value: _isOffline,
              onChanged: (val) {
                if (mounted) setState(() => _isOffline = val);
                if (_isOffline) {
                  manager.unsubscribe();
                } else {
                  manager.subscribe();
                  _sync();
                }
              },
              secondary: const Icon(Icons.wifi_off),
            ),
            const Divider(),
            ListTile(
              title: const Text('View Logs'),
              leading: const Icon(Icons.bug_report),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'OFFLINE MODE ENABLED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_currentUserEmail != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Logged in as: $_currentUserEmail'),
            ),
          Expanded(
            child: _records.isEmpty
                ? const Center(child: Text("No messages. Add one!"))
                : ListView.builder(
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final isEditing = _editingId == record.id;

                      return ListTile(
                        leading: Icon(
                          record.isDirty
                              ? Icons.cloud_upload
                              : Icons.cloud_done,
                          color: record.isDirty ? Colors.orange : Colors.green,
                        ),
                        title: isEditing
                            ? TextField(
                                controller: _editController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Edit message...',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Text(record.data.message),
                        subtitle: Text('ID: ${record.id}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEditing) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _saveEdit(record.id, record.data),
                                tooltip: 'Save',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: _cancelEdit,
                                tooltip: 'Cancel',
                              ),
                            ] else ...[
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  try {
                                    await manager.delete(record.id);
                                    await _refreshList();
                                    _refresh();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delete failed: $e'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                        onTap: isEditing ? null : () => _handleEdit(record),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMessage,
        child: const Icon(Icons.add),
      ),
    );
  }
}
