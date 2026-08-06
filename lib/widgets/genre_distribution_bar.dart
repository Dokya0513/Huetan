import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';

/// Stacked bar + legend showing how registered words are spread across
/// tags, so lopsided coverage (e.g. mostly "ビジネス", barely any "旅行")
/// is visible at a glance.
class GenreDistributionBar extends ConsumerWidget {
  const GenreDistributionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distribution = ref.watch(tagDistributionProvider);
    final allTagNames = ref.watch(allTagNamesProvider).value ?? [];
    final colors = context.colors;

    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = distribution.fold<int>(0, (sum, t) => sum + t.count);
    final untaggedColor = colors.textSecondary.withValues(alpha: 0.35);

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
            'ジャンル内訳（全$total語）',
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
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
                        color: colorForTag(item.tag, allTagNames, untaggedColor),
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
                          color: colorForTag(item.tag, allTagNames, untaggedColor),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.tag == untaggedLabel
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${item.count}語（${(item.count / total * 100).round()}%）',
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
