import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v8 word progress v9 is_known migration ile veriyi korur', () async {
    final database = await openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
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
        updated_at TEXT NOT NULL,
        review_stage INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('PRAGMA user_version = 8');
    await database.insert('word_progress', {
      'word_id': 'dog',
      'is_favorite': 1,
      'mastery': 'easy',
      'repetition_count': 4,
      'correct_count': 4,
      'wrong_count': 0,
      'last_reviewed_at': '2026-09-06T10:00:00.000Z',
      'next_review_at': '2026-09-09T10:00:00.000Z',
      'updated_at': '2026-09-06T10:00:00.000Z',
      'review_stage': 2,
    });

    final service = DatabaseService();
    await service.upgradeForTesting(database, oldVersion: 8);

    final columns = await database.rawQuery('PRAGMA table_info(word_progress)');
    expect(columns.any((column) => column['name'] == 'is_known'), isTrue);
    final row = (await database.query('word_progress')).single;
    expect(row['word_id'], 'dog');
    expect(row['is_favorite'], 1);
    expect(row['mastery'], 'easy');
    expect(row['repetition_count'], 4);
    expect(row['review_stage'], 2);
    expect(row['is_known'], 0);

    await service.upgradeForTesting(database, oldVersion: 8);
    expect((await database.query('word_progress')).single['is_known'], 0);
  });
}
