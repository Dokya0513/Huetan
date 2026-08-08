import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeProgressProvider);
    final unlockedCount = badges.where((b) => b.unlocked).length;
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: AppTitleRow(title: l10n.navBadges)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.badgesUnlockedCount(unlockedCount, badges.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final progress = badges[index];
                final badge = progress.badge;
                return Card(
                  color: progress.unlocked
                      ? colors.surface
                      : colors.surface.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: progress.unlocked
                          ? colors.cardBorder
                          : colors.cardBorder.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          badge.icon,
                          size: 36,
                          color: progress.unlocked
                              ? colors.primary
                              : colors.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Zen Maru Gothic',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: progress.unlocked
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
