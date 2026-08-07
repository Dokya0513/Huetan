import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/cefr_level.dart';
import '../models/fill_blank.dart';
import '../models/part_of_speech.dart';
import '../providers/providers.dart';
import '../repositories/word_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'choice_quiz_screen.dart';
import 'fill_blank_quiz_screen.dart';
import 'flashcard_screen.dart';

const List<int?> _countOptions = [null, 100, 50, 30];

/// 4-choice modes need at least 1 correct answer + 3 distractors to be a
/// real quiz rather than a "tap the only button" no-op.
const _minWordsForChoiceModes = 4;

enum QuizMode {
  flashcard('暗記カード'),
  choiceQuiz('4択クイズ'),
  fillBlank('穴埋めクイズ（4択）');

  final String label;
  const QuizMode(this.label);
}

class FlashcardSetupScreen extends ConsumerStatefulWidget {
  /// Which modes the user can pick between. When there's only one, the
  /// "出題形式" selector is hidden entirely and that mode is locked in —
  /// used to restrict this screen to just the flip-card mode from the 単語帳
  /// tab, or to just the quiz modes from the テスト tab.
  final List<QuizMode> allowedModes;

  /// AppBar title — customizable so the same screen can read "暗記カード設定"
  /// when pushed, or a tab-appropriate title when embedded as a tab root.
  final String title;

  const FlashcardSetupScreen({
    super.key,
    this.allowedModes = QuizMode.values,
    this.title = '暗記カード設定',
  });

  @override
  ConsumerState<FlashcardSetupScreen> createState() =>
      _FlashcardSetupScreenState();
}

class _FlashcardSetupScreenState extends ConsumerState<FlashcardSetupScreen> {
  int? _selectedCount;
  bool _enToJa = true;
  bool _jaToEn = false;
  late QuizMode _mode;
  PartOfSpeech? _posFilter;
  CefrLevel? _cefrFilter;

  @override
  void initState() {
    super.initState();
    _mode = widget.allowedModes.first;
  }

  bool Function(Word word)? _buildExtraFilter(Map<String, CefrLevel>? cefr) {
    final cefrFilter = _cefrFilter;
    final requireExample = _mode == QuizMode.fillBlank;
    if (cefrFilter == null && !requireExample) return null;

    return (word) {
      if (requireExample) {
        final sentence = word.exampleSentence;
        if (sentence == null ||
            !wordAppearsInSentence(word.english, sentence)) {
          return false;
        }
      }
      if (cefrFilter != null) {
        final level = cefr?[word.english.trim().toLowerCase()];
        if (level != cefrFilter) return false;
      }
      return true;
    };
  }

  Future<void> _start({bool dueOnly = false}) async {
    final needsDirection =
        _mode == QuizMode.flashcard || _mode == QuizMode.choiceQuiz;
    if (needsDirection && !_enToJa && !_jaToEn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('出題方向を1つ以上選んでください')));
      return;
    }

    final cefrWordlist = ref.read(cefrWordlistProvider).value;
    final repository = ref.read(wordRepositoryProvider);
    final words = await repository.selectSessionWords(
      count: dueOnly ? null : _selectedCount,
      dueOnly: dueOnly,
      partOfSpeech: _posFilter?.label,
      extraFilter: _buildExtraFilter(cefrWordlist),
    );

    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('条件に合う単語が見つかりませんでした')));
      }
      return;
    }

    if (!mounted) return;

    if (_mode == QuizMode.fillBlank) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FillBlankQuizScreen(words: words)),
      );
      return;
    }

    final directions = <ReviewDirection>[
      if (_enToJa) ReviewDirection.enToJa,
      if (_jaToEn) ReviewDirection.jaToEn,
    ];

    if (_mode == QuizMode.choiceQuiz) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChoiceQuizScreen(words: words, allowedDirections: directions),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FlashcardScreen(words: words, allowedDirections: directions),
      ),
    );
  }

  /// Live preview count matching the current filters — lets the user see
  /// "0 words" and fix the filter before hitting start.
  int _matchingCount(List<Word> allWords, Map<String, CefrLevel>? cefr) {
    return allWords.where((w) {
      if (w.japanese == null) return false;
      if (_posFilter != null && w.partOfSpeech != _posFilter!.label) {
        return false;
      }
      if (_cefrFilter != null) {
        final level = cefr?[w.english.trim().toLowerCase()];
        if (level != _cefrFilter) return false;
      }
      if (_mode == QuizMode.fillBlank) {
        final sentence = w.exampleSentence;
        if (sentence == null || !wordAppearsInSentence(w.english, sentence)) {
          return false;
        }
      }
      return true;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(allWordsProvider);
    final allWords = wordsAsync.value ?? [];
    final cefrWordlist = ref.watch(cefrWordlistProvider).value;
    final dueCount = ref.watch(dueWordsProvider).value?.length;
    final matchingCount = _matchingCount(allWords, cefrWordlist);
    final showDirectionPicker =
        _mode == QuizMode.flashcard || _mode == QuizMode.choiceQuiz;
    final needsChoices =
        _mode == QuizMode.choiceQuiz || _mode == QuizMode.fillBlank;
    final isLocked = needsChoices && matchingCount < _minWordsForChoiceModes;
    final canStart = needsChoices
        ? matchingCount >= _minWordsForChoiceModes
        : matchingCount > 0;

    return Scaffold(
      appBar: AppBar(title: AppTitleRow(title: widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dueCount != null &&
                dueCount > 0 &&
                widget.allowedModes.contains(QuizMode.flashcard)) ...[
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
                'または、条件を選んで自由にやる',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.allowedModes.length > 1) ...[
              const Text('出題形式', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in widget.allowedModes)
                    _choiceChip(
                      label: mode.label,
                      selected: _mode == mode,
                      onSelected: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              if (_mode == QuizMode.fillBlank) ...[
                const SizedBox(height: 4),
                Text(
                  '例文に単語がそのままの形で含まれている単語だけが出題対象です',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
            ],
            const Text('出題数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _countOptions.map((count) {
                final label = count == null ? 'すべて' : '$count';
                return _choiceChip(
                  label: label,
                  selected: _selectedCount == count,
                  onSelected: () => setState(() => _selectedCount = count),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              '品詞で絞り込み',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _choiceChip(
                  label: '絞り込みなし',
                  selected: _posFilter == null,
                  onSelected: () => setState(() => _posFilter = null),
                ),
                for (final pos in PartOfSpeech.values)
                  _choiceChip(
                    label: pos.label,
                    selected: _posFilter == pos,
                    onSelected: () => setState(() => _posFilter = pos),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'CEFRレベルで絞り込み',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _choiceChip(
                  label: '絞り込みなし',
                  selected: _cefrFilter == null,
                  onSelected: () => setState(() => _cefrFilter = null),
                ),
                for (final level in CefrLevel.values)
                  _choiceChip(
                    label: level.label,
                    selected: _cefrFilter == level,
                    onSelected: () => setState(() => _cefrFilter = level),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLocked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        matchingCount == 0
                            ? 'この条件に合う単語がまだありません。まずは単語を追加してみよう'
                            : 'あと${_minWordsForChoiceModes - matchingCount}語追加すると遊べるようになります（現在$matchingCount語）',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                '条件に合う単語数: $matchingCount件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (showDirectionPicker) ...[
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
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canStart ? _start : null,
                child: const Text('開始'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : context.colors.textPrimary,
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
