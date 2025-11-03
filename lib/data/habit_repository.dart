import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/habit.dart';
import 'habit_store.dart';

class HabitRepository implements HabitStore {
  HabitRepository({
    DatabaseFactory? databaseFactoryOverride,
    String? databaseName,
  })  : _databaseFactory = databaseFactoryOverride ?? databaseFactory,
        _databaseName = databaseName ?? _defaultDatabaseName;

  static const String _defaultDatabaseName = 'habitflow.db';
  static const String _tableName = 'habits';

  final DatabaseFactory _databaseFactory;
  final String _databaseName;

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }

    final path = await _resolveDatabasePath();
    _database = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              focus_minutes INTEGER NOT NULL,
              streak INTEGER NOT NULL,
              completed INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    return _database!;
  }

  Future<String> _resolveDatabasePath() async {
    if (_databaseName == inMemoryDatabasePath) {
      return _databaseName;
    }
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, _databaseName);
  }

  @override
  Future<List<Habit>> fetchHabits() async {
    final db = await _db;
    final rows = await db.query(
      _tableName,
      orderBy: 'id DESC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  @override
  Future<Habit> insertHabit(Habit habit) async {
    final db = await _db;
    final id = await db.insert(
      _tableName,
      habit.toMap(includeId: false),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return habit.copyWith(id: id);
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    if (habit.id == null) {
      throw ArgumentError('Habit must have an id to be updated');
    }
    final db = await _db;
    await db.update(
      _tableName,
      habit.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  @override
  Future<void> deleteHabit(int id) async {
    final db = await _db;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> seedDefaults(List<Habit> habits) async {
    if (habits.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final habit in habits) {
      batch.insert(_tableName, habit.toMap(includeId: false));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(_tableName);
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  Future<void> deletePersistentStore() async {
    final path = await _resolveDatabasePath();
    await _databaseFactory.deleteDatabase(path);
  }
}
