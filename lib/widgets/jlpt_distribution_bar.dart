import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/jlpt_colors.dart';

/// Stacked bar + legend showing registered words by JLPT level (N5-N1), as
/// a rough difficulty gauge — the Japanese-learning-mode counterpart to
/// [CefrDistributionBar]. Shown natively (not converted to a CEFR grade).
///
/// Data: word list aggregated by https://github.com/elzup/jlpt-word-list
/// (MIT), underlying data from Jonathan Waller's JLPT Resources
/// (tanos.co.uk), CC BY.
class JlptDistributionBar extends ConsumerWidget {
  const JlptDistributionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distribution = ref.watch(jlptDistributionProvider);
    final colors = context.colors;

    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = distribution.fold<int>(0, (sum, t) => sum + t.count);
    final outOfScopeColor = colors.textSecondary.withValues(alpha: 0.35);
    final l10n = AppLocalizations.of(context)!;

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
          Text(
            l10n.jlptDistributionTitle(total),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  for (final item in distribution)
                    Expanded(
                      flex: item.count,
                      child: Container(
                        color: colorForJlpt(item.level, outOfScopeColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final item in distribution)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorForJlpt(item.level, outOfScopeColor),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.level?.label ?? l10n.cefrOutOfScopeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.level == null
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        l10n.wordCountPercent(
                          item.count,
                          (item.count / total * 100).round(),
                        ),
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
        ],
      ),
    );
  }
}
