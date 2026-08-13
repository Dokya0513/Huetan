import 'package:drift/drift.dart';

class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get english => text()();
  // Nullable so a word can be "quick added" with just the English text and
  // filled in with its meaning later.
  TextColumn get japanese => text().nullable()();
  TextColumn get exampleSentence => text().nullable()();
  TextColumn get partOfSpeech => text().nullable()();
  TextColumn get tag => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get leitnerBox => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  // Pronunciation audio URL fetched from the dictionary lookup, if any.
  TextColumn get audioUrl => text().nullable()();
  // Next scheduled review date for the spaced-repetition "due today" queue.
  DateTimeColumn get nextReviewDate => dateTime().nullable()();
  // Which language this word targets ('enTarget'/'jaTarget', see
  // LearningDirection) — stamped at creation, never changed afterward.
  TextColumn get learningDirection =>
      text().withDefault(const Constant('enTarget'))();
  // Kana reading for a jaTarget word's kanji spelling, from the JMdict
  // lookup — used for TTS instead of the raw kanji, since Japanese TTS
  // engines frequently mispronounce kanji with multiple valid readings
  // (e.g. 来る as "kitaru" instead of "kuru") without it. Null for words
  // entered without a dictionary lookup, or for enTarget words.
  TextColumn get japaneseReading => text().nullable()();
  // Additional example sentences beyond `exampleSentence`, from a
  // dictionary lookup that returned more than one — JSON-encoded
  // `List<String>`. Used to rotate through varied contexts on review
  // instead of always showing the same sentence. Null/empty when there's
  // only the one example (or none).
  TextColumn get extraExamples => text().nullable()();
  // SM-2 spaced-repetition state (see recordAnswer() in
  // word_repository.dart for the update rules). `leitnerBox` above is now
  // *derived* from `srsInterval` purely as a 1-5 display/sort tier for
  // existing UI (weak-word badges, session weighting) — it no longer
  // independently drives the review schedule.
  //
  // Ease factor ("EF"): how easily this word is remembered. Starts at
  // SM-2's standard 2.5 and only moves within [1.3, ...) — lower means the
  // interval grows more slowly after each correct answer.
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  // Consecutive correct-answer streak — resets to 0 on a "わからなかった"
  // answer, which is what routes recordAnswer() into the "start the ramp
  // over at 1 day" branch instead of interval * easeFactor.
  IntColumn get srsRepetitions => integer().withDefault(const Constant(0))();
  // Current SM-2 interval in days, used both to compute nextReviewDate and
  // as the base for the *next* interval (srsInterval * easeFactor).
  IntColumn get srsInterval => integer().withDefault(const Constant(0))();
}

class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wordId => integer().references(Words, #id)();
  DateTimeColumn get reviewedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get direction => text()();
  BoolColumn get isCorrect => boolean()();
}

/// Records that a given activity (app open / flashcard session) happened on
/// a given calendar day. `date` is always truncated to midnight, and at
/// most one row exists per (date, activityType) pair.
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get activityType => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, activityType},
  ];
}
