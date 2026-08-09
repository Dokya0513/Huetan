import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

class SessionResultScreen extends ConsumerStatefulWidget {
  final int correctCount;
  final int incorrectCount;

  const SessionResultScreen({
    super.key,
    required this.correctCount,
    required this.incorrectCount,
  });

  @override
  ConsumerState<SessionResultScreen> createState() =>
      _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: keeps the cloud-visible XP/streak (for friends)
    // roughly up to date without making the result screen wait on a
    // network call. Silently does nothing when signed out.
    if (Supabase.instance.client.auth.currentUser != null) {
      Future.microtask(_pushStats);
    }
  }

  Future<void> _pushStats() async {
    try {
      final xp = await ref.read(xpProvider.future);
      final streak = await ref.read(streakProvider.future);
      await ref
          .read(friendsServiceProvider)
          .pushStats(xp: xp, streakDays: streak);
    } catch (_) {
      // Best-effort only — the local review session already succeeded
      // regardless of whether this sync goes through.
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.correctCount + widget.incorrectCount;
    final rate = total == 0 ? 0 : (widget.correctCount / total * 100).round();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.resultAccuracyRate(rate),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(l10n.resultCorrectCount(widget.correctCount)),
            Text(l10n.resultIncorrectCount(widget.incorrectCount)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(l10n.resultBackToHome),
            ),
          ],
        ),
      ),
    );
  }
}
