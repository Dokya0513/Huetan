import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../repositories/word_repository.dart';
import '../screens/flashcard_screen.dart';
import '../theme/app_theme.dart';

/// One-tap shortcut to start today's due-word review, shown on the home
/// dashboard so the user doesn't have to go through the flashcard setup
/// screen just to do the daily minimum.
class DueTodayCard extends ConsumerWidget {
  const DueTodayCard({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final words = await ref
        .read(wordRepositoryProvider)
        .selectSessionWords(dueOnly: true);
    if (words.isEmpty || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          words: words,
          allowedDirections: const [
            ReviewDirection.enToJa,
            ReviewDirection.jaToEn,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueCount = ref.watch(dueWordsProvider).value?.length;
    final wordCount = ref.watch(allWordsProvider).value?.length ?? 0;
    final colors = context.colors;

    if (wordCount == 0 || dueCount == null) return const SizedBox.shrink();

    final isDone = dueCount == 0;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? colors.successBg : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? colors.success : colors.cardBorder,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDone ? l10n.dueTodayDoneMessage : l10n.dueTodayCount(dueCount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          if (!isDone) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _start(context, ref),
                child: Text(l10n.doNowButton),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
