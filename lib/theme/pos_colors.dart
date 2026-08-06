import 'package:flutter/material.dart';

import '../models/part_of_speech.dart';

/// Fixed color per part-of-speech category — shared by the genre
/// breakdown bar and the word list's category dot, so a given part of
/// speech always shows the same color everywhere.
const Map<PartOfSpeech, Color> posColors = {
  PartOfSpeech.noun: Color(0xFF0EA5E9),
  PartOfSpeech.verb: Color(0xFFDB2777),
  PartOfSpeech.adjective: Color(0xFF65A30D),
  PartOfSpeech.adverb: Color(0xFFEA580C),
  PartOfSpeech.phrase: Color(0xFFCA8A04),
  PartOfSpeech.other: Color(0xFF7F77DD),
};

const unsetPosLabel = '未設定';

Color colorForPos(PartOfSpeech? pos, Color unsetColor) {
  if (pos == null) return unsetColor;
  return posColors[pos] ?? unsetColor;
}
