import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/habit_repository.dart';
import 'data/habit_store.dart';
import 'models/habit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const desktopPlatforms = {
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  };

  if (!kIsWeb && desktopPlatforms.contains(defaultTargetPlatform)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  runApp(HabitFlowApp());
}

class HabitFlowApp extends StatefulWidget {
  HabitFlowApp({
    super.key,
    HabitStore? repository,
  }) : repository = repository ?? HabitRepository();

  final HabitStore repository;

  @override
  State<HabitFlowApp> createState() => _HabitFlowAppState();
}

class _HabitFlowAppState extends State<HabitFlowApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _handleThemeModeChange(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void dispose() {
    unawaited(widget.repository.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.indigoAccent);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigoAccent,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'HabitFlow',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 1,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
      ),
      home: HabitShell(
        repository: widget.repository,
        themeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChange,
      ),
    );
  }
}

class HabitShell extends StatefulWidget {
  const HabitShell({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final HabitStore repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HabitShell> createState() => _HabitShellState();
}

class _HabitShellState extends State<HabitShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Overview',
      ),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          OverviewScreen(repository: widget.repository),
          SettingsScreen(
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}

class RoutineIdea {
  const RoutineIdea({
    required this.title,
    required this.subtitle,
    required this.focusMinutes,
  });

