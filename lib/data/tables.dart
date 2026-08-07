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
