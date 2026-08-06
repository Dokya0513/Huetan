import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tag_colors.dart';
import '../widgets/app_logo.dart';
import 'flashcard_setup_screen.dart';
import 'word_form_screen.dart';

enum _SortMode { registered, alphabetical, weakness, tag }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _SortMode _sortMode = _SortMode.registered;

  List<Word> _sorted(List<Word> words, Map<int, List<String>> tagsByWordId) {
    final sorted = List<Word>.from(words);
    switch (_sortMode) {
      case _SortMode.registered:
        break; // allWordsProvider already orders by createdAt desc.
      case _SortMode.alphabetical:
        sorted.sort(
          (a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()),
        );
      case _SortMode.weakness:
        sorted.sort((a, b) {
          final keyA = a.lastReviewedAt == null ? 99 : a.leitnerBox;
          final keyB = b.lastReviewedAt == null ? 99 : b.leitnerBox;
          return keyA.compareTo(keyB);
        });
      case _SortMode.tag:
        String firstTag(Word w) {
          final tags = tagsByWordId[w.id];
          return (tags == null || tags.isEmpty) ? '\u{10FFFF}' : tags.first;
        }

        sorted.sort((a, b) => firstTag(a).compareTo(firstTag(b)));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(allWordsProvider);
    final tagsByWordId = ref.watch(wordTagsByWordIdProvider);
    final allTagNames = ref.watch(allTagNamesProvider).value ?? [];
    final colors = context.colors;
    final untaggedColor = colors.textSecondary.withValues(alpha: 0.35);

    return Scaffold(
      appBar: AppBar(
        title: const AppTitleRow(title: '単語'),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: '並び替え',
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _SortMode.registered, child: Text('登録順')),
              PopupMenuItem(value: _SortMode.alphabetical, child: Text('ABC順')),
              PopupMenuItem(value: _SortMode.weakness, child: Text('苦手度順')),
              PopupMenuItem(value: _SortMode.tag, child: Text('タグ順')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '単語を追加（詳細入力）',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordFormScreen()),
              );
            },
          ),
        ],
      ),
      body: wordsAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const Center(
              child: Text('まだ単語が登録されていません。「ホーム」タブの入力欄から追加してください。'),
            );
          }
          final sortedWords = _sorted(words, tagsByWordId);
          return ListView.separated(
            itemCount: sortedWords.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final word = sortedWords[index];
              final tags = tagsByWordId[word.id] ?? const [];
              return ListTile(
                title: Text(
                  word.english,
                  style: const TextStyle(
                    fontFamily: englishDisplayFontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    word.japanese != null
                        ? Text(word.japanese!)
                        : const Text(
                            '訳未入力',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: tags
                              .map(
                                (tag) => Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colorForTag(
                                      tag,
                                      allTagNames,
                                      untaggedColor,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up_outlined),
                      tooltip: '発音を再生',
                      onPressed: () => ref
                          .read(pronunciationServiceProvider)
                          .speak(
                            word.english,
                            audioUrl: word.audioUrl,
                            volume: ref.read(voiceVolumeProvider),
                          ),
                    ),
                    _BoxBadge(
                      box: word.leitnerBox,
                      isReviewed: word.lastReviewedAt != null,
                      hasTranslation: word.japanese != null,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WordFormScreen(existing: word),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FlashcardSetupScreen()),
          );
        },
        icon: const Icon(Icons.style_outlined),
        label: const Text('暗記カード'),
      ),
    );
  }
}

class _BoxBadge extends StatelessWidget {
  final int box;
  final bool isReviewed;
  final bool hasTranslation;
  const _BoxBadge({
    required this.box,
    required this.isReviewed,
    required this.hasTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String label;
    final Color color;
    final Color backgroundColor;
    if (!hasTranslation) {
      label = '未設定';
      color = colors.textSecondary;
      backgroundColor = colors.textSecondary.withValues(alpha: 0.15);
    } else if (!isReviewed) {
      label = 'NEW';
      color = colors.primary;
      backgroundColor = colors.primary.withValues(alpha: 0.15);
    } else {
      final condition = WordCondition.forBox(box, colors);
      label = condition.label;
      color = condition.color;
      backgroundColor = condition.backgroundColor;
    }
    return Container(
      width: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
