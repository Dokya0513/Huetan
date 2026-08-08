import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Words, ReviewLogs, ActivityLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(activityLogs);
      }
      if (from < 3) {
        // `japanese` becomes nullable and `audioUrl`/`nextReviewDate`
        // are added. SQLite can't relax a NOT NULL constraint in
        // place, so the table is recreated and data copied over.
        await m.database.customStatement(
          'ALTER TABLE words RENAME TO words_old',
        );
        await m.createTable(words);
        await m.database.customStatement('''
              INSERT INTO words (id, english, japanese, example_sentence,
                part_of_speech, tag, created_at, leitner_box, last_reviewed_at)
              SELECT id, english, japanese, example_sentence,
                part_of_speech, tag, created_at, leitner_box, last_reviewed_at
              FROM words_old
            ''');
        await m.database.customStatement('DROP TABLE words_old');
      }
      if (from < 4) {
        // Words now support multiple tags via WordTags. Carry over the
        // old single free-text `tag` column as each word's first tag.
        await m.database.customStatement('''
              CREATE TABLE IF NOT EXISTS word_tags (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                word_id INTEGER NOT NULL REFERENCES words (id),
                tag TEXT NOT NULL,
                UNIQUE (word_id, tag)
              )
            ''');
        await m.database.customStatement('''
              INSERT INTO word_tags (word_id, tag)
              SELECT id, tag FROM words WHERE tag IS NOT NULL AND tag != ''
            ''');
      }
      if (from < 5) {
        // The tag system (WordTags) has been replaced by the fixed
        // partOfSpeech categories — drop the now-unused table.
        await m.database.customStatement('DROP TABLE IF EXISTS word_tags');
      }
      if (from >= 3 && from < 6) {
        // Adds the English-learning/Japanese-learning mode tag. Existing
        // rows all predate this feature, so they default to 'enTarget'.
        // Guarded to from >= 3: upgrades starting below v3 already get this
        // column for free, since the `from < 3` branch above recreates
        // `words` via createTable() using the *current* (v6) table
        // definition — adding it again here would be a duplicate column.
        await m.addColumn(words, words.learningDirection);
      }
      if (from >= 3 && from < 7) {
        // Adds the kana reading captured from a JMdict lookup, used for
        // TTS instead of raw kanji (see japaneseReading doc comment).
        // Same from>=3 guard as learningDirection above, for the same
        // reason (the `from < 3` branch already gets this column for free).
        await m.addColumn(words, words.japaneseReading);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'english_learning.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
