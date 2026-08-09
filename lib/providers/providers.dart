import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/database.dart';
import '../models/cefr_level.dart';
import '../models/character_advice.dart';
import '../models/jlpt_level.dart';
import '../models/learning_direction.dart';
import '../models/part_of_speech.dart';
import '../models/word_display.dart';
import '../repositories/activity_repository.dart';
import '../repositories/stats_repository.dart';
import '../repositories/word_repository.dart';
import '../services/backup_service.dart';
import '../services/badge_unlock_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/friends_service.dart';
import '../services/cefr_service.dart';
import '../services/jlpt_service.dart';
import '../services/pronunciation_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../services/update_check_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return WordRepository(ref.watch(databaseProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(databaseProvider));
});

final allWordsProvider = StreamProvider<List<Word>>((ref) {
  return ref
      .watch(wordRepositoryProvider)
      .watchAllWords(direction: ref.watch(learningModeProvider));
});

final weakWordsProvider = StreamProvider<List<Word>>((ref) {
  return ref
      .watch(wordRepositoryProvider)
      .watchWeakWords(direction: ref.watch(learningModeProvider));
});

final dueWordsProvider = StreamProvider<List<Word>>((ref) {
  return ref
      .watch(wordRepositoryProvider)
      .watchDueWords(direction: ref.watch(learningModeProvider));
});

final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  return ref.watch(activityRepositoryProvider).watchActivityLogs();
});

final streakProvider = FutureProvider.autoDispose<int>((ref) {
  // Re-run whenever activity logs change so the streak stays fresh.
  ref.watch(activityLogsProvider);
  return ref.watch(activityRepositoryProvider).currentStreak();
});

final reviewLogsProvider = StreamProvider<List<ReviewLog>>((ref) {
  return ref.watch(wordRepositoryProvider).watchReviewLogs();
});

/// One day's worth of activity for the calendar's input/output chart:
/// [added] = words registered that day, [reviewed] = distinct words
/// reviewed that day (a word reviewed twice in one day still counts once).
class DailyActivityCount {
  final DateTime day;
  final int added;
  final int reviewed;
  const DailyActivityCount(this.day, this.added, this.reviewed);
}

final dailyActivityCountsProvider = Provider<List<DailyActivityCount>>((ref) {
  final words = ref.watch(allWordsProvider).value ?? [];
  final reviewLogs = ref.watch(reviewLogsProvider).value ?? [];

  final today = dateOnly(DateTime.now());
  final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

  final addedByDay = <DateTime, int>{};
  for (final word in words) {
    final day = dateOnly(word.createdAt);
    addedByDay[day] = (addedByDay[day] ?? 0) + 1;
  }

  // `words` is already scoped to the current learning mode; restrict the
  // (mode-agnostic) review logs to just those words' ids so a review of a
  // word from the other mode doesn't get counted here.
  final modeWordIds = words.map((w) => w.id).toSet();
  final reviewedByDay = <DateTime, Set<int>>{};
  for (final log in reviewLogs) {
    if (!modeWordIds.contains(log.wordId)) continue;
    final day = dateOnly(log.reviewedAt);
    reviewedByDay.putIfAbsent(day, () => {}).add(log.wordId);
  }

  return [
    for (final day in days)
      DailyActivityCount(
        day,
        addedByDay[day] ?? 0,
        reviewedByDay[day]?.length ?? 0,
      ),
  ];
});

final pronunciationServiceProvider = Provider<PronunciationService>((ref) {
  final service = PronunciationService();
  ref.onDispose(service.dispose);
  return service;
});

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService();
});

/// Checked once per app session (FutureProvider caches its result). Null
/// means either no update is available or the check failed/was skipped —
/// callers don't distinguish between those, since this is a best-effort,
/// non-critical notice.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return ref.watch(updateCheckServiceProvider).checkForUpdate(info.version);
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(databaseProvider));
});

