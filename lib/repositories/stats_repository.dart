import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/learning_direction.dart';

const int xpPerCorrectAnswer = 10;
const int xpPerLevel = 100;

/// XP is derived from review history (no dedicated column): every correct
/// flashcard answer is worth [xpPerCorrectAnswer] XP.
class StatsRepository {
  final AppDatabase db;
  StatsRepository(this.db);

  /// Joins through to Words rather than duplicating the mode tag onto
  /// ReviewLogs — learningDirection is immutable per word, so the join is
  /// always exact and needs no backfill.
  Stream<int> watchXp({required LearningDirection direction}) {
    final query =
        db.select(db.reviewLogs).join([
            innerJoin(db.words, db.words.id.equalsExp(db.reviewLogs.wordId)),
          ])
          ..where(
            db.reviewLogs.isCorrect.equals(true) &
                db.words.learningDirection.equals(direction.dbValue),
          );
    return query.watch().map((rows) => rows.length * xpPerCorrectAnswer);
  }
}

/// Level derived from total XP: every [xpPerLevel] XP is one level.
class LevelInfo {
  final int xp;
  const LevelInfo(this.xp);

  int get level => (xp ~/ xpPerLevel) + 1;
  int get xpIntoLevel => xp % xpPerLevel;
  double get progress => xpIntoLevel / xpPerLevel;
}

class StatsSnapshot {
  final int wordCount;
  final int streak;
  final int correctCount;
  const StatsSnapshot({
    required this.wordCount,
    required this.streak,
    required this.correctCount,
  });
}

/// [title]/[description] are closures rather than resolved [String]s because
/// [badgeDefinitions] is a top-level list built with no [BuildContext]
/// access — resolution happens wherever a badge is displayed instead.
class BadgeDef {
  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) description;
  final IconData icon;
  final bool Function(StatsSnapshot) isUnlocked;
  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

class BadgeProgress {
  final BadgeDef badge;
  final bool unlocked;
  const BadgeProgress(this.badge, this.unlocked);
}

final List<BadgeDef> badgeDefinitions = [
  BadgeDef(
    id: 'first_word',
    title: (l10n) => l10n.badgeFirstWordTitle,
    description: (l10n) => l10n.badgeFirstWordDescription,
    icon: Icons.edit_note,
    isUnlocked: (s) => s.wordCount >= 1,
  ),
  BadgeDef(
    id: 'word_50',
    title: (l10n) => l10n.badgeWord50Title,
    description: (l10n) => l10n.badgeWord50Description,
    icon: Icons.collections_bookmark,
    isUnlocked: (s) => s.wordCount >= 50,
  ),
  BadgeDef(
    id: 'word_100',
    title: (l10n) => l10n.badgeWord100Title,
    description: (l10n) => l10n.badgeWord100Description,
    icon: Icons.workspace_premium,
    isUnlocked: (s) => s.wordCount >= 100,
  ),
  BadgeDef(
    id: 'streak_3',
    title: (l10n) => l10n.badgeStreak3Title,
    description: (l10n) => l10n.badgeStreak3Description,
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 3,
  ),
  BadgeDef(
    id: 'streak_7',
    title: (l10n) => l10n.badgeStreak7Title,
    description: (l10n) => l10n.badgeStreak7Description,
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 7,
  ),
  BadgeDef(
    id: 'streak_30',
    title: (l10n) => l10n.badgeStreak30Title,
    description: (l10n) => l10n.badgeStreak30Description,
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 30,
  ),
  BadgeDef(
    id: 'correct_1',
    title: (l10n) => l10n.badgeCorrect1Title,
    description: (l10n) => l10n.badgeCorrect1Description,
    icon: Icons.check_circle,
    isUnlocked: (s) => s.correctCount >= 1,
  ),
  BadgeDef(
    id: 'correct_100',
    title: (l10n) => l10n.badgeCorrect100Title,
    description: (l10n) => l10n.badgeCorrect100Description,
    icon: Icons.military_tech,
    isUnlocked: (s) => s.correctCount >= 100,
  ),
];

List<BadgeProgress> evaluateBadges(StatsSnapshot snapshot) {
  return badgeDefinitions
      .map((def) => BadgeProgress(def, def.isUnlocked(snapshot)))
      .toList();
}
