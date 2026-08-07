import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../repositories/activity_repository.dart';
import '../repositories/word_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_button.dart';
import 'session_result_screen.dart';

class _Question {
  final Word word;
  final ReviewDirection direction;
  final String prompt;
  final String correctAnswer;
  final List<String> choices;
  _Question(
    this.word,
    this.direction,
    this.prompt,
    this.correctAnswer,
    this.choices,
  );
}

/// A 4-choice, auto-graded alternative to the flip-card flashcard mode:
/// shows the word (or its meaning, depending on direction) and asks the
/// user to pick the correct match from 4 options, instead of flipping the
/// card and self-reporting.
class ChoiceQuizScreen extends ConsumerStatefulWidget {
  final List<Word> words;
  final List<ReviewDirection> allowedDirections;

  const ChoiceQuizScreen({
    super.key,
    required this.words,
    required this.allowedDirections,
  });

  @override
  ConsumerState<ChoiceQuizScreen> createState() => _ChoiceQuizScreenState();
}

class _ChoiceQuizScreenState extends ConsumerState<ChoiceQuizScreen> {
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
      final direction = widget
          .allowedDirections[rand.nextInt(widget.allowedDirections.length)];
      final isEnToJa = direction == ReviewDirection.enToJa;
      final prompt = isEnToJa ? word.english : word.japanese!;
      final correctAnswer = isEnToJa ? word.japanese! : word.english;

      final others = widget.words.where((w) => w.id != word.id).toList();
      final samePos = others
          .where((w) => w.partOfSpeech == word.partOfSpeech)
          .toList();
      final distractors = <String>{};
      for (final pool in [samePos, others]) {
        final shuffled = List.of(pool)..shuffle(rand);
        for (final w in shuffled) {
          if (distractors.length >= 3) break;
          final candidate = isEnToJa ? w.japanese : w.english;
          if (candidate == null) continue;
          if (candidate.toLowerCase() == correctAnswer.toLowerCase()) {
            continue;
          }
          distractors.add(candidate);
        }
        if (distractors.length >= 3) break;
      }

      final choices = [correctAnswer, ...distractors]..shuffle(rand);
      return _Question(word, direction, prompt, correctAnswer, choices);
    }).toList();
  }

  Future<void> _selectChoice(String choice) async {
    if (_answered) return;
    final question = _questions[_index];
    final isCorrect =
        choice.toLowerCase() == question.correctAnswer.toLowerCase();

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
          direction: question.direction,
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
    final promptIsEnglish = question.direction == ReviewDirection.enToJa;
    final choicesAreEnglish = !promptIsEnglish;

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
                      question.prompt,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontFamily: promptIsEnglish
                                ? englishDisplayFontFamily
                                : 'Zen Maru Gothic',
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
                      question.correctAnswer.toLowerCase(),
                  answered: _answered,
                  onTap: _answered ? null : () => _selectChoice(choice),
                  isEnglish: choicesAreEnglish,
                ),
              ),
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_index == _questions.length - 1 ? '結果を見る' : '次へ'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
