import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../repositories/activity_repository.dart';
import '../theme/app_theme.dart';

/// Last 7 days as a row of small squares — filled if the user did a
/// flashcard session that day, so continuity is visible at a glance.
class WeeklyActivityStrip extends ConsumerWidget {
  const WeeklyActivityStrip({super.key});

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(activityLogsProvider).value ?? [];
    final colors = context.colors;

    final flashcardDays = logs
        .where((l) => l.activityType == ActivityType.flashcard.value)
        .map((l) => dateOnly(l.date))
        .toSet();

    final today = dateOnly(DateTime.now());
    final days = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

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
            '直近7日間',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              final active = flashcardDays.contains(day);
              final isToday = day == today;
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary
                          : colors.cardBorder.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: colors.secondary, width: 2)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weekdayLabels[day.weekday - 1],
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
