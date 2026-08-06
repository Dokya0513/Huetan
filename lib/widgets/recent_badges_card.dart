import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/badges_screen.dart';
import '../theme/app_theme.dart';

/// Recently unlocked badges, so a fresh achievement doesn't go unnoticed
/// until the next visit to the バッジ tab.
class RecentBadgesCard extends ConsumerWidget {
  const RecentBadgesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentBadgesProvider);
    final colors = context.colors;

    if (recent.isEmpty) return const SizedBox.shrink();

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
                  '最近解錠したバッジ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BadgesScreen()),
                  );
                },
                child: const Text('すべて見る'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final progress in recent)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Icon(
                        progress.badge.icon,
                        color: colors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress.badge.title,
                        style: TextStyle(
                          fontSize: 11,
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
