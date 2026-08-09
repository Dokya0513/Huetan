import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/cefr_level.dart';
import '../models/jlpt_level.dart';
import '../models/learning_direction.dart';
import '../models/part_of_speech.dart';
import '../models/word_display.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/cefr_colors.dart';
import '../theme/jlpt_colors.dart';
import '../theme/pos_colors.dart';
import '../widgets/app_logo.dart';
import 'flashcard_setup_screen.dart';
import 'word_form_screen.dart';

enum _SortMode { registered, alphabetical, weakness, partOfSpeech }

class HomeScreen extends ConsumerStatefulWidget {
  /// Opens the tab with the "苦手のみ" filter already on — used when
  /// navigating here from the dashboard's weak-words preview card.
  final bool initialWeakOnly;

  const HomeScreen({super.key, this.initialWeakOnly = false});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _SortMode _sortMode = _SortMode.registered;
  final _searchController = TextEditingController();
  String _query = '';
  late bool _weakOnly;

  @override
  void initState() {
    super.initState();
    _weakOnly = widget.initialWeakOnly;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Word> _filtered(List<Word> words) {
    var result = words;
    if (_weakOnly) {
      result = result.where((w) => w.lastReviewedAt != null).toList();
    }
    if (_query.isNotEmpty) {
      result = result.where((w) {
        if (w.targetText.toLowerCase().contains(_query)) return true;
        final meaning = w.meaningText;
        return meaning != null && meaning.toLowerCase().contains(_query);
      }).toList();
    }
    return result;
  }

  List<Word> _sorted(List<Word> words) {
    // The 苦手のみ filter always shows weakest-first, matching what the old
    // dedicated 苦手 tab did — the sort menu only applies to the full list.
    final effectiveSortMode = _weakOnly ? _SortMode.weakness : _sortMode;
    final sorted = List<Word>.from(words);
    switch (effectiveSortMode) {
      case _SortMode.registered:
        break; // allWordsProvider already orders by createdAt desc.
      case _SortMode.alphabetical:
        sorted.sort(
          (a, b) =>
              a.targetText.toLowerCase().compareTo(b.targetText.toLowerCase()),
        );
      case _SortMode.weakness:
        sorted.sort((a, b) {
          final keyA = a.lastReviewedAt == null ? 99 : a.leitnerBox;
          final keyB = b.lastReviewedAt == null ? 99 : b.leitnerBox;
          return keyA.compareTo(keyB);
        });
      case _SortMode.partOfSpeech:
        String posLabel(Word w) => w.partOfSpeech == null
            ? '\u{10FFFF}'
            : mapToPartOfSpeech(w.partOfSpeech!).label;

        sorted.sort((a, b) => posLabel(a).compareTo(posLabel(b)));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(allWordsProvider);
    final cefrWordlist = ref.watch(cefrWordlistProvider).value;
    final jlptWordlist = ref.watch(jlptWordlistProvider).value;
    final colors = context.colors;
    final unsetColor = colors.textSecondary.withValues(alpha: 0.35);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: AppTitleRow(title: l10n.navWords),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sortTooltip,
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SortMode.registered,
                child: Text(l10n.sortRegistered),
              ),
              PopupMenuItem(
                value: _SortMode.alphabetical,
                child: Text(l10n.sortAlphabetical),
              ),
              PopupMenuItem(
                value: _SortMode.weakness,
                child: Text(l10n.sortWeakness),
              ),
              PopupMenuItem(
                value: _SortMode.partOfSpeech,
                child: Text(l10n.sortPartOfSpeech),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: l10n.addWordTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WordFormScreen()));
            },
          ),
        ],
      ),
      body: wordsAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return Center(child: Text(l10n.emptyWordsMessage));
          }
          final sortedWords = _sorted(_filtered(words));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(l10n.weakOnlyFilterLabel),
                    avatar: _weakOnly
                        ? null
                        : const Icon(Icons.warning_amber_outlined, size: 18),
                    selected: _weakOnly,
                    onSelected: (value) => setState(() => _weakOnly = value),
                  ),
                ),
              ),
              Expanded(
                child: sortedWords.isEmpty
                    ? Center(child: Text(l10n.noMatchingWords))
                    : ListView.separated(
                        itemCount: sortedWords.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final word = sortedWords[index];
                          final isEnTargetWord =
                              word.direction == LearningDirection.enTarget;
                          final pos = word.partOfSpeech != null
                              ? mapToPartOfSpeech(word.partOfSpeech!)
                              : null;
                          // CEFR-J only classifies English words; JLPT
                          // only classifies Japanese words.
                          CefrLevel? cefr;
                          JlptLevel? jlpt;
                          final targetKey = word.targetText
                              .trim()
                              .toLowerCase();
                          if (isEnTargetWord) {
                            cefr = cefrWordlist?[targetKey];
                          } else {
                            jlpt = jlptWordlist?[targetKey];
                          }
                          final meaning = word.meaningText;
                          return ListTile(
                            title: Text(
                              word.targetText,
                              style: TextStyle(
                                fontFamily: isEnTargetWord
                                    ? englishDisplayFontFamily
                                    : null,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                meaning != null
                                    ? Text(meaning)
                                    : Text(
                                        l10n.noTranslationYet,
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                if (pos != null || cefr != null || jlpt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (pos != null)
                                          _PosPill(
                                            pos: pos,
                                            color: colorForPos(pos, unsetColor),
                                          ),
                                        if (cefr != null)
                                          _CefrPill(level: cefr),
                                        if (jlpt != null)
                                          _JlptPill(level: jlpt),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.volume_up_outlined),
                                  tooltip: l10n.playPronunciationTooltip,
                                  onPressed: () => ref
                                      .read(pronunciationServiceProvider)
                                      .speak(
                                        word.speechText,
                                        audioUrl: word.audioUrl,
                                        volume: ref.read(voiceVolumeProvider),
                                        languageCode: isEnTargetWord
                                            ? 'en-US'
                                            : 'ja-JP',
                                      ),
                                ),
                                const SizedBox(width: 6),
                                _BoxBadge(
                                  box: word.leitnerBox,
                                  isReviewed: word.lastReviewedAt != null,
                                  hasTranslation: meaning != null,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WordFormScreen(existing: word),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.errorWithMessage(error.toString()))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FlashcardSetupScreen(
                allowedModes: [QuizMode.flashcard],
              ),
            ),
          );
        },
        icon: const Icon(Icons.style_outlined),
        label: Text(l10n.flashcardFabLabel),
      ),
    );
  }
}

class _PosPill extends StatelessWidget {
  final PartOfSpeech pos;
  final Color color;
  const _PosPill({required this.pos, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pos.displayLabel(l10n),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CefrPill extends StatelessWidget {
  final CefrLevel level;
  const _CefrPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = cefrColors[level]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _JlptPill extends StatelessWidget {
  final JlptLevel level;
  const _JlptPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = jlptColors[level]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final String label;
    final Color color;
    final Color backgroundColor;
    if (!hasTranslation) {
      label = l10n.boxUnsetLabel;
      color = colors.textSecondary;
      backgroundColor = colors.textSecondary.withValues(alpha: 0.15);
    } else if (!isReviewed) {
      label = 'NEW';
      color = colors.primary;
      backgroundColor = colors.primary.withValues(alpha: 0.15);
    } else {
      final condition = WordCondition.forBox(box, colors, l10n);
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