final xpProvider = StreamProvider<int>((ref) {
  return ref
      .watch(statsRepositoryProvider)
      .watchXp(direction: ref.watch(learningModeProvider));
});

final levelInfoProvider = Provider<LevelInfo>((ref) {
  final xp = ref.watch(xpProvider).value ?? 0;
  return LevelInfo(xp);
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  return CloudBackupService();
});

final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService();
});

class VolumeNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  final VolumeChannel _channel;
  VolumeNotifier(this._settingsService, this._channel) : super(defaultVolume) {
    _load();
  }

  Future<void> _load() async {
    state = await _settingsService.loadVolume(_channel);
  }

  Future<void> setVolume(double volume) async {
    state = volume;
    await _settingsService.saveVolume(_channel, volume);
  }
}

final seVolumeProvider = StateNotifierProvider<VolumeNotifier, double>((ref) {
  return VolumeNotifier(
    ref.watch(settingsServiceProvider),
    VolumeChannel.soundEffect,
  );
});

final voiceVolumeProvider = StateNotifierProvider<VolumeNotifier, double>((
  ref,
) {
  return VolumeNotifier(
    ref.watch(settingsServiceProvider),
    VolumeChannel.voice,
  );
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsService _settingsService;
  ThemeModeNotifier(this._settingsService) : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final isDark = await _settingsService.loadDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    await _settingsService.saveDarkMode(isDark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(settingsServiceProvider));
});

class LearningModeNotifier extends StateNotifier<LearningDirection> {
  final SettingsService _settingsService;
  LearningModeNotifier(this._settingsService)
    : super(LearningDirection.enTarget) {
    _load();
  }

  Future<void> _load() async {
    state = await _settingsService.loadLearningMode();
  }

  Future<void> setMode(LearningDirection mode) async {
    state = mode;
    await _settingsService.saveLearningMode(mode);
  }
}

final learningModeProvider =
    StateNotifierProvider<LearningModeNotifier, LearningDirection>((ref) {
      return LearningModeNotifier(ref.watch(settingsServiceProvider));
    });

/// Locale forced by the current learning mode: enTarget (JP speaker
/// learning English) forces Japanese UI, jaTarget (EN speaker learning
/// Japanese) forces English UI. Settings/Onboarding override this locally
/// back to the system locale — see lib/l10n/locale_utils.dart.
final effectiveLocaleProvider = Provider<Locale>((ref) {
  final mode = ref.watch(learningModeProvider);
  return mode == LearningDirection.enTarget
      ? const Locale('ja')
      : const Locale('en');
});

final characterAdviceCandidatesProvider = Provider<List<CharacterAdvice>>((
  ref,
) {
  final wordCount = ref.watch(allWordsProvider).value?.length ?? 0;
  final streak = ref.watch(streakProvider).value ?? 0;
  final dueCount = ref.watch(dueWordsProvider).value?.length ?? 0;
  final weakCount =
      ref
          .watch(weakWordsProvider)
          .value
          ?.where((w) => w.leitnerBox <= 2)
          .length ??
      0;
  return characterAdviceCandidates(
    wordCount: wordCount,
    streak: streak,
    dueCount: dueCount,
    weakCount: weakCount,
    currentHour: DateTime.now().hour,
    genreInsight: ref.watch(genreInsightProvider),
  );
});

/// Threshold below which a part-of-speech category is considered "too small
/// a sample" to base balance/weakness comments on.
const _minPosSampleForInsight = 3;

