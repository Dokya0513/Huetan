import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/character_advice.dart';
import '../repositories/activity_repository.dart';
import '../repositories/stats_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/word_repository.dart';
import '../services/badge_unlock_service.dart';
import '../services/pronunciation_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';

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
  return ref.watch(wordRepositoryProvider).watchAllWords();
});

final weakWordsProvider = StreamProvider<List<Word>>((ref) {
  return ref.watch(wordRepositoryProvider).watchWeakWords();
});

final dueWordsProvider = StreamProvider<List<Word>>((ref) {
  return ref.watch(wordRepositoryProvider).watchDueWords();
});

final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  return ref.watch(activityRepositoryProvider).watchActivityLogs();
});

final streakProvider = FutureProvider.autoDispose<int>((ref) {
  // Re-run whenever activity logs change so the streak stays fresh.
  ref.watch(activityLogsProvider);
  return ref.watch(activityRepositoryProvider).currentStreak();
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

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(databaseProvider));
});

final xpProvider = StreamProvider<int>((ref) {
  return ref.watch(statsRepositoryProvider).watchXp();
});

final levelInfoProvider = Provider<LevelInfo>((ref) {
  final xp = ref.watch(xpProvider).value ?? 0;
  return LevelInfo(xp);
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class VolumeNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  final VolumeChannel _channel;
  VolumeNotifier(this._settingsService, this._channel)
    : super(defaultVolume) {
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
  return VolumeNotifier(ref.watch(settingsServiceProvider), VolumeChannel.soundEffect);
});

final voiceVolumeProvider = StateNotifierProvider<VolumeNotifier, double>((
  ref,
) {
  return VolumeNotifier(ref.watch(settingsServiceProvider), VolumeChannel.voice);
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

final characterAdviceCandidatesProvider = Provider<List<CharacterAdvice>>((
  ref,
) {
  final wordCount = ref.watch(allWordsProvider).value?.length ?? 0;
  final streak = ref.watch(streakProvider).value ?? 0;
  final dueCount = ref.watch(dueWordsProvider).value?.length ?? 0;
  final weakCount = ref
      .watch(weakWordsProvider)
      .value
      ?.where((w) => w.leitnerBox <= 2)
      .length ?? 0;
  return characterAdviceCandidates(
    wordCount: wordCount,
    streak: streak,
    dueCount: dueCount,
    weakCount: weakCount,
    currentHour: DateTime.now().hour,
  );
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(databaseProvider));
});

final wordTagsProvider = StreamProvider<List<WordTag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAllWordTags();
});

final allTagNamesProvider = FutureProvider<List<String>>((ref) {
  // Re-run whenever tag links change so autocomplete stays current.
  ref.watch(wordTagsProvider);
  return ref.watch(tagRepositoryProvider).getAllTagNames();
});

final wordTagsByWordIdProvider = Provider<Map<int, List<String>>>((ref) {
  final links = ref.watch(wordTagsProvider).value ?? [];
  final map = <int, List<String>>{};
  for (final link in links) {
    map.putIfAbsent(link.wordId, () => []).add(link.tag);
  }
  return map;
});

final tagDistributionProvider = Provider<List<TagCount>>((ref) {
  final words = ref.watch(allWordsProvider).value ?? [];
  final wordTags = ref.watch(wordTagsProvider).value ?? [];

  final counts = <String, int>{};
  final taggedWordIds = <int>{};
  for (final link in wordTags) {
    counts[link.tag] = (counts[link.tag] ?? 0) + 1;
    taggedWordIds.add(link.wordId);
  }
  final untaggedCount = words
      .where((w) => !taggedWordIds.contains(w.id))
      .length;

  final list = counts.entries.map((e) => TagCount(e.key, e.value)).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  if (untaggedCount > 0) {
    list.add(TagCount('未分類', untaggedCount));
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
