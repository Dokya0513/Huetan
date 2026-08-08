import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SessionResultScreen extends StatelessWidget {
  final int correctCount;
  final int incorrectCount;

  const SessionResultScreen({
    super.key,
    required this.correctCount,
    required this.incorrectCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = correctCount + incorrectCount;
    final rate = total == 0 ? 0 : (correctCount / total * 100).round();
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
            Text(l10n.resultCorrectCount(correctCount)),
            Text(l10n.resultIncorrectCount(incorrectCount)),
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