final genreInsightProvider = Provider<GenreInsight>((ref) {
  final words = ref.watch(allWordsProvider).value ?? [];
  final posCounts = ref.watch(posDistributionProvider);

  PartOfSpeech? dominantPos;
  PartOfSpeech? sparsePos;
  var balanced = false;
  if (posCounts.length >= _minPosSampleForInsight) {
    final total = posCounts.fold<int>(0, (sum, t) => sum + t.count);
    final max = posCounts.reduce((a, b) => a.count > b.count ? a : b);
    final min = posCounts.reduce((a, b) => a.count < b.count ? a : b);
    if (max.count / total >= 0.5) {
      dominantPos = max.pos;
      sparsePos = min.pos;
    } else if (max.count - min.count <= 1) {
      balanced = true;
    }
  }

  final posTotals = <PartOfSpeech, int>{};
  final posWeakCounts = <PartOfSpeech, int>{};
  for (final word in words) {
    if (word.partOfSpeech == null) continue;
    final pos = mapToPartOfSpeech(word.partOfSpeech!);
    posTotals[pos] = (posTotals[pos] ?? 0) + 1;
    if (word.leitnerBox <= 2) {
      posWeakCounts[pos] = (posWeakCounts[pos] ?? 0) + 1;
    }
  }
  PartOfSpeech? weakPos;
  var bestWeakRatio = 0.0;
  posTotals.forEach((pos, total) {
    if (total < _minPosSampleForInsight) return;
    final ratio = (posWeakCounts[pos] ?? 0) / total;
    if (ratio >= 0.5 && ratio > bestWeakRatio) {
      bestWeakRatio = ratio;
      weakPos = pos;
    }
  });

  return GenreInsight(
    weakPos: weakPos,
    dominantPos: dominantPos,
    sparsePos: sparsePos,
    balanced: balanced,
  );
});

final calendarAdviceCandidatesProvider = Provider<List<CharacterAdvice>>((ref) {
  final logs = ref.watch(activityLogsProvider).value ?? [];
  final streak = ref.watch(streakProvider).value ?? 0;

  final thirtyDaysAgo = dateOnly(
    DateTime.now().subtract(const Duration(days: 30)),
  );
  final allActiveDays = <DateTime>{};
  final recentActiveDays = <DateTime>{};
  for (final log in logs) {
    final day = dateOnly(log.date);
    allActiveDays.add(day);
    if (!day.isBefore(thirtyDaysAgo)) {
      recentActiveDays.add(day);
    }
  }

  return calendarAdviceCandidates(
    streak: streak,
    activeDaysLast30: recentActiveDays.length,
    totalActiveDays: allActiveDays.length,
  );
});

class PosCount {
  final PartOfSpeech? pos;
  final int count;
  const PosCount(this.pos, this.count);
}

final posDistributionProvider = Provider<List<PosCount>>((ref) {
  final words = ref.watch(allWordsProvider).value ?? [];

  final counts = <PartOfSpeech, int>{};
  var unsetCount = 0;
  for (final word in words) {
    if (word.partOfSpeech == null) {
      unsetCount++;
      continue;
    }
    final pos = mapToPartOfSpeech(word.partOfSpeech!);
    counts[pos] = (counts[pos] ?? 0) + 1;
  }

  final list = counts.entries.map((e) => PosCount(e.key, e.value)).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  if (unsetCount > 0) {
    list.add(PosCount(null, unsetCount));
  }
  return list;
});

final badgeProgressProvider = Provider<List<BadgeProgress>>((ref) {
  final wordCount = ref.watch(allWordsProvider).value?.length ?? 0;
  final streak = ref.watch(streakProvider).value ?? 0;
  final xp = ref.watch(xpProvider).value ?? 0;
  return evaluateBadges(
    StatsSnapshot(
      wordCount: wordCount,
      streak: streak,
      correctCount: xp ~/ xpPerCorrectAnswer,
    ),
  );
});

final badgeUnlockServiceProvider = Provider<BadgeUnlockService>((ref) {
  return BadgeUnlockService();
});

class BadgeUnlockNotifier extends StateNotifier<Map<String, DateTime>> {
  final BadgeUnlockService _service;
  BadgeUnlockNotifier(this._service) : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.load();
  }

  /// Records "now" for any badge id in [unlockedIds] that isn't already
  /// recorded. Safe to call repeatedly — already-known ids are no-ops.
  Future<void> markUnlocked(List<String> unlockedIds) async {
    final updated = Map<String, DateTime>.from(state);
    var changed = false;
    for (final id in unlockedIds) {
      if (!updated.containsKey(id)) {
        updated[id] = DateTime.now();
        changed = true;
      }
    }
    if (changed) {
      state = updated;
      await _service.save(updated);
    }
  }
}

