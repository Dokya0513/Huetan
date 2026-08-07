// Covers the Leitner box progression and due-date logic in
// WordRepository.recordAnswer() — this is the core spaced-repetition
// behavior of the app, and a regression here would silently make review
// scheduling wrong without any visible error.
import 'package:drift/native.dart';
import 'package:english_learning/data/database.dart';
import 'package:english_learning/repositories/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WordRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WordRepository(db);
  });

  tearDown(() => db.close());

  Future<Word> wordById(int id) =>
      (db.select(db.words)..where((t) => t.id.equals(id))).getSingle();

  group('recordAnswer — box progression', () {
    test('correct answer advances the box by 1', () async {
      final id = await repository.addWord(english: 'apple', japanese: 'りんご');

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        isCorrect: true,
      );

      final word = await wordById(id);
      expect(word.leitnerBox, 2);
      expect(word.lastReviewedAt, isNotNull);
    });

    test('correct answer never exceeds the max box', () async {
      final id = await repository.addWord(english: 'apple', japanese: 'りんご');

      for (var i = 0; i < 10; i++) {
        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          isCorrect: true,
        );
      }

      final word = await wordById(id);
      expect(word.leitnerBox, maxLeitnerBox);
    });

    test(
      'incorrect answer resets the box to 1 regardless of progress',
      () async {
        final id = await repository.addWord(english: 'apple', japanese: 'りんご');
        for (var i = 0; i < 3; i++) {
          await repository.recordAnswer(
            wordId: id,
            direction: ReviewDirection.enToJa,
            isCorrect: true,
          );
        }
        expect((await wordById(id)).leitnerBox, greaterThan(minLeitnerBox));

        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          isCorrect: false,
        );

        expect((await wordById(id)).leitnerBox, minLeitnerBox);
      },
    );

    test('nextReviewDate matches the interval for the new box', () async {
      final id = await repository.addWord(english: 'apple', japanese: 'りんご');

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        isCorrect: true,
      );

      final word = await wordById(id);
      final expectedInterval = reviewIntervalDays[word.leitnerBox]!;
      final daysUntilReview = word.nextReviewDate!
          .difference(DateTime.now())
          .inDays;
      // Allow a 1-day slack for the test's own clock skew around midnight.
      expect(daysUntilReview, closeTo(expectedInterval, 1));
    });

    test('records a ReviewLog entry for every answer', () async {
      final id = await repository.addWord(english: 'apple', japanese: 'りんご');

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.jaToEn,
        isCorrect: true,
      );

      final logs = await db.select(db.reviewLogs).get();
      expect(logs, hasLength(1));
      expect(logs.single.wordId, id);
      expect(logs.single.direction, ReviewDirection.jaToEn.value);
      expect(logs.single.isCorrect, isTrue);
    });
  });

  group('findExactDuplicate', () {
    test('blocks re-registering the identical sense of a word', () async {
      await repository.addWord(
        english: 'play',
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
      );

      final duplicate = await repository.findExactDuplicate(
        english: 'PLAY', // case-insensitive
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
      );

      expect(duplicate, isNotNull);
    });

    test('allows a different sense of the same word (different POS)', () async {
      await repository.addWord(
        english: 'play',
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
      );

      final duplicate = await repository.findExactDuplicate(
        english: 'play',
        japanese: '芝居',
        partOfSpeech: '名詞',
      );

      expect(duplicate, isNull);
    });

    test(
      'excludingId lets a word not collide with itself when editing',
      () async {
        final id = await repository.addWord(
          english: 'play',
          japanese: '遊ぶ',
          partOfSpeech: '動詞',
        );

        final duplicate = await repository.findExactDuplicate(
          english: 'play',
          japanese: '遊ぶ',
          partOfSpeech: '動詞',
          excludingId: id,
        );

        expect(duplicate, isNull);
      },
    );
  });

  group('due words', () {
    test('a never-reviewed word counts as due', () async {
      await repository.addWord(english: 'apple', japanese: 'りんご');

      final due = await repository.selectSessionWords(dueOnly: true);
      expect(due, hasLength(1));
    });

    test('a word not due until the future is excluded', () async {
      final id = await repository.addWord(english: 'apple', japanese: 'りんご');
      // Answering correctly pushes nextReviewDate into the future.
      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        isCorrect: true,
      );

      final due = await repository.selectSessionWords(dueOnly: true);
      expect(due, isEmpty);
    });
  });
}
