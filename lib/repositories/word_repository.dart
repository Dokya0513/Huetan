import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../models/answer_quality.dart';
import '../models/learning_direction.dart';
import 'activity_repository.dart' show dateOnly;

/// Leitner box range: lower box = weaker word = shown more often. The box
/// itself no longer drives scheduling (see recordAnswer()'s SM-2 logic) —
/// it's now a display/sorting-only tier derived from the current SM-2
/// interval via [_tierForInterval], kept so the weak-word badges, sort
/// order, and session-weighting logic below don't need to change.
const int minLeitnerBox = 1;
const int maxLeitnerBox = 5;

/// Interval-in-days breakpoints for deriving [Word.leitnerBox] from the
/// SM-2 interval — mirrors the old fixed per-box schedule's boundaries, so
/// the resulting tier reads the same way it always has (1=weakest/just
/// missed, 5=strongest/reviewed a month-plus out).
int _tierForInterval(int intervalDays) {
  if (intervalDays <= 1) return 1;
  if (intervalDays <= 3) return 2;
  if (intervalDays <= 7) return 3;
  if (intervalDays <= 14) return 4;
  return 5;
}

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

  Stream<List<Word>> watchAllWords({required LearningDirection direction}) {
    return (db.select(db.words)
          ..where((t) => t.learningDirection.equals(direction.dbValue))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Word>> getAllWords({required LearningDirection direction}) =>
      (db.select(
        db.words,
      )..where((t) => t.learningDirection.equals(direction.dbValue))).get();

  /// Base query for words that can be quizzed (have a meaning filled in on
  /// their mode's target-language side), optionally restricted to ones due
  /// for review today or earlier (including never-reviewed words, whose
  /// `nextReviewDate` is null) and/or to a specific part of speech.
  SimpleSelectStatement<$WordsTable, Word> _quizzableQuery({
    required LearningDirection direction,
    bool dueOnly = false,
    String? partOfSpeech,
  }) {
    final query = db.select(db.words)
      ..where((t) => t.learningDirection.equals(direction.dbValue));
    if (direction == LearningDirection.enTarget) {
      query.where((t) => t.japanese.isNotNull());
    } else {
      // english is NOT NULL at the schema level, so a jaTarget quick-add
      // with its meaning left blank stores '' rather than null — matching
      // that here, the same way the enTarget branch above checks for an
      // unset (null) japanese meaning.
      query.where((t) => t.english.equals('').not());
    }
    if (dueOnly) {
      final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
      query.where(
        (t) =>
            t.nextReviewDate.isNull() |
            t.nextReviewDate.isSmallerThanValue(tomorrow),
      );
    }
    if (partOfSpeech != null) {
      query.where((t) => t.partOfSpeech.equals(partOfSpeech));
    }
    return query;
  }

  /// Words due for review today (or never reviewed yet).
  Stream<List<Word>> watchDueWords({required LearningDirection direction}) =>
      _quizzableQuery(direction: direction, dueOnly: true).watch();

  /// Adds a word. [japanese] may be left null for a "quick add" entry whose
  /// meaning will be filled in later (enTarget mode only — see
  /// LearningDirection); such words are excluded from flashcard sessions
  /// until a meaning is set. [learningDirection] is stamped once at
  /// creation and never changes afterward.
  Future<int> addWord({
    required String english,
    String? japanese,
    String? exampleSentence,
    List<String>? extraExamples,
    String? partOfSpeech,
    String? audioUrl,
    String? japaneseReading,
    required LearningDirection learningDirection,
  }) {
    return db
        .into(db.words)
        .insert(
          WordsCompanion.insert(
            english: english,
            japanese: Value(japanese),
            exampleSentence: Value(exampleSentence),
            extraExamples: Value(_encodeExtraExamples(extraExamples)),
            partOfSpeech: Value(partOfSpeech),
            audioUrl: Value(audioUrl),
            japaneseReading: Value(japaneseReading),
            learningDirection: Value(learningDirection.dbValue),
          ),
        );
  }

  Future<void> updateWord({
    required int id,
    required String english,
    String? japanese,
    String? exampleSentence,
    List<String>? extraExamples,
    String? partOfSpeech,
    String? audioUrl,
    String? japaneseReading,
  }) {
    return (db.update(db.words)..where((t) => t.id.equals(id))).write(
      WordsCompanion(
        english: Value(english),
        japanese: Value(japanese),
        exampleSentence: Value(exampleSentence),
        extraExamples: Value(_encodeExtraExamples(extraExamples)),
        partOfSpeech: Value(partOfSpeech),
        audioUrl: Value(audioUrl),
        japaneseReading: Value(japaneseReading),
      ),
    );
  }

  String? _encodeExtraExamples(List<String>? examples) =>
      (examples == null || examples.isEmpty) ? null : jsonEncode(examples);

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
    required LearningDirection learningDirection,
  }) async {
    final normalizedEnglish = english.trim().toLowerCase();
    final all = await (db.select(db.words)..where(
          (t) => t.learningDirection.equals(learningDirection.dbValue),
        ))
        .get();
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
    List<String>? extraExamples,
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
        extraExamples: word.exampleSentence == null && exampleSentence != null
            ? Value(_encodeExtraExamples(extraExamples))
            : const Value.absent(),
        audioUrl: word.audioUrl == null && audioUrl != null
            ? Value(audioUrl)
            : const Value.absent(),
      ),
    );
  }

  /// Picks words for a flashcard session.
  ///
  /// [partOfSpeech] filters at the database level (an exact match on the
  /// stored label). [extraFilter], if given, is applied afterward in Dart —
  /// used for criteria that aren't stored columns, e.g. a word's CEFR level
  /// (computed at runtime from the bundled wordlist) or whether its example
  /// sentence actually contains the word (needed for the fill-in-the-blank
  /// quiz mode).
  ///
  /// If [count] is null or >= the number of available words, all words are
  /// returned in random order. Otherwise a weighted random sample (without
  /// replacement) is drawn, favoring words with a lower Leitner box (i.e.
  /// words the user gets wrong more often) so weak words appear more.
  Future<List<Word>> selectSessionWords({
    required LearningDirection direction,
    int? count,
    bool dueOnly = false,
    String? partOfSpeech,
    bool Function(Word word)? extraFilter,
  }) async {
    var all = await _quizzableQuery(
      direction: direction,
      dueOnly: dueOnly,
      partOfSpeech: partOfSpeech,
    ).get();
    if (extraFilter != null) {
      all = all.where(extraFilter).toList();
    }
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
    }).toList()..sort((a, b) => b.key.compareTo(a.key));

    return keyed.take(count).map((e) => e.value).toList();
  }

  /// Records the result of answering [wordId] in the given [direction]
  /// using the SM-2 spaced-repetition algorithm: [quality] < 3 (didntKnow)
  /// resets the streak and drops the interval back to 1 day; quality >= 3
  /// extends it (1 day -> 6 days -> previous interval * ease factor), and
  /// nudges the ease factor up or down depending on how easy the recall
  /// was. Also updates the derived Leitner-box display tier and logs the
  /// attempt.
  Future<void> recordAnswer({
    required int wordId,
    required ReviewDirection direction,
    required AnswerQuality quality,
  }) async {
    final word = await (db.select(
      db.words,
    )..where((t) => t.id.equals(wordId))).getSingle();

    final q = quality.value;
    int repetitions;
    int interval;
    double ease;
    if (q < 3) {
      repetitions = 0;
      interval = 1;
      ease = word.easeFactor; // SM-2 leaves EF untouched on a miss.
    } else {
      repetitions = word.srsRepetitions + 1;
      if (repetitions <= 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (word.srsInterval * word.easeFactor).round();
      }
      ease = word.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
      if (ease < 1.3) ease = 1.3;
    }

    final newBox = _tierForInterval(interval);
    final nextReviewDate = dateOnly(
      DateTime.now(),
    ).add(Duration(days: interval));

    await (db.update(db.words)..where((t) => t.id.equals(wordId))).write(
      WordsCompanion(
        leitnerBox: Value(newBox),
        easeFactor: Value(ease),
        srsRepetitions: Value(repetitions),
        srsInterval: Value(interval),
        lastReviewedAt: Value(DateTime.now()),
        nextReviewDate: Value(nextReviewDate),
      ),
    );

    await db
        .into(db.reviewLogs)
        .insert(
          ReviewLogsCompanion.insert(
            wordId: wordId,
            direction: direction.value,
            isCorrect: quality.isCorrect,
          ),
        );
  }

  /// All review attempts ever logged — used to compute per-day activity
  /// stats (e.g. distinct words reviewed per day) for the calendar screen.
  Stream<List<ReviewLog>> watchReviewLogs() {
    return db.select(db.reviewLogs).watch();
  }

  /// Words ordered from weakest (lowest box) to strongest. Never-reviewed
  /// words are excluded — a freshly added word defaults to the lowest box,
  /// but that reflects "no data yet," not an actual weakness.
  Stream<List<Word>> watchWeakWords({
    required LearningDirection direction,
    int limit = 100,
  }) {
    return (db.select(db.words)
          ..where(
            (t) =>
                t.lastReviewedAt.isNotNull() &
                t.learningDirection.equals(direction.dbValue),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.leitnerBox)])
          ..limit(limit))
        .watch();
  }
}
