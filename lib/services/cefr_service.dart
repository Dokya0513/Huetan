import 'package:flutter/services.dart' show rootBundle;

import '../models/cefr_level.dart';

/// Looks up a word's CEFR-J level from the bundled wordlist (offline —
/// no network call, unlike the dictionary lookup). Attribution:
/// 『CEFR-J Wordlist Version 1.6』東京外国語大学投野由紀夫研究室.
/// (http://www.cefr-j.org/download.html)
class CefrService {
  static const _assetPath = 'assets/cefr/cefrj_wordlist.csv';

  Map<String, CefrLevel>? _lookup;

  /// Loads (and caches) the full word -> level map, for callers that need
  /// to look up many words at once (e.g. the distribution bar).
  Future<Map<String, CefrLevel>> loadWordlist() async {
    final cached = _lookup;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final map = <String, CefrLevel>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final commaIndex = trimmed.lastIndexOf(',');
      if (commaIndex < 0) continue;
      final word = trimmed.substring(0, commaIndex);
      final level = CefrLevel.fromLabel(trimmed.substring(commaIndex + 1));
      if (level != null) map[word] = level;
    }
    _lookup = map;
    return map;
  }

  /// Returns the CEFR-J level for [english], or null if the word (or
  /// phrase) isn't in the wordlist — proper nouns, technical terms, and
  /// most multi-word phrases fall outside its ~7000-word coverage.
  Future<CefrLevel?> lookup(String english) async {
    final map = await loadWordlist();
    return map[english.trim().toLowerCase()];
  }
}
