import 'package:flutter/material.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('結果')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('正答率 $rate%', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('わかった: $correctCount'),
            Text('わからなかった: $incorrectCount'),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('ホームに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
