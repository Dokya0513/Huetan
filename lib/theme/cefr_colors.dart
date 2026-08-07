import 'package:flutter/material.dart';

import '../models/cefr_level.dart';

/// Fixed color per CEFR level, roughly progressing from "easy" (green) to
/// "hard" (pink) so the distribution bar reads as a difficulty gauge.
const Map<CefrLevel, Color> cefrColors = {
  CefrLevel.a1: Color(0xFF65A30D),
  CefrLevel.a2: Color(0xFF0EA5E9),
  CefrLevel.b1: Color(0xFFEA580C),
  CefrLevel.b2: Color(0xFFDB2777),
};

const cefrOutOfScopeLabel = '対象外';

Color colorForCefr(CefrLevel? level, Color outOfScopeColor) {
  if (level == null) return outOfScopeColor;
  return cefrColors[level] ?? outOfScopeColor;
}
