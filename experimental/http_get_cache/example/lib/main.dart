import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http_get_cache/http_get_cache.dart';
import 'package:http_get_cache/http_get_cache_flutter.dart';
import 'package:http_get_cache/http_image_provider.dart';
import 'package:signals/signals_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFlutterHttpGetCache();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final client = httpClient();

  static const target = 'https://jsonplaceholder.typicode.com/photos';
  final requestCount$ = signal(0);

  // We limit to 50 items for the demo to keep it snappy and focused
  late final items$ = client
      .get(Uri.parse(target))
      .then((res) => res.statusCode == 200 ? jsonDecode(res.body) as List : [])
      .then((items) => items.take(50).cast<Map<String, Object?>>().toList())
      .then(
        (r) => () {
          requestCount$.value++;
          return r;
        }(),
      )
      .toFutureSignal();

  @override
  Widget build(BuildContext context) {
    final state = items$.watch(context);
    final count = requestCount$.watch(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Http Get Cache'),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.cloud_sync_outlined),
                    ),
                  ),
                ),
              ],
            ),
            state.map(
              data: (items) {
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No items found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final title = item['title'] as String;
                        final url = item['url'] as String;
                        // Use a deterministic random height for a staggered-like feel if we were using masonry,
                        // but for standard grid, we keep uniform aspect ratio.
                        // We'll use the ID to pick a color for the placeholder.
                        final id = item['id'] as int;
                        final color =
                            Colors.primaries[id % Colors.primaries.length];

                        return Card(
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: HttpImageProvider(
                                  Uri.parse(url),
                                  client: client,
                                ),
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: color.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: color.withValues(alpha: 0.2),
                                    child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 48),
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black87,
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              },
              error: (error) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => items$.refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => items$.refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Data'),
        ),
      ),
    );
  }
}
