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
  int get schemaVersion => 9;

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
      if (from >= 3 && from < 8) {
        // Adds storage for extra example sentences beyond the primary one,
        // for rotating through varied contexts on review. Same from>=3
        // guard as the columns above, for the same reason.
        await m.addColumn(words, words.extraExamples);
      }
      if (from >= 3 && from < 9) {
        // Switches the review scheduler from fixed per-box intervals to
        // SM-2 (ease factor / repetitions / interval) — see tables.dart's
        // doc comments on these columns. Same from>=3 guard as above.
        await m.addColumn(words, words.easeFactor);
        await m.addColumn(words, words.srsRepetitions);
        await m.addColumn(words, words.srsInterval);
      }
      if (from < 9) {
        // Backfill from the pre-SM-2 Leitner box for words already in
        // progress, so their next review doesn't cold-start back at a
        // 1-day interval — only genuinely new/unreviewed words stay at
        // the column defaults (interval 0, repetitions 0). Deliberately
        // NOT guarded by from>=3 like the addColumn calls above: an
        // upgrade starting below v3 already has these columns (the
        // `from < 3` branch's recreate uses the current, v9+ table
        // shape) but still needs this same backfill run against them.
        await m.database.customStatement('''
              UPDATE words
              SET srs_interval = CASE leitner_box
                    WHEN 1 THEN 1 WHEN 2 THEN 3 WHEN 3 THEN 7
                    WHEN 4 THEN 14 ELSE 30 END,
                  srs_repetitions = leitner_box
              WHERE last_reviewed_at IS NOT NULL
            ''');
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
