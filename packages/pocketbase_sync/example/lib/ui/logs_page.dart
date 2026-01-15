import 'package:flutter/material.dart';
import '../services/log_service.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              LogService().clear();
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: LogService(),
        builder: (context, child) {
          final logs = LogService().logs.reversed.toList();
          if (logs.isEmpty) {
            return const Center(child: Text('No logs collected yet.'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                dense: true,
                leading: Text(
                  log.time.toString().split('.').first,
                  style: const TextStyle(fontSize: 10),
                ),
                title: Text(log.message),
                subtitle: Text(log.level.name),
                trailing: log.error != null
                    ? const Icon(Icons.error, color: Colors.red)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