final badgeUnlockNotifierProvider =
    StateNotifierProvider<BadgeUnlockNotifier, Map<String, DateTime>>((ref) {
      return BadgeUnlockNotifier(ref.watch(badgeUnlockServiceProvider));
    });

final cefrServiceProvider = Provider<CefrService>((ref) {
  return CefrService();
});

final cefrWordlistProvider = FutureProvider<Map<String, CefrLevel>>((ref) {
  return ref.watch(cefrServiceProvider).loadWordlist();
});

class CefrCount {
  final CefrLevel? level;
  final int count;
  const CefrCount(this.level, this.count);
}

final cefrDistributionProvider = Provider<List<CefrCount>>((ref) {
  // CEFR-J only classifies English words; a jaTarget-mode word list has
  // nothing meaningful to show here until a JLPT-based sibling provider
  // exists (see jlptDistributionProvider, not yet implemented).
  if (ref.watch(learningModeProvider) != LearningDirection.enTarget) {
    return const [];
  }
  final words = ref.watch(allWordsProvider).value ?? [];
  final wordlist = ref.watch(cefrWordlistProvider).value;
  if (wordlist == null || words.isEmpty) return const [];

  final counts = <CefrLevel, int>{};
  var outOfScope = 0;
  for (final word in words) {
    final level = wordlist[word.english.trim().toLowerCase()];
    if (level == null) {
      outOfScope++;
      continue;
    }
    counts[level] = (counts[level] ?? 0) + 1;
  }

  final list = [
    for (final level in CefrLevel.values)
      if (counts[level] != null) CefrCount(level, counts[level]!),
  ];
  if (outOfScope > 0) {
    list.add(CefrCount(null, outOfScope));
  }
  return list;
});

final jlptServiceProvider = Provider<JlptService>((ref) {
  return JlptService();
});

final jlptWordlistProvider = FutureProvider<Map<String, JlptLevel>>((ref) {
  return ref.watch(jlptServiceProvider).loadWordlist();
});

class JlptCount {
  final JlptLevel? level;
  final int count;
  const JlptCount(this.level, this.count);
}

final jlptDistributionProvider = Provider<List<JlptCount>>((ref) {
  // JLPT only classifies Japanese words; an enTarget-mode word list has
  // nothing meaningful to show here (see cefrDistributionProvider above).
  if (ref.watch(learningModeProvider) != LearningDirection.jaTarget) {
    return const [];
  }
  final words = ref.watch(allWordsProvider).value ?? [];
  final wordlist = ref.watch(jlptWordlistProvider).value;
  if (wordlist == null || words.isEmpty) return const [];

  final counts = <JlptLevel, int>{};
  var outOfScope = 0;
  for (final word in words) {
    final level = wordlist[word.targetText.trim().toLowerCase()];
    if (level == null) {
      outOfScope++;
      continue;
    }
    counts[level] = (counts[level] ?? 0) + 1;
  }

  final list = [
    for (final level in JlptLevel.values)
      if (counts[level] != null) JlptCount(level, counts[level]!),
  ];
  if (outOfScope > 0) {
    list.add(JlptCount(null, outOfScope));
  }
  return list;
});

final recentBadgesProvider = Provider<List<BadgeProgress>>((ref) {
  final badges = ref.watch(badgeProgressProvider);
  final timestamps = ref.watch(badgeUnlockNotifierProvider);
  final unlocked = badges.where((b) => b.unlocked).toList()
    ..sort((a, b) {
      final ta = timestamps[a.badge.id];
      final tb = timestamps[b.badge.id];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
  return unlocked.take(3).toList();
});
