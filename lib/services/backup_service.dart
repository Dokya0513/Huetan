import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../data/database.dart';

/// Exports/imports the full local dataset (words + review logs + activity
/// logs) as a single JSON file. Review/activity logs are included, not
/// just words, so XP/level/streak/badges — all derived from those logs —
/// survive a restore too, not just the word list itself.
class BackupService {
  static const _formatVersion = 1;

  Future<Map<String, dynamic>> buildExport(AppDatabase db) async {
    final words = await db.select(db.words).get();
    final reviewLogs = await db.select(db.reviewLogs).get();
    final activityLogs = await db.select(db.activityLogs).get();

    return {
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'words': words.map(_wordToJson).toList(),
      'reviewLogs': reviewLogs.map(_reviewLogToJson).toList(),
      'activityLogs': activityLogs.map(_activityLogToJson).toList(),
    };
  }

  Future<void> saveToFile(String path, Map<String, dynamic> data) {
    final file = File(path);
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<Map<String, dynamic>> readFromFile(String path) async {
    final raw = await File(path).readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Replaces all existing words/review logs/activity logs with the
  /// contents of [data]. Wrapped in a transaction so a malformed file
  /// can't leave the database half-cleared.
  Future<void> importAndReplace(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    final words = (data['words'] as List).cast<Map<String, dynamic>>();
    final reviewLogs = (data['reviewLogs'] as List)
        .cast<Map<String, dynamic>>();
    final activityLogs = (data['activityLogs'] as List)
        .cast<Map<String, dynamic>>();

    await db.transaction(() async {
      await db.delete(db.reviewLogs).go();
      await db.delete(db.activityLogs).go();
      await db.delete(db.words).go();

      for (final w in words) {
        await db
            .into(db.words)
            .insert(_wordFromJson(w), mode: InsertMode.insertOrReplace);
      }
      for (final r in reviewLogs) {
        await db
            .into(db.reviewLogs)
            .insert(_reviewLogFromJson(r), mode: InsertMode.insertOrReplace);
      }
      for (final a in activityLogs) {
        await db
            .into(db.activityLogs)
            .insert(_activityLogFromJson(a), mode: InsertMode.insertOrReplace);
      }
    });
  }

  Map<String, dynamic> _wordToJson(Word w) => {
    'id': w.id,
    'english': w.english,
    'japanese': w.japanese,
    'exampleSentence': w.exampleSentence,
    'partOfSpeech': w.partOfSpeech,
    'createdAt': w.createdAt.toIso8601String(),
    'leitnerBox': w.leitnerBox,
    'lastReviewedAt': w.lastReviewedAt?.toIso8601String(),
    'audioUrl': w.audioUrl,
    'nextReviewDate': w.nextReviewDate?.toIso8601String(),
    'learningDirection': w.learningDirection,
    'japaneseReading': w.japaneseReading,
    'extraExamples': w.extraExamples,
    'easeFactor': w.easeFactor,
    'srsRepetitions': w.srsRepetitions,
    'srsInterval': w.srsInterval,
  };

  WordsCompanion _wordFromJson(Map<String, dynamic> j) => WordsCompanion(
    id: Value(j['id'] as int),
    english: Value(j['english'] as String),
    japanese: Value(j['japanese'] as String?),
    exampleSentence: Value(j['exampleSentence'] as String?),
    partOfSpeech: Value(j['partOfSpeech'] as String?),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
    leitnerBox: Value(j['leitnerBox'] as int),
    lastReviewedAt: Value(
      j['lastReviewedAt'] == null
          ? null
          : DateTime.parse(j['lastReviewedAt'] as String),
    ),
    audioUrl: Value(j['audioUrl'] as String?),
    nextReviewDate: Value(
      j['nextReviewDate'] == null
          ? null
          : DateTime.parse(j['nextReviewDate'] as String),
    ),
    // Older backups (pre-learning-mode) won't have this key — default to
    // enTarget, matching the schema column's own default for the same case.
    learningDirection: Value(j['learningDirection'] as String? ?? 'enTarget'),
    japaneseReading: Value(j['japaneseReading'] as String?),
    extraExamples: Value(j['extraExamples'] as String?),
    // Older backups (pre-SM-2) won't have these keys — default to the
    // column defaults for a never-reviewed word rather than trying to
    // back-derive them from leitnerBox here (the schema migration already
    // does that one-time backfill for the local DB; a restored backup from
    // before this feature existed just starts the SM-2 ramp fresh).
    easeFactor: Value((j['easeFactor'] as num?)?.toDouble() ?? 2.5),
    srsRepetitions: Value(j['srsRepetitions'] as int? ?? 0),
    srsInterval: Value(j['srsInterval'] as int? ?? 0),
  );

  Map<String, dynamic> _reviewLogToJson(ReviewLog r) => {
    'id': r.id,
    'wordId': r.wordId,
    'reviewedAt': r.reviewedAt.toIso8601String(),
    'direction': r.direction,
    'isCorrect': r.isCorrect,
  };

  ReviewLogsCompanion _reviewLogFromJson(Map<String, dynamic> j) =>
      ReviewLogsCompanion(
        id: Value(j['id'] as int),
        wordId: Value(j['wordId'] as int),
        reviewedAt: Value(DateTime.parse(j['reviewedAt'] as String)),
        direction: Value(j['direction'] as String),
        isCorrect: Value(j['isCorrect'] as bool),
      );

  Map<String, dynamic> _activityLogToJson(ActivityLog a) => {
    'id': a.id,
    'date': a.date.toIso8601String(),
    'activityType': a.activityType,
  };

  ActivityLogsCompanion _activityLogFromJson(Map<String, dynamic> j) =>
      ActivityLogsCompanion(
        id: Value(j['id'] as int),
        date: Value(DateTime.parse(j['date'] as String)),
        activityType: Value(j['activityType'] as String),
      );
}
