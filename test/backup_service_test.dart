// Covers BackupService's export/import round trip. A prior regression here
// silently dropped `learningDirection`/`japaneseReading` from the exported
// JSON, so restoring a backup reset every Japanese-learning word back to
// English-learning mode with no error or warning — this test exists so that
// exact failure mode can't reoccur unnoticed.
import 'package:drift/native.dart';
import 'package:english_learning/data/database.dart';
import 'package:english_learning/models/learning_direction.dart';
import 'package:english_learning/repositories/word_repository.dart';
import 'package:english_learning/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase sourceDb;
  late AppDatabase targetDb;
  late WordRepository sourceRepo;
  final backupService = BackupService();

  setUp(() {
    sourceDb = AppDatabase.forTesting(NativeDatabase.memory());
    targetDb = AppDatabase.forTesting(NativeDatabase.memory());
    sourceRepo = WordRepository(sourceDb);
  });

  tearDown(() async {
    await sourceDb.close();
    await targetDb.close();
  });

  test(
    'export then import preserves every word field, including '
    'learningDirection and japaneseReading',
    () async {
      final enId = await sourceRepo.addWord(
        english: 'apple',
        japanese: 'りんご',
        exampleSentence: 'I ate an apple.',
        partOfSpeech: '名詞',
        audioUrl: 'https://example.com/apple.mp3',
        learningDirection: LearningDirection.enTarget,
      );
      final jaId = await sourceRepo.addWord(
        english: 'to come',
        japanese: '来る',
        japaneseReading: 'くる',
        learningDirection: LearningDirection.jaTarget,
      );

      await sourceRepo.recordAnswer(
        wordId: enId,
        direction: ReviewDirection.enToJa,
        isCorrect: true,
      );

      final data = await backupService.buildExport(sourceDb);
      await backupService.importAndReplace(targetDb, data);

      final imported = await targetDb.select(targetDb.words).get();
      expect(imported, hasLength(2));

      final enWord = imported.firstWhere((w) => w.id == enId);
      expect(enWord.english, 'apple');
      expect(enWord.japanese, 'りんご');
      expect(enWord.exampleSentence, 'I ate an apple.');
      expect(enWord.partOfSpeech, '名詞');
      expect(enWord.audioUrl, 'https://example.com/apple.mp3');
      expect(enWord.learningDirection, LearningDirection.enTarget.dbValue);
      // The critical regression case: a jaTarget word must round-trip as
      // jaTarget, not silently fall back to the enTarget column default.
      final jaWord = imported.firstWhere((w) => w.id == jaId);
      expect(jaWord.japanese, '来る');
      expect(jaWord.japaneseReading, 'くる');
      expect(jaWord.learningDirection, LearningDirection.jaTarget.dbValue);

      final importedLogs = await targetDb.select(targetDb.reviewLogs).get();
      expect(importedLogs, hasLength(1));
      expect(importedLogs.single.wordId, enId);
      expect(importedLogs.single.isCorrect, isTrue);
    },
  );

  test(
    'importing a backup missing learningDirection/japaneseReading keys '
    '(pre-learning-mode backup) defaults to enTarget rather than throwing',
    () async {
      // A hand-built backup file shaped like one exported before
      // learningDirection/japaneseReading existed — those keys are simply
      // absent, not null, from the JSON.
      final legacyBackup = {
        'formatVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'words': [
          {
            'id': 1,
            'english': 'legacy',
            'japanese': 'レガシー',
            'exampleSentence': null,
            'partOfSpeech': null,
            'createdAt': DateTime.now().toIso8601String(),
            'leitnerBox': 1,
            'lastReviewedAt': null,
            'audioUrl': null,
            'nextReviewDate': null,
          },
        ],
        'reviewLogs': [],
        'activityLogs': [],
      };

      await backupService.importAndReplace(targetDb, legacyBackup);

      final imported = await targetDb.select(targetDb.words).get();
      expect(imported, hasLength(1));
      expect(
        imported.single.learningDirection,
        LearningDirection.enTarget.dbValue,
      );
      expect(imported.single.japaneseReading, isNull);
    },
  );
}
