import 'package:drift/drift.dart';

import '../data/database.dart';

class TagRepository {
  final AppDatabase db;
  TagRepository(this.db);

  /// Distinct tag names in use, alphabetically — used for autocomplete
  /// suggestions when entering tags on a word.
  Future<List<String>> getAllTagNames() async {
    final query = db.selectOnly(db.wordTags, distinct: true)
      ..addColumns([db.wordTags.tag])
      ..orderBy([OrderingTerm.asc(db.wordTags.tag)]);
    final rows = await query.get();
    return rows.map((r) => r.read(db.wordTags.tag)!).toList();
  }

  Future<List<String>> getTagsForWord(int wordId) async {
    final rows = await (db.select(
      db.wordTags,
    )..where((t) => t.wordId.equals(wordId))).get();
    return rows.map((r) => r.tag).toList();
  }

  /// Replaces all of a word's tags with [tags] (empty/duplicate entries are
  /// dropped).
  Future<void> setTagsForWord(int wordId, List<String> tags) async {
    final cleaned = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    await db.transaction(() async {
      await (db.delete(
        db.wordTags,
      )..where((t) => t.wordId.equals(wordId))).go();
      for (final tag in cleaned) {
        await db.into(db.wordTags).insert(
          WordTagsCompanion.insert(wordId: wordId, tag: tag),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// All word-tag links, used to compute the genre distribution.
  Stream<List<WordTag>> watchAllWordTags() => db.select(db.wordTags).watch();
}

class TagCount {
  final String tag;
  final int count;
  const TagCount(this.tag, this.count);
}
