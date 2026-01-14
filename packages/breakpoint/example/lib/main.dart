import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breakpoint Example',
      debugShowCheckedModeBanner: false,
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
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final breakpoint = Breakpoint.fromConstraints(constraints);
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              title: const Text('Breakpoint Gallery'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => BreakpointInfoSheet(
                        breakpoint: breakpoint,
                      ),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: breakpoint.margin,
                  vertical: 16,
                ),
                child: BreakpointInfoCard(breakpoint: breakpoint),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: breakpoint.margin),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: breakpoint.columns,
                  crossAxisSpacing: breakpoint.gutters,
                  mainAxisSpacing: breakpoint.gutters,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return GridItem(index: index);
                  },
                  childCount: 24,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: breakpoint.gutters),
            ),
          ],
        ),
      );
    });
  }
}

class BreakpointInfoCard extends StatelessWidget {
  const BreakpointInfoCard({
    super.key,
    required this.breakpoint,
  });

  final Breakpoint breakpoint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Layout',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: 'Device',
                    value: breakpoint.device.name,
                    icon: Icons.devices,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: 'Window',
                    value: breakpoint.window.name,
                    icon: Icons.window,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: 'Columns',
                    value: '${breakpoint.columns}',
                    icon: Icons.view_column,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: 'Gutters',
                    value: '${breakpoint.gutters}px',
                    icon: Icons.space_bar,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: 'Margin',
                    value: '${breakpoint.margin}px',
                    icon: Icons.border_outer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class GridItem extends StatelessWidget {
  const GridItem({
    super.key,
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: LayoutBuilder(builder: (context, constraints) {
          final isSmall = constraints.maxHeight < 80;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: colorScheme.primaryContainer
                      .withValues(alpha: (index % 5 + 1) * 0.1),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: isSmall ? 32 : 48,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (!isSmall)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item $index',
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        width: 60,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class BreakpointInfoSheet extends StatelessWidget {
  const BreakpointInfoSheet({
    super.key,
    required this.breakpoint,
  });

  final Breakpoint breakpoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakpoint Details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text('Device Class: ${breakpoint.device}'),
          Text('Window Size: ${breakpoint.window}'),
          Text('Column Count: ${breakpoint.columns}'),
          Text('Gutter Size: ${breakpoint.gutters}'),
          Text('Margin Size: ${breakpoint.margin}'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
