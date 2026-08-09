import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/learning_direction.dart';
import '../providers/providers.dart';
import '../repositories/word_repository.dart';
import '../services/auto_backup.dart';
import '../services/dictionary_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/cefr_distribution_bar.dart';
import '../widgets/character_card.dart';
import '../widgets/due_today_card.dart';
import '../widgets/genre_distribution_bar.dart';
import '../widgets/jlpt_distribution_bar.dart';
import '../widgets/recent_badges_card.dart';
import '../widgets/update_available_banner.dart';
import '../widgets/weak_words_preview_card.dart';
import '../widgets/weekly_activity_strip.dart';
import '../widgets/xp_level_bar.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _quickAddController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final unlockedIds = ref
          .read(badgeProgressProvider)
          .where((b) => b.unlocked)
          .map((b) => b.badge.id)
          .toList();
      ref.read(badgeUnlockNotifierProvider.notifier).markUnlocked(unlockedIds);
    });
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final english = _quickAddController.text.trim();
    if (english.isEmpty) return;

    final repository = ref.read(wordRepositoryProvider);
    final wordId = await repository.addWord(
      english: english,
      learningDirection: LearningDirection.enTarget,
    );
    _quickAddController.clear();
    unawaited(autoBackupIfSignedIn(ref));

    // Fire-and-forget: fill in part of speech/example/audio from the
    // dictionary in the background so quick-added words don't stay
    // completely uncategorized, without making the user wait on a lookup.
    unawaited(_backgroundDictionaryFill(repository, wordId, english));
  }

  /// jaTarget equivalent of [_quickAdd]: just the target word, meaning left
  /// blank to fill in later — no dictionary lookup exists for Japanese yet
  /// (see word_form_screen.dart's jaTarget handling), so there's no
  /// background fill step, just a plain word entry.
  Future<void> _quickAddJa() async {
    final japanese = _quickAddController.text.trim();
    if (japanese.isEmpty) return;

    final repository = ref.read(wordRepositoryProvider);
    await repository.addWord(
      english: '',
      japanese: japanese,
      learningDirection: LearningDirection.jaTarget,
    );
    _quickAddController.clear();
    unawaited(autoBackupIfSignedIn(ref));
  }

  Future<void> _backgroundDictionaryFill(
    WordRepository repository,
    int wordId,
    String english,
  ) async {
    final result = await DictionaryService().lookup(english);
    if (result == null || result.senses.isEmpty) return;
    final sense = result.senses.first;
    await repository.fillDictionaryFieldsIfEmpty(
      id: wordId,
      partOfSpeech: sense.partOfSpeech.label,
      exampleSentence: sense.example,
      extraExamples: sense.examples.skip(1).toList(),
      audioUrl: result.audioUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(badgeProgressProvider, (previous, next) {
      final unlockedIds = next
          .where((b) => b.unlocked)
          .map((b) => b.badge.id)
          .toList();
      ref.read(badgeUnlockNotifierProvider.notifier).markUnlocked(unlockedIds);
    });

    final l10n = AppLocalizations.of(context)!;
    final isEnTarget = ref.watch(learningModeProvider) == LearningDirection.enTarget;
    return Scaffold(
      appBar: AppBar(
        title: AppTitleRow(title: l10n.navHome),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: l10n.friendsNavTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const UpdateAvailableBanner(),
          const CharacterCard(),
          const SizedBox(height: 16),
          const XpLevelBar(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickAddController,
                  decoration: InputDecoration(
                    hintText: isEnTarget
                        ? l10n.dashboardQuickAddHint
                        : l10n.dashboardQuickAddJaHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => isEnTarget ? _quickAdd() : _quickAddJa(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: isEnTarget ? _quickAdd : _quickAddJa,
                icon: const Icon(Icons.add),
                tooltip: l10n.addTooltip,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const WeeklyActivityStrip(),
          const SizedBox(height: 16),
          const DueTodayCard(),
          const SizedBox(height: 16),
          const RecentBadgesCard(),
          const SizedBox(height: 16),
          const WeakWordsPreviewCard(),
          const SizedBox(height: 16),
          const GenreDistributionBar(),
          const SizedBox(height: 16),
          const CefrDistributionBar(),
          const SizedBox(height: 16),
          const JlptDistributionBar(),
        ],
      ),
    );
  }
}
