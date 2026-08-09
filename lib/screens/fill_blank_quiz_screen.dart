import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/fill_blank.dart';
import '../models/learning_direction.dart';
import '../models/word_display.dart';
import '../providers/providers.dart';
import '../repositories/activity_repository.dart';
import '../repositories/word_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_button.dart';
import 'session_result_screen.dart';

class _Question {
  final Word word;
  final String blankedSentence;
  final List<String> choices;
  _Question(this.word, this.blankedSentence, this.choices);
}

/// A multiple-choice "fill in the blank" quiz using each word's example
/// sentence, instead of the flip-card front/back format. [words] must
/// already be filtered to ones whose exampleSentence actually contains the
/// word (see [wordAppearsInSentence]) — this screen assumes that's true and
/// blanks out the first match unconditionally.
class FillBlankQuizScreen extends ConsumerStatefulWidget {
  final List<Word> words;
  const FillBlankQuizScreen({super.key, required this.words});

  @override
  ConsumerState<FillBlankQuizScreen> createState() =>
      _FillBlankQuizScreenState();
}

class _FillBlankQuizScreenState extends ConsumerState<FillBlankQuizScreen> {
  late final List<_Question> _questions;
  int _index = 0;
  int _correct = 0;
  int _incorrect = 0;
  String? _selectedChoice;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _questions = widget.words.map((word) {
      // Rotate through whichever of the word's example sentences actually
      // contain it, instead of always the primary one — words with only
      // one example (the common case) are unaffected.
      final candidates = word.allExampleSentences
          .where((sentence) => wordAppearsInSentence(word.targetText, sentence))
          .toList();
      final sentence = candidates.isEmpty
          ? word.exampleSentence!
          : candidates[rand.nextInt(candidates.length)];
      final blanked = blankOutWord(word.targetText, sentence);

      final others = widget.words
          .where((w) => w.id != word.id)
          .where(
            (w) =>
                w.targetText.toLowerCase() != word.targetText.toLowerCase(),
          )
          .toList();
      // Prefer distractors of the same part of speech for a bit of a
      // challenge, falling back to any other word if there aren't enough.
      final samePos = others
          .where((w) => w.partOfSpeech == word.partOfSpeech)
          .toList();
      final distractors = <String>{};
      for (final pool in [samePos, others]) {
        final shuffled = List.of(pool)..shuffle(rand);
        for (final w in shuffled) {
          if (distractors.length >= 3) break;
          distractors.add(w.targetText);
        }
        if (distractors.length >= 3) break;
      }

      final choices = [word.targetText, ...distractors]..shuffle(rand);
      return _Question(word, blanked, choices);
    }).toList();
  }

  Future<void> _selectChoice(String choice) async {
    if (_answered) return;
    final question = _questions[_index];
    final isCorrect =
        choice.toLowerCase() == question.word.targetText.toLowerCase();

    setState(() {
      _selectedChoice = choice;
      _answered = true;
      if (isCorrect) {
        _correct++;
      } else {
        _incorrect++;
      }
    });

    await ref
        .read(wordRepositoryProvider)
        .recordAnswer(
          wordId: question.word.id,
          direction: ReviewDirection.enToJa,
          isCorrect: isCorrect,
        );

    if (isCorrect) {
      final volume = ref.read(seVolumeProvider);
      ref.read(soundServiceProvider).playCorrect(volume: volume);
    }
  }

  Future<void> _next() async {
    if (_index == _questions.length - 1) {
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
      _selectedChoice = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];
    final l10n = AppLocalizations.of(context)!;
    final isEnTargetQuestion =
        question.word.direction == LearningDirection.enTarget;

    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / ${_questions.length}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(value: _index / _questions.length),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      question.blankedSentence,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: isEnTargetQuestion
                                ? englishDisplayFontFamily
                                : null,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            for (final choice in question.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceButton(
                  label: choice,
                  isSelected: choice == _selectedChoice,
                  isCorrectChoice:
                      choice.toLowerCase() ==
                      question.word.targetText.toLowerCase(),
                  answered: _answered,
                  onTap: _answered ? null : () => _selectChoice(choice),
                  isEnglish: isEnTargetQuestion,
                ),
              ),
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _index == _questions.length - 1
                        ? l10n.viewResultButton
                        : l10n.onboardingNext,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