  final String title;
  final String subtitle;
  final int focusMinutes;
}

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.repository,
  });

  final HabitStore repository;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  static const List<Habit> _seedHabits = [
    Habit(
      title: 'Focus Warmup',
      description: 'Spend five minutes planning the first task of the day.',
      focusMinutes: 5,
      streak: 1,
    ),
  ];

  final List<RoutineIdea> _routineIdeas = const [
    RoutineIdea(
      title: '15 min walk',
      subtitle: 'Quick loop outside to reset energy.',
      focusMinutes: 15,
    ),
    RoutineIdea(
      title: 'Inbox zero',
      subtitle: 'Declutter your inbox in one focused sprint.',
      focusMinutes: 20,
    ),
    RoutineIdea(
      title: 'Read 10 pages',
      subtitle: 'Wind down with meaningful reading time.',
      focusMinutes: 25,
    ),
    RoutineIdea(
      title: 'Plan tomorrow',
      subtitle: 'Outline priorities before the day ends.',
      focusMinutes: 10,
    ),
    RoutineIdea(
      title: 'Language practice',
      subtitle: 'Daily flashcard or speaking drill session.',
      focusMinutes: 30,
    ),
  ];

  List<Habit> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    try {
      var habits = await widget.repository.fetchHabits();
      if (habits.isEmpty) {
        await widget.repository.seedDefaults(_seedHabits);
        habits = await widget.repository.fetchHabits();
      }
      if (!mounted) return;
      setState(() {
        _habits = List<Habit>.from(habits);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _habits = [];
        _isLoading = false;
      });
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'overview_screen',
          context: ErrorDescription('loading habits from repository'),
        ),
      );
    }
  }

  Future<void> _toggleCompletion(int index) async {
    final habit = _habits[index];
    final toggled = habit.copyWith(
      completed: !habit.completed,
      streak: !habit.completed
          ? habit.streak + 1
          : (habit.streak > 0 ? habit.streak - 1 : 0),
    );

    setState(() {
      _habits = List<Habit>.from(_habits)..[index] = toggled;
    });

    await widget.repository.updateHabit(toggled);
  }

  Future<void> _openAddHabitSheet() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final focusController = TextEditingController(text: '15');

    final newHabit = await showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create habit',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: focusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Focus minutes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final focusMinutes = int.tryParse(focusController.text);

                    if (title.isEmpty || description.isEmpty || focusMinutes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add a title, description, and focus time.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop(
                      Habit(
                        title: title,
                        description: description,
                        focusMinutes: focusMinutes,
                        streak: 0,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('Add habit'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (newHabit != null) {
      final savedHabit = await widget.repository.insertHabit(newHabit);
      if (!mounted) return;
      setState(() {
        _habits = [savedHabit, ..._habits];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${savedHabit.title} added to your list')),
      );
    }
  }

  int get _completedCount => _habits.where((habit) => habit.completed).length;

  double get _completionRate =>
      _habits.isEmpty ? 0 : _completedCount / _habits.length;

  Future<void> _handleRoutineTap(RoutineIdea idea) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                idea.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                idea.subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Text('${idea.focusMinutes} minute focus'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Add to timeline'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      final habit = Habit(
        title: idea.title,
        description: idea.subtitle,
        focusMinutes: idea.focusMinutes,
        streak: 0,
      );
      final savedHabit = await widget.repository.insertHabit(habit);
      if (!mounted) return;
      setState(() {
        _habits = [savedHabit, ..._habits];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${savedHabit.title} added to your timeline')),
      );
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    if (habit.id == null) return;
    final previous = List<Habit>.from(_habits);
    setState(() {
      _habits.removeWhere((h) => h.id == habit.id);
    });
    try {
      await widget.repository.deleteHabit(habit.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${habit.title} removed')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _habits = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove habit right now')),
      );
    }
  }

  Future<void> _confirmDelete(Habit habit) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove habit'),
            content: Text(
              'Remove ${habit.title} from your timeline? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldDelete) {
      await _deleteHabit(habit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddHabitSheet,
              icon: const Icon(Icons.add),
              label: const Text('New habit'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _OverviewHeader(
              totalHabits: _habits.length,
              completedHabits: _completedCount,
              completionRate: _completionRate,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Today at a glance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _InsightsRow(
              completed: _completedCount,
              total: _habits.length,
              focusMinutes: _habits.fold<int>(
                0,
                (total, habit) => total + habit.focusMinutes,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Curated routines',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _routineIdeas.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final idea = _routineIdeas[index];
                  return _RoutineCard(
                    idea: idea,
                    onTap: () => _handleRoutineTap(idea),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final habit = _habits[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _habits.length - 1 ? 0 : 16,
                    ),
                    child: HabitTimelineTile(
                      habit: habit,
                      onToggle: () => _toggleCompletion(index),
                      onDelete: () => _confirmDelete(habit),
                    ),
                  );
                },
                childCount: _habits.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.totalHabits,
    required this.completedHabits,
    required this.completionRate,
  });

  final int totalHabits;
  final int completedHabits;
  final double completionRate;

  @override
  Widget build(BuildContext context) {
    final percent = (completionRate * 100).round();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 32,
        top: MediaQuery.of(context).padding.top + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HabitFlow',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Build rhythm with intentional routines.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 28),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: completionRate),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: value.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$completedHabits of $totalHabits complete ($percent%)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightsRow extends StatelessWidget {
  const _InsightsRow({
    required this.completed,
    required this.total,
    required this.focusMinutes,
  });

  final int completed;
  final int total;
  final int focusMinutes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _InsightCard(
              title: 'Consistency',
              value: total == 0 ? '0%' : '${(completed / total * 100).round()}%',
              subtitle: 'Completed today',
              icon: Icons.trending_up,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _InsightCard(
              title: 'Focus time',
              value: '${focusMinutes}m',
              subtitle: 'Scheduled streaks',
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
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
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.idea,
    required this.onTap,
  });

  final RoutineIdea idea;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ]
        : [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ];
    final textColor =
        isDark ? colorScheme.onSurface : colorScheme.onPrimaryContainer;

    return GestureDetector(
      key: ValueKey('routine-card-${idea.title}'),
      onTap: () async {
        await onTap();
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              Icons.auto_awesome,
              color: textColor,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  idea.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.2,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to preview',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                    height: 1.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class HabitTimelineTile extends StatelessWidget {
  const HabitTimelineTile({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onDelete,
  });

  final Habit habit;
  final Future<void> Function() onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Checkbox(
              value: habit.completed,
              onChanged: (_) async {
                await onToggle();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        habit.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove habit',
              onPressed: onDelete,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${habit.streak} day${habit.streak == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('${habit.focusMinutes} min focus'),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(habit.title),
                          content: Text(
                            'Great work keeping the streak at ${habit.streak} days. '
                            'Stay consistent for a week to unlock a milestone badge.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('View details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _muteNotifications = true;
  bool _streakReminders = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = widget.themeMode;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: const Text('Choose how HabitFlow looks on your device.'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.laptop_windows),
                label: Text('System'),
              ),
            ],
            selected: <ThemeMode>{themeMode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                widget.onThemeModeChanged(selection.first);
              }
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus assists',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mute notifications during focus sessions'),
                    value: _muteNotifications,
                    onChanged: (value) {
                      setState(() {
                        _muteNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remind me when a streak is about to reset'),
                    value: _streakReminders,
                    onChanged: (value) {
                      setState(() {
                        _streakReminders = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
