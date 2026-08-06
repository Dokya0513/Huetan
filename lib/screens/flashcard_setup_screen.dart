import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../repositories/word_repository.dart';
import '../theme/app_theme.dart';
import 'flashcard_screen.dart';

const List<int?> _countOptions = [null, 100, 50, 30];

class FlashcardSetupScreen extends ConsumerStatefulWidget {
  const FlashcardSetupScreen({super.key});

  @override
  ConsumerState<FlashcardSetupScreen> createState() =>
      _FlashcardSetupScreenState();
}

class _FlashcardSetupScreenState extends ConsumerState<FlashcardSetupScreen> {
  int? _selectedCount;
  bool _enToJa = true;
  bool _jaToEn = false;

  Future<void> _start({bool dueOnly = false}) async {
    if (!_enToJa && !_jaToEn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出題方向を1つ以上選んでください')),
      );
      return;
    }

    final repository = ref.read(wordRepositoryProvider);
    final words = await repository.selectSessionWords(
      count: dueOnly ? null : _selectedCount,
      dueOnly: dueOnly,
    );

    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('単語が登録されていません')),
        );
      }
      return;
    }

    final directions = <ReviewDirection>[
      if (_enToJa) ReviewDirection.enToJa,
      if (_jaToEn) ReviewDirection.jaToEn,
    ];

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(
            words: words,
            allowedDirections: directions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(allWordsProvider);
    final totalCount = wordsAsync.value?.length;
    final dueCount = ref.watch(dueWordsProvider).value?.length;

    return Scaffold(
      appBar: AppBar(title: const Text('暗記カード設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dueCount != null && dueCount > 0) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '今日の復習: $dueCount件',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _start(dueOnly: true),
                        child: const Text('今日の分をやる'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'または、件数・方向を選んで自由にやる',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            const Text('出題数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _countOptions.map((count) {
                final label = count == null ? 'すべて' : '$count';
                final selected = _selectedCount == count;
                return ChoiceChip(
                  label: Text(label),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : context.colors.textPrimary,
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCount = count),
                );
              }).toList(),
            ),
            if (totalCount != null) ...[
              const SizedBox(height: 4),
              Text(
                '登録済み単語数: $totalCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            const Text('出題方向', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('英語 → 日本語'),
              value: _enToJa,
              onChanged: (value) => setState(() => _enToJa = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('日本語 → 英語'),
              value: _jaToEn,
              onChanged: (value) => setState(() => _jaToEn = value ?? false),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _start,
              child: const Text('開始'),
            ),
          ],
        ),
      ),
    );
  }
}
