import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_demo/data/habit_store.dart';
import 'package:flutter_demo/main.dart';
import 'package:flutter_demo/models/habit.dart';

Future<void> _waitForDashboard(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

class FakeHabitStore implements HabitStore {
  FakeHabitStore({List<Habit>? seed}) : _habits = List.of(seed ?? []) {
    _syncIds();
  }

  List<Habit> _habits;
  int _idCounter = 0;

  void _syncIds() {
    _idCounter = _habits.fold<int>(
      0,
      (previous, habit) => habit.id != null && habit.id! > previous ? habit.id! : previous,
    );
    _habits = _habits
        .map((habit) => habit.id == null ? habit.copyWith(id: ++_idCounter) : habit)
        .toList()
      ..sort((a, b) => b.id!.compareTo(a.id!));
  }

  @override
  Future<void> clearAll() async {
    _habits = [];
    _idCounter = 0;
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deletePersistentStore() async {}

  @override
  Future<List<Habit>> fetchHabits() async {
    return List<Habit>.unmodifiable(_habits);
  }

  @override
  Future<Habit> insertHabit(Habit habit) async {
    final saved = habit.copyWith(id: ++_idCounter);
    _habits = [saved, ..._habits];
    return saved;
  }

  @override
  Future<void> deleteHabit(int id) async {
    _habits.removeWhere((habit) => habit.id == id);
  }

  @override
  Future<void> seedDefaults(List<Habit> habits) async {
    _habits = List.of(habits);
    _syncIds();
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    if (habit.id == null) {
      throw ArgumentError('Habit must have an id to update');
    }
    final index = _habits.indexWhere((element) => element.id == habit.id);
    if (index == -1) {
      throw StateError('Habit with id ${habit.id} not found');
    }
    final copy = habit;
    _habits[index] = copy;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HabitStore repository;

  setUp(() async {
    repository = FakeHabitStore(seed: const [
      Habit(
        title: 'Focus Warmup',
        description: 'Spend five minutes planning the first task of the day.',
        focusMinutes: 5,
        streak: 1,
      ),
    ]);
  });

  tearDown(() async {
    await repository.close();
  });

  testWidgets('Overview shows starter insights and habits', (tester) async {
    await tester.pumpWidget(HabitFlowApp(repository: repository));
    await _waitForDashboard(tester);

    expect(find.text('HabitFlow'), findsOneWidget);
    expect(find.text('Curated routines'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Focus Warmup'), findsOneWidget);
    expect(find.byType(HabitTimelineTile), findsWidgets);
  });

  testWidgets('Switching to dark theme updates MaterialApp themeMode', (tester) async {
    await tester.pumpWidget(HabitFlowApp(repository: repository));
    await _waitForDashboard(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final materialAppBefore = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialAppBefore.themeMode, ThemeMode.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final materialAppAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialAppAfter.themeMode, ThemeMode.dark);
  });

  testWidgets('Curated routine quick add inserts habit into timeline', (tester) async {
    await tester.pumpWidget(HabitFlowApp(repository: repository));
    await _waitForDashboard(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final routineCard = find.byKey(const ValueKey('routine-card-15 min walk')).hitTestable();
    expect(routineCard, findsOneWidget);

    final tapPosition = tester.getCenter(routineCard);
    await tester.tapAt(tapPosition);
    await tester.pumpAndSettle();

    expect(find.text('Quick loop outside to reset energy.'), findsOneWidget);
    expect(find.text('Add to timeline'), findsOneWidget);

    await tester.tap(find.text('Add to timeline'));
    await tester.pumpAndSettle();

    expect(find.text('15 min walk added to your timeline'), findsOneWidget);
    expect(find.text('Quick loop outside to reset energy.'), findsWidgets);
  });

  testWidgets('Deleting a habit removes it from the timeline', (tester) async {
    await tester.pumpWidget(HabitFlowApp(repository: repository));
    await _waitForDashboard(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final initialTiles =
        tester.widgetList(find.byType(HabitTimelineTile)).length;
    expect(initialTiles, greaterThan(0));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('removed'), findsOneWidget);
    final remainingTiles =
        tester.widgetList(find.byType(HabitTimelineTile)).length;
    expect(remainingTiles, initialTiles - 1);
  });
}

