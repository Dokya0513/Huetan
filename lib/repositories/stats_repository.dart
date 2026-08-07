import 'package:flutter/material.dart';

import '../data/database.dart';

const int xpPerCorrectAnswer = 10;
const int xpPerLevel = 100;

/// XP is derived from review history (no dedicated column): every correct
/// flashcard answer is worth [xpPerCorrectAnswer] XP.
class StatsRepository {
  final AppDatabase db;
  StatsRepository(this.db);

  Stream<int> watchXp() {
    return (db.select(db.reviewLogs)..where((t) => t.isCorrect.equals(true)))
        .watch()
        .map((rows) => rows.length * xpPerCorrectAnswer);
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

class BadgeDef {
  final String id;
  final String title;
  final String description;
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
    title: 'はじめの一歩',
    description: '単語を1つ登録した',
    icon: Icons.edit_note,
    isUnlocked: (s) => s.wordCount >= 1,
  ),
  BadgeDef(
    id: 'word_50',
    title: '単語コレクター',
    description: '単語を50個登録した',
    icon: Icons.collections_bookmark,
    isUnlocked: (s) => s.wordCount >= 50,
  ),
  BadgeDef(
    id: 'word_100',
    title: '単語マスター',
    description: '単語を100個登録した',
    icon: Icons.workspace_premium,
    isUnlocked: (s) => s.wordCount >= 100,
  ),
  BadgeDef(
    id: 'streak_3',
    title: '3日坊主卒業',
    description: '3日連続で学習した',
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 3,
  ),
  BadgeDef(
    id: 'streak_7',
    title: '継続は力なり',
    description: '7日連続で学習した',
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 7,
  ),
  BadgeDef(
    id: 'streak_30',
    title: 'がんばり屋',
    description: '30日連続で学習した',
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streak >= 30,
  ),
  BadgeDef(
    id: 'correct_1',
    title: 'はじめての正解',
    description: '暗記カードで1問正解した',
    icon: Icons.check_circle,
    isUnlocked: (s) => s.correctCount >= 1,
  ),
  BadgeDef(
    id: 'correct_100',
    title: '百戦錬磨',
    description: '累計100問正解した',
    icon: Icons.military_tech,
    isUnlocked: (s) => s.correctCount >= 100,
  ),
];

List<BadgeProgress> evaluateBadges(StatsSnapshot snapshot) {
  return badgeDefinitions
      .map((def) => BadgeProgress(def, def.isUnlocked(snapshot)))
      .toList();
}
