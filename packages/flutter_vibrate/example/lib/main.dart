import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

void main() {
  runApp(const VibrateExampleApp());
}

class VibrateExampleApp extends StatelessWidget {
  const VibrateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haptic Feedback',
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
      themeMode: ThemeMode.system,
      home: const HapticFeedbackDemo(),
    );
  }
}

class HapticFeedbackDemo extends StatefulWidget {
  const HapticFeedbackDemo({super.key});

  @override
  State<HapticFeedbackDemo> createState() => _HapticFeedbackDemoState();
}

class _HapticFeedbackDemoState extends State<HapticFeedbackDemo> {
  // We use a future to track initialization status
  late final Future<bool> _initFuture;
  bool _canVibrate = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<bool> _init() async {
    final canVibrate = await Vibrate.canVibrate;
    if (mounted) {
      setState(() {
        _canVibrate = canVibrate;
      });
    }
    return canVibrate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haptic Studio'),
        centerTitle: true,
        notificationPredicate: (notification) => notification.depth == 1,
        scrolledUnderElevation: 4.0,
      ),
      body: FutureBuilder<bool>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Failed to initialize vibration.'));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DeviceabilityHeader(canVibrate: _canVibrate),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionHeader(title: 'Basic Vibration'),
                    _VibrateCard(
                      title: 'Standard Vibrate',
                      subtitle: '500ms vibration',
                      icon: Icons.vibration,
                      onTap: _canVibrate ? () => Vibrate.vibrate() : null,
                    ),
                    const SizedBox(height: 12),
                    _VibrateCard(
                      title: 'Pattern Vibrate',
                      subtitle: '500ms, wait 1s, 500ms',
                      icon: Icons.graphic_eq,
                      onTap: _canVibrate
                          ? () {
                              final pauses = [
                                const Duration(milliseconds: 500),
                                const Duration(milliseconds: 1000),
                                const Duration(milliseconds: 500),
                              ];
                              Vibrate.vibrateWithPauses(pauses);
                            }
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Haptic Feedback'),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _feedbackItems[index];
                    return _FeedbackTile(
                      item: item,
                      isEnabled: _canVibrate,
                      onTap: () {
                        if (_canVibrate) {
                          Vibrate.feedback(item.type);
                        }
                      },
                    );
                  }, childCount: _feedbackItems.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceabilityHeader extends StatelessWidget {
  final bool canVibrate;

  const _DeviceabilityHeader({required this.canVibrate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: canVibrate
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            canVibrate ? Icons.check_circle_outline : Icons.error_outline,
            size: 32,
            color: canVibrate
                ? colorScheme.onPrimaryContainer
                : colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canVibrate ? 'Device Ready' : 'Capability Missing',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: canVibrate
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  canVibrate
                      ? 'This device supports vibration features.'
                      : 'This device does not support vibration.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: canVibrate
                        ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                        : colorScheme.onErrorContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VibrateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _VibrateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                color: onTap != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatefulWidget {
  final _FeedbackItem item;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _FeedbackTile({
    required this.item,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<_FeedbackTile> createState() => _FeedbackTileState();
}

class _FeedbackTileState extends State<_FeedbackTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      _controller.forward().then((_) => _controller.reverse());
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: Material(
        color:
            widget.item.color?.withOpacity(0.15) ??
            colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.isEnabled ? _handleTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.item.icon,
                  size: 32,
                  color: widget.item.color ?? colorScheme.onSecondaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        widget.item.color ?? colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackItem {
  final String label;
  final FeedbackType type;
  final IconData icon;
  final Color? color;

  const _FeedbackItem(this.label, this.type, this.icon, [this.color]);
}

final List<_FeedbackItem> _feedbackItems = [
  const _FeedbackItem(
    'Impact',
    FeedbackType.impact,
    Icons.touch_app,
    Colors.orange,
  ),
  const _FeedbackItem(
    'Success',
    FeedbackType.success,
    Icons.check_circle,
    Colors.green,
  ),
  const _FeedbackItem(
    'Warning',
    FeedbackType.warning,
    Icons.warning_amber,
    Colors.orangeAccent,
  ),
  const _FeedbackItem(
    'Error',
    FeedbackType.error,
    Icons.error_outline,
    Colors.red,
  ),
  const _FeedbackItem(
    'Selection',
    FeedbackType.selection,
    Icons.gesture,
    Colors.blue,
  ),
  const _FeedbackItem('Heavy', FeedbackType.heavy, Icons.anchor, Colors.indigo),
  const _FeedbackItem(
    'Medium',
    FeedbackType.medium,
    Icons.circle_notifications,
    Colors.purple,
  ),
  const _FeedbackItem(
    'Light',
    FeedbackType.light,
    Icons.bubble_chart,
    Colors.teal,
  ),
];
