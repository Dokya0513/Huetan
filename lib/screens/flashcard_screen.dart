import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/learning_direction.dart';
import '../models/word_display.dart';
import '../providers/providers.dart';
import '../repositories/activity_repository.dart';
import '../repositories/word_repository.dart';
import '../theme/app_theme.dart';
import 'session_result_screen.dart';

class _Card {
  final Word word;
  final ReviewDirection direction;
  /// Picked once per card from [WordDisplay.allExampleSentences] — words
  /// with more than one available example rotate through a different one
  /// each session instead of always showing the same sentence.
  final String? displayExample;
  _Card(this.word, this.direction, this.displayExample);
}

class FlashcardScreen extends ConsumerStatefulWidget {
  final List<Word> words;
  final List<ReviewDirection> allowedDirections;

  const FlashcardScreen({
    super.key,
    required this.words,
    required this.allowedDirections,
  });

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  late final List<_Card> _cards;
  int _index = 0;
  bool _flipped = false;
  int _correct = 0;
  int _incorrect = 0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _cards = widget.words.map((word) {
      final direction = widget
          .allowedDirections[rand.nextInt(widget.allowedDirections.length)];
      final examples = word.allExampleSentences;
      final displayExample = examples.isEmpty
          ? null
          : examples[rand.nextInt(examples.length)];
      return _Card(word, direction, displayExample);
    }).toList();
  }

  Future<void> _answer(bool isCorrect) async {
    final card = _cards[_index];
    await ref
        .read(wordRepositoryProvider)
        .recordAnswer(
          wordId: card.word.id,
          direction: card.direction,
          isCorrect: isCorrect,
        );

    if (isCorrect) {
      final volume = ref.read(seVolumeProvider);
      ref.read(soundServiceProvider).playCorrect(volume: volume);
      _showXpPopup();
    }

    setState(() {
      if (isCorrect) {
        _correct++;
      } else {
        _incorrect++;
      }
    });

    if (_index == _cards.length - 1) {
      await ref
          .read(activityRepositoryProvider)
          .recordActivity(ActivityType.flashcard);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionResultScreen(
              correctCount: _correct,
              incorrectCount: _incorrect,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _index++;
      _flipped = false;
    });
  }

  void _showXpPopup() {
    final overlay = Overlay.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final secondaryColor = context.colors.secondary;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: screenHeight * 0.35,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.scale(scale: 0.6 + value * 0.6, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '+10 XP',
                  style: TextStyle(
                    fontFamily: 'Baloo 2',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 900), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_index];
    // selectSessionWords() only returns words with a Japanese meaning set,
    // so japanese is guaranteed non-null for any card shown here.
    final front = card.direction == ReviewDirection.enToJa
        ? card.word.english
        : card.word.japanese!;
    final back = card.direction == ReviewDirection.enToJa
        ? card.word.japanese!
        : card.word.english;
    final frontIsEnglish = card.direction == ReviewDirection.enToJa;
    final backIsEnglish = !frontIsEnglish;
    final l10n = AppLocalizations.of(context)!;
    final baseWordStyle = Theme.of(context).textTheme.headlineMedium;
    TextStyle? wordStyle(bool isEnglish) => baseWordStyle?.copyWith(
      fontFamily: isEnglish ? englishDisplayFontFamily : 'Zen Maru Gothic',
    );

    void speak() => ref
        .read(pronunciationServiceProvider)
        .speak(
          card.word.speechText,
          audioUrl: card.word.audioUrl,
          volume: ref.read(voiceVolumeProvider),
          languageCode: card.word.direction == LearningDirection.enTarget
              ? 'en-US'
              : 'ja-JP',
        );

    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / ${_cards.length}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index) / _cards.length),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: Card(
                  elevation: 4,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _flipped
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        back,
                                        style: wordStyle(backIsEnglish),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: speak,
                                      tooltip: l10n.playPronunciationTooltip,
                                      icon: const Icon(
                                        Icons.volume_up_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                if (card.displayExample != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    card.displayExample!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    front,
                                    style: wordStyle(frontIsEnglish),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  onPressed: speak,
                                  tooltip: l10n.playPronunciationTooltip,
                                  icon: const Icon(Icons.volume_up_outlined),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_flipped)
              Text(l10n.tapToReveal)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _answer(false),
                      child: Text(l10n.dontKnowButton),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _answer(true),
                      child: Text(l10n.knowButton),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
