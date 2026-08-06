import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/app_logo.dart';
import '../widgets/character_card.dart';
import '../widgets/due_today_card.dart';
import '../widgets/genre_distribution_bar.dart';
import '../widgets/recent_badges_card.dart';
import '../widgets/weak_words_preview_card.dart';
import '../widgets/weekly_activity_strip.dart';
import '../widgets/xp_level_bar.dart';
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

    await ref.read(wordRepositoryProvider).addWord(english: english);
    _quickAddController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(streakProvider);

    ref.listen(badgeProgressProvider, (previous, next) {
      final unlockedIds = next
          .where((b) => b.unlocked)
          .map((b) => b.badge.id)
          .toList();
      ref.read(badgeUnlockNotifierProvider.notifier).markUnlocked(unlockedIds);
    });

    return Scaffold(
      appBar: AppBar(
        title: const AppTitleRow(title: 'ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const CharacterCard(),
          const SizedBox(height: 16),
          const XpLevelBar(),
          streakAsync.maybeWhen(
            data: (streak) => streak > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '🔥 $streak日連続で学習中',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickAddController,
                  decoration: const InputDecoration(
                    hintText: '英単語をサッと追加（意味は後で入力）',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _quickAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _quickAdd,
                icon: const Icon(Icons.add),
                tooltip: '追加',
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
        ],
      ),
    );
  }
}
