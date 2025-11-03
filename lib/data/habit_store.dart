import '../models/habit.dart';

abstract class HabitStore {
  Future<List<Habit>> fetchHabits();

  Future<Habit> insertHabit(Habit habit);

  Future<void> updateHabit(Habit habit);

  Future<void> seedDefaults(List<Habit> habits);

  Future<void> clearAll();

  Future<void> close();

  Future<void> deletePersistentStore();

  Future<void> deleteHabit(int id);
}
