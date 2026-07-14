import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const databaseName = 'kelimo.db';
  static const databaseVersion = 3;

  static Database? _database;
  static Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final openedDatabase = _database;
    if (openedDatabase != null) return openedDatabase;

    final openingDatabase = _openingDatabase;
    if (openingDatabase != null) return openingDatabase;

    final future = _openDatabase();
    _openingDatabase = future;
    try {
      final database = await future;
      _database = database;
      return database;
    } catch (error, stackTrace) {
      debugPrint('Kelimo veritabanı açılamadı: $error\n$stackTrace');
      rethrow;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    return openDatabase(
      p.join(databasesPath, databaseName),
      version: databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database database, int version) async {
    await _createVersion1(database);
    if (version >= 2) await _migrateVersion1To2(database);
    if (version >= 3) await _migrateVersion2To3(database);
  }

  Future<void> _createVersion1(Database database) async {
    await database.execute('''
      CREATE TABLE word_progress (
        word_id TEXT PRIMARY KEY,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        mastery TEXT NOT NULL DEFAULT 'new',
        repetition_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed_at TEXT,
        next_review_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE daily_progress (
        date_key TEXT PRIMARY KEY,
        review_count INTEGER NOT NULL DEFAULT 0,
        is_goal_completed INTEGER NOT NULL DEFAULT 0,
        streak_awarded INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE streak_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        current_streak INTEGER NOT NULL,
        last_completed_date TEXT
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _migrateVersion1To2(database);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _migrateVersion2To3(database);
    }
  }

  Future<void> _migrateVersion1To2(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS xp_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_xp INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.insert('xp_state', {
      'id': 1,
      'total_xp': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _migrateVersion2To3(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS quiz_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id TEXT NOT NULL,
        correct_count INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        score_percent INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        xp_awarded INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
