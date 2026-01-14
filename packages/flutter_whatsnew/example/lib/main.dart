import 'package:flutter/material.dart';
import 'package:flutter_whatsnew/flutter_whatsnew.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter WhatsNew Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter WhatsNew'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Changelogs'),
          _buildListTile(
            context,
            icon: Icons.list_alt,
            title: 'Standard Changelog',
            subtitle: 'Parses CHANGELOG.md automatically',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WhatsNewPage.changelog(
                    title: const Text(
                      "What's New",
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    buttonText: const Text(
                      'Continue',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.timer,
            title: 'Scheduled Changelog',
            subtitle: 'Shows after a 3 second delay',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduledWhatsNewPage(
                    details: WhatsNewPage.changelog(
                      title: const Text(
                        "What's New",
                        style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      buttonText: const Text(
                        'Continue',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    delay: const Duration(seconds: 3),
                    child: Scaffold(
                      appBar: AppBar(title: const Text('Wait for it...')),
                      body: const Center(child: Text('Loading changelog...')),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Custom Pages'),
          _buildListTile(
            context,
            icon: Icons.stars,
            title: 'Feature List',
            subtitle: 'Custom items and styling',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WhatsNewPage(
                    title: const Text(
                      "What's New",
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    buttonText: const Text(
                      'Let\'s Go!',
                      style: TextStyle(color: Colors.white),
                    ),
                    items: [
                      const ListTile(
                        leading: Icon(Icons.palette),
                        title: Text('Material 3 Support'),
                        subtitle: Text('Beautiful adaptive colors and shapes'),
                      ),
                      const ListTile(
                        leading: Icon(Icons.dark_mode),
                        title: Text('Dark Mode'),
                        subtitle: Text('Easy on the eyes at night'),
                      ),
                      const ListTile(
                        leading: Icon(Icons.speed),
                        title: Text('Performance'),
                        subtitle: Text('Faster and smoother than ever'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.thumb_up),
                        title: const Text('Interactive'),
                        subtitle: const Text('Tap to learn more'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Feature tapped!')),
                          );
                        },
                      ),
                    ],
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
          _buildListTile(
            context,
            icon: Icons.info_outline,
            title: 'Detail Popup',
            subtitle: 'Simple informational dialog',
            onTap: () {
              WhatsNewPage.showDetailPopUp(
                context,
                'Did you know?',
                'You can use WhatsNewPage.showDetailPopUp to show quick information without a full page navigation.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
