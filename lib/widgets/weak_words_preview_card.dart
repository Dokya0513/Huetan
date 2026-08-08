import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../screens/home_screen.dart';
import '../theme/app_theme.dart';

/// Shows the weakest few words on the home dashboard, so trouble spots are
/// visible without a trip to the 苦手 tab.
class WeakWordsPreviewCard extends ConsumerWidget {
  const WeakWordsPreviewCard({super.key});

  static const _previewCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(weakWordsProvider).value ?? [];
    final colors = context.colors;

    if (words.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final preview = words.take(_previewCount).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.weakWordsTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(initialWeakOnly: true),
                    ),
                  );
                },
                child: Text(l10n.viewAllButton),
              ),
            ],
          ),
          for (final word in preview)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: WordCondition.forBox(
                        word.leitnerBox,
                        colors,
                        l10n,
                      ).color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      word.english,
                      style: TextStyle(
                        fontFamily: englishDisplayFontFamily,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (word.japanese != null)
                    Text(
                      word.japanese!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
