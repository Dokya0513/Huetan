import 'dart:math';

import 'package:drift/drift.dart';

import '../data/database.dart';
import 'activity_repository.dart' show dateOnly;

/// Leitner box range: lower box = weaker word = shown more often.
const int minLeitnerBox = 1;
const int maxLeitnerBox = 5;

/// Days until the next review, keyed by the Leitner box the word just
/// landed in. Mimics a simple spaced-repetition schedule.
const Map<int, int> reviewIntervalDays = {1: 1, 2: 3, 3: 7, 4: 14, 5: 30};

enum ReviewDirection {
  enToJa('en2ja'),
  jaToEn('ja2en');

  final String value;
  const ReviewDirection(this.value);

  static ReviewDirection fromValue(String value) =>
      values.firstWhere((d) => d.value == value);
}

class WordRepository {
  final AppDatabase db;
  WordRepository(this.db);

  Stream<List<Word>> watchAllWords() {
    return (db.select(db.words)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Word>> getAllWords() => db.select(db.words).get();

  /// Base query for words that can be quizzed (have a Japanese meaning),
  /// optionally restricted to ones due for review today or earlier
  /// (including never-reviewed words, whose `nextReviewDate` is null).
  SimpleSelectStatement<$WordsTable, Word> _quizzableQuery({
    bool dueOnly = false,
  }) {
    final query = db.select(db.words)
      ..where((t) => t.japanese.isNotNull());
    if (dueOnly) {
      final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
      query.where(
        (t) =>
            t.nextReviewDate.isNull() |
            t.nextReviewDate.isSmallerThanValue(tomorrow),
      );
    }
    return query;
  }

  /// Words due for review today (or never reviewed yet).
  Stream<List<Word>> watchDueWords() => _quizzableQuery(dueOnly: true).watch();

  /// Adds a word. [japanese] may be left null for a "quick add" entry whose
  /// meaning will be filled in later; such words are excluded from
  /// flashcard sessions until a meaning is set.
  Future<int> addWord({
    required String english,
    String? japanese,
    String? exampleSentence,
    String? partOfSpeech,
    String? audioUrl,
  }) {
    return db.into(db.words).insert(
          WordsCompanion.insert(
            english: english,
            japanese: Value(japanese),
            exampleSentence: Value(exampleSentence),
            partOfSpeech: Value(partOfSpeech),
            audioUrl: Value(audioUrl),
          ),
        );
  }

  Future<void> updateWord({
    required int id,
    required String english,
    String? japanese,
    String? exampleSentence,
    String? partOfSpeech,
    String? audioUrl,
  }) {
    return (db.update(db.words)..where((t) => t.id.equals(id))).write(
      WordsCompanion(
        english: Value(english),
        japanese: Value(japanese),
        exampleSentence: Value(exampleSentence),
        partOfSpeech: Value(partOfSpeech),
        audioUrl: Value(audioUrl),
      ),
    );
  }

  Future<void> deleteWord(int id) =>
      (db.delete(db.words)..where((t) => t.id.equals(id))).go();

  /// Finds an existing word whose english/japanese/partOfSpeech all match
  /// exactly (english compared case/whitespace-insensitively) — used to
  /// block accidental re-entry of the *same* sense of a word, while still
  /// allowing the same english spelling to be registered again under a
  /// different meaning/part of speech (e.g. "play" as a noun vs. a verb).
  Future<Word?> findExactDuplicate({
    required String english,
    String? japanese,
    String? partOfSpeech,
    int? excludingId,
  }) async {
    final normalizedEnglish = english.trim().toLowerCase();
    final all = await db.select(db.words).get();
    for (final word in all) {
      if (excludingId != null && word.id == excludingId) continue;
      if (word.english.trim().toLowerCase() != normalizedEnglish) continue;
      if (word.japanese != japanese) continue;
      if (word.partOfSpeech != partOfSpeech) continue;
      return word;
    }
    return null;
  }

  /// Fills partOfSpeech/exampleSentence/audioUrl for [id] only where those
  /// fields are still empty — used to backfill quick-added words from a
  /// background dictionary lookup without clobbering anything the user may
  /// have already typed by hand in the meantime.
  Future<void> fillDictionaryFieldsIfEmpty({
    required int id,
    String? partOfSpeech,
    String? exampleSentence,
    String? audioUrl,
  }) async {
    final word = await (db.select(
      db.words,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (word == null) return;

    await (db.update(db.words)..where((t) => t.id.equals(id))).write(
      WordsCompanion(
        partOfSpeech: word.partOfSpeech == null && partOfSpeech != null
            ? Value(partOfSpeech)
            : const Value.absent(),
        exampleSentence: word.exampleSentence == null && exampleSentence != null
            ? Value(exampleSentence)
            : const Value.absent(),
        audioUrl: word.audioUrl == null && audioUrl != null
            ? Value(audioUrl)
            : const Value.absent(),
      ),
    );
  }

  /// Picks words for a flashcard session.
  ///
  /// If [count] is null or >= the number of available words, all words are
  /// returned in random order. Otherwise a weighted random sample (without
  /// replacement) is drawn, favoring words with a lower Leitner box (i.e.
  /// words the user gets wrong more often) so weak words appear more.
  Future<List<Word>> selectSessionWords({
    int? count,
    bool dueOnly = false,
  }) async {
    final all = await _quizzableQuery(dueOnly: dueOnly).get();
    if (count == null || count >= all.length) {
      final shuffled = List<Word>.from(all)..shuffle();
      return shuffled;
    }

    final rand = Random();
    // Efraimidis-Spirakis weighted reservoir sampling: draw a key
    // random()^(1/weight) per item and take the top `count` keys.
    final keyed = all.map((word) {
      final weight = (maxLeitnerBox + 1 - word.leitnerBox)
          .clamp(1, maxLeitnerBox)
          .toDouble();
      final key = pow(rand.nextDouble(), 1 / weight).toDouble();
      return MapEntry(key, word);
    }).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return keyed.take(count).map((e) => e.value).toList();
  }

  /// Records the result of answering [wordId] in the given [direction],
  /// updates its Leitner box (correct -> +1, incorrect -> reset to 1),
  /// and logs the attempt.
  Future<void> recordAnswer({
    required int wordId,
    required ReviewDirection direction,
    required bool isCorrect,
  }) async {
    final word =
        await (db.select(db.words)..where((t) => t.id.equals(wordId)))
            .getSingle();
    final newBox = isCorrect
        ? (word.leitnerBox + 1).clamp(minLeitnerBox, maxLeitnerBox)
        : minLeitnerBox;
    final nextReviewDate = dateOnly(
      DateTime.now(),
    ).add(Duration(days: reviewIntervalDays[newBox] ?? 1));

    await (db.update(db.words)..where((t) => t.id.equals(wordId))).write(
      WordsCompanion(
        leitnerBox: Value(newBox),
        lastReviewedAt: Value(DateTime.now()),
        nextReviewDate: Value(nextReviewDate),
      ),
    );

    await db.into(db.reviewLogs).insert(
          ReviewLogsCompanion.insert(
            wordId: wordId,
            direction: direction.value,
            isCorrect: isCorrect,
          ),
        );
  }

  /// Words ordered from weakest (lowest box) to strongest. Never-reviewed
  /// words are excluded — a freshly added word defaults to the lowest box,
  /// but that reflects "no data yet," not an actual weakness.
  Stream<List<Word>> watchWeakWords({int limit = 100}) {
    return (db.select(db.words)
          ..where((t) => t.lastReviewedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.leitnerBox)])
          ..limit(limit))
        .watch();
  }
}
