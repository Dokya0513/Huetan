import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single answer option in a multiple-choice quiz — highlights green when
/// it's the correct answer and red when it was the (wrong) pick, once
/// [answered] is true. Shared by the fill-in-the-blank and 4-choice quiz
/// screens so both grade/highlight identically.
class ChoiceButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCorrectChoice;
  final bool answered;
  final VoidCallback? onTap;
  final bool isEnglish;

  const ChoiceButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCorrectChoice,
    required this.answered,
    required this.onTap,
    this.isEnglish = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color? backgroundColor;
    Color? borderColor;
    if (answered && isCorrectChoice) {
      backgroundColor = colors.successBg;
      borderColor = colors.success;
    } else if (answered && isSelected) {
      backgroundColor = colors.dangerBg;
      borderColor = colors.danger;
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: borderColor != null ? BorderSide(color: borderColor) : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: isEnglish
                ? englishDisplayFontFamily
                : 'Zen Maru Gothic',
          ),
        ),
      ),
    );
  }
}
