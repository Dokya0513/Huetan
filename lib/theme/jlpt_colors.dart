import 'package:flutter/material.dart';

import '../models/jlpt_level.dart';

/// Fixed color per JLPT level, progressing from "easy" (teal) to "hard"
/// (deep purple) so the distribution bar reads as a difficulty gauge.
/// Deliberately distinct from [cefrColors] so the two pill systems stay
/// visually distinguishable, though in practice they never co-occur (a
/// word is always exactly one learning direction).
const Map<JlptLevel, Color> jlptColors = {
  JlptLevel.n5: Color(0xFF14B8A6),
  JlptLevel.n4: Color(0xFF65A30D),
  JlptLevel.n3: Color(0xFFF97316),
  JlptLevel.n2: Color(0xFFDB2777),
  JlptLevel.n1: Color(0xFF9333EA),
};

Color colorForJlpt(JlptLevel? level, Color outOfScopeColor) {
  if (level == null) return outOfScopeColor;
  return jlptColors[level] ?? outOfScopeColor;
}
