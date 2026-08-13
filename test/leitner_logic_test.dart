// Covers the SM-2 spaced-repetition logic in WordRepository.recordAnswer()
// — this is the core scheduling behavior of the app, and a regression here
// would silently make review scheduling wrong without any visible error.
import 'package:drift/native.dart';
import 'package:english_learning/data/database.dart';
import 'package:english_learning/models/answer_quality.dart';
import 'package:english_learning/models/learning_direction.dart';
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

  Future<int> addTestWord() => repository.addWord(
    english: 'apple',
    japanese: 'りんご',
    learningDirection: LearningDirection.enTarget,
  );

  group('recordAnswer — SM-2 interval/repetition progression', () {
    test('first correct answer sets a 1-day interval', () async {
      final id = await addTestWord();

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.knew,
      );

      final word = await wordById(id);
      expect(word.srsRepetitions, 1);
      expect(word.srsInterval, 1);
      expect(word.lastReviewedAt, isNotNull);
    });

    test('second consecutive correct answer sets a 6-day interval', () async {
      final id = await addTestWord();

      for (var i = 0; i < 2; i++) {
        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          quality: AnswerQuality.knew,
        );
      }

      final word = await wordById(id);
      expect(word.srsRepetitions, 2);
      expect(word.srsInterval, 6);
    });

    test(
      'third+ correct answer multiplies the interval by the ease factor',
      () async {
        final id = await addTestWord();

        for (var i = 0; i < 2; i++) {
          await repository.recordAnswer(
            wordId: id,
            direction: ReviewDirection.enToJa,
            quality: AnswerQuality.knew,
          );
        }
        final afterTwo = await wordById(id);
        final easeAfterTwo = afterTwo.easeFactor;

        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          quality: AnswerQuality.knew,
        );

        final word = await wordById(id);
        expect(word.srsRepetitions, 3);
        expect(word.srsInterval, (6 * easeAfterTwo).round());
      },
    );

    test(
      '"わかった" (perfect recall) increases the ease factor',
      () async {
        final id = await addTestWord();

        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          quality: AnswerQuality.knew,
        );

        final word = await wordById(id);
        expect(word.easeFactor, greaterThan(2.5));
      },
    );

    test(
      '"悩んだがわかった" (barely-passing recall) decreases the ease factor',
      () async {
        final id = await addTestWord();

        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          quality: AnswerQuality.struggled,
        );

        final word = await wordById(id);
        expect(word.easeFactor, lessThan(2.5));
      },
    );

    test(
      'ease factor never drops below the 1.3 floor',
      () async {
        final id = await addTestWord();

        // Repeated bare passes push the ease factor down each time.
        for (var i = 0; i < 20; i++) {
          await repository.recordAnswer(
            wordId: id,
            direction: ReviewDirection.enToJa,
            quality: AnswerQuality.struggled,
          );
        }

        final word = await wordById(id);
        expect(word.easeFactor, greaterThanOrEqualTo(1.3));
      },
    );

    test(
      '"わからなかった" resets repetitions and interval, leaves ease factor untouched',
      () async {
        final id = await addTestWord();
        for (var i = 0; i < 3; i++) {
          await repository.recordAnswer(
            wordId: id,
            direction: ReviewDirection.enToJa,
            quality: AnswerQuality.knew,
          );
        }
        final beforeMiss = await wordById(id);
        expect(beforeMiss.srsRepetitions, greaterThan(0));

        await repository.recordAnswer(
          wordId: id,
          direction: ReviewDirection.enToJa,
          quality: AnswerQuality.didntKnow,
        );

        final word = await wordById(id);
        expect(word.srsRepetitions, 0);
        expect(word.srsInterval, 1);
        expect(word.easeFactor, beforeMiss.easeFactor);
      },
    );

    test('leitnerBox tier is derived from the current interval', () async {
      final id = await addTestWord();

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.knew,
      );
      // interval 1 day -> tier 1.
      expect((await wordById(id)).leitnerBox, 1);

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.knew,
      );
      // interval 6 days -> tier 3.
      expect((await wordById(id)).leitnerBox, 3);

      expect(minLeitnerBox, 1);
      expect(maxLeitnerBox, 5);
    });

    test('nextReviewDate matches the newly computed interval', () async {
      final id = await addTestWord();

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.knew,
      );

      final word = await wordById(id);
      final daysUntilReview = word.nextReviewDate!
          .difference(DateTime.now())
          .inDays;
      // Allow a 1-day slack for the test's own clock skew around midnight.
      expect(daysUntilReview, closeTo(word.srsInterval, 1));
    });

    test('records a ReviewLog entry for every answer', () async {
      final id = await addTestWord();

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.jaToEn,
        quality: AnswerQuality.knew,
      );

      final logs = await db.select(db.reviewLogs).get();
      expect(logs, hasLength(1));
      expect(logs.single.wordId, id);
      expect(logs.single.direction, ReviewDirection.jaToEn.value);
      expect(logs.single.isCorrect, isTrue);
    });

    test('a "struggled" answer is logged as correct', () async {
      final id = await addTestWord();

      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.struggled,
      );

      final logs = await db.select(db.reviewLogs).get();
      expect(logs.single.isCorrect, isTrue);
    });
  });

  group('findExactDuplicate', () {
    test('blocks re-registering the identical sense of a word', () async {
      await repository.addWord(
        english: 'play',
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
        learningDirection: LearningDirection.enTarget,
      );

      final duplicate = await repository.findExactDuplicate(
        english: 'PLAY', // case-insensitive
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
        learningDirection: LearningDirection.enTarget,
      );

      expect(duplicate, isNotNull);
    });

    test('allows a different sense of the same word (different POS)', () async {
      await repository.addWord(
        english: 'play',
        japanese: '遊ぶ',
        partOfSpeech: '動詞',
        learningDirection: LearningDirection.enTarget,
      );

      final duplicate = await repository.findExactDuplicate(
        english: 'play',
        japanese: '芝居',
        partOfSpeech: '名詞',
        learningDirection: LearningDirection.enTarget,
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
          learningDirection: LearningDirection.enTarget,
        );

        final duplicate = await repository.findExactDuplicate(
          english: 'play',
          japanese: '遊ぶ',
          partOfSpeech: '動詞',
          excludingId: id,
          learningDirection: LearningDirection.enTarget,
        );

        expect(duplicate, isNull);
      },
    );
  });

  group('due words', () {
    test('a never-reviewed word counts as due', () async {
      await repository.addWord(
        english: 'apple',
        japanese: 'りんご',
        learningDirection: LearningDirection.enTarget,
      );

      final due = await repository.selectSessionWords(
        direction: LearningDirection.enTarget,
        dueOnly: true,
      );
      expect(due, hasLength(1));
    });

    test('a word not due until the future is excluded', () async {
      final id = await addTestWord();
      // Answering correctly pushes nextReviewDate into the future.
      await repository.recordAnswer(
        wordId: id,
        direction: ReviewDirection.enToJa,
        quality: AnswerQuality.knew,
      );

      final due = await repository.selectSessionWords(
        direction: LearningDirection.enTarget,
        dueOnly: true,
      );
      expect(due, isEmpty);
    });
  });
}
