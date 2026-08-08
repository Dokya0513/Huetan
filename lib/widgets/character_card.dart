import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/character_advice.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class CharacterCard extends ConsumerStatefulWidget {
  /// Which advice pool to show — defaults to the general home-tab advice.
  /// Pass [calendarAdviceCandidatesProvider] etc. for tab-specific flavor.
  final ProviderListenable<List<CharacterAdvice>>? adviceProvider;

  const CharacterCard({super.key, this.adviceProvider});

  @override
  ConsumerState<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends ConsumerState<CharacterCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(
      widget.adviceProvider ?? characterAdviceCandidatesProvider,
    );
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final advice = candidates[_index % candidates.length];
    final canCycle = candidates.length > 1;

    return GestureDetector(
      onTap: canCycle
          ? () => setState(() => _index = (_index + 1) % candidates.length)
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cardBorder, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(advice.emotion.assetPath, width: 56, height: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                advice.message(l10n),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (canCycle)
              Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
