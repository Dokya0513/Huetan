import 'package:flutter/material.dart';

/// Fixed palette cycled for tag color-coding — shared by the genre
/// distribution bar and the per-word tag dots so the same tag always shows
/// the same color everywhere.
const tagColorPalette = [
  Color(0xFF0EA5E9),
  Color(0xFFDB2777),
  Color(0xFF65A30D),
  Color(0xFFEA580C),
  Color(0xFFCA8A04),
  Color(0xFF7F77DD),
];

const untaggedLabel = '未分類';

/// Picks a stable color for [tag] based on its position in [allTagNames]
/// (expected to be the alphabetically-sorted list of every tag in use), so
/// a tag's color doesn't shift as word counts change.
Color colorForTag(String tag, List<String> allTagNames, Color untaggedColor) {
  if (tag == untaggedLabel) return untaggedColor;
  final index = allTagNames.indexOf(tag);
  if (index < 0) return untaggedColor;
  return tagColorPalette[index % tagColorPalette.length];
}
