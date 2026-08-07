// Covers AppDatabase's schema migration path (schemaVersion 1 -> 5). This
// runs against real user data whenever someone updates the app, so a
// silent mistake here can corrupt or lose existing words without ever
// showing an error during development.
import 'package:drift/native.dart';
import 'package:english_learning/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-builds a v1-schema database (the shape implied by the oldest
/// `INSERT ... SELECT` column list in AppDatabase's migration code) and
/// seeds it with data, so the test exercises the *real* upgrade path
/// rather than just a fresh `onCreate`.
sqlite3.Database _buildV1Database() {
  final raw = sqlite3.sqlite3.openInMemory();
  raw.execute('''
    CREATE TABLE words (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      english TEXT NOT NULL,
      japanese TEXT NOT NULL,
      example_sentence TEXT,
      part_of_speech TEXT,
      tag TEXT,
      created_at INTEGER NOT NULL,
      leitner_box INTEGER NOT NULL DEFAULT 1,
      last_reviewed_at INTEGER
    )
  ''');
  raw.execute('''
    CREATE TABLE review_logs (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL REFERENCES words (id),
      reviewed_at INTEGER NOT NULL,
      direction TEXT NOT NULL,
      is_correct INTEGER NOT NULL
    )
  ''');

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  raw.execute(
    'INSERT INTO words (english, japanese, tag, created_at, leitner_box) '
    "VALUES ('abandon', '捨てる', 'ビジネス', ?, 3)",
    [now],
  );
  raw.execute('PRAGMA user_version = 1');
  return raw;
}

void main() {
  test(
    'upgrading from v1 preserves existing words and drops word_tags',
    () async {
      final rawDb = _buildV1Database();
      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));

      // Any query forces drift to open the connection and run the migration.
      final words = await db.select(db.words).get();

      expect(words, hasLength(1));
      final word = words.single;
      expect(word.english, 'abandon');
      expect(word.japanese, '捨てる');
      expect(word.leitnerBox, 3);
      // Columns added after v1 should exist and default to null for
      // pre-existing rows.
      expect(word.audioUrl, isNull);
      expect(word.nextReviewDate, isNull);

      // WordTags was introduced in v4 and removed again in v5 — the table
      // must not exist after migrating straight from v1 to v5.
      final tableExists = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'word_tags'",
          )
          .get();
      expect(tableExists, isEmpty);

      await db.close();
    },
  );

  test('a fresh database (onCreate) opens without error', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final words = await db.select(db.words).get();
    expect(words, isEmpty);
    await db.close();
  });
}
