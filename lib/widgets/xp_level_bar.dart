import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class XpLevelBar extends ConsumerWidget {
  const XpLevelBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelInfo = ref.watch(levelInfoProvider);
    final colors = context.colors;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Lv.${levelInfo.level}',
            style: const TextStyle(
              fontFamily: 'Baloo 2',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelInfo.progress,
              minHeight: 8,
              backgroundColor: colors.cardBorder.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${levelInfo.xpIntoLevel}/100 XP',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }
}
