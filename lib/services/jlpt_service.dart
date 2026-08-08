import 'package:flutter/services.dart' show rootBundle;

import '../models/jlpt_level.dart';

/// Looks up a word's JLPT level from the bundled wordlist (offline — no
/// network call). Attribution: word list aggregated by the jlpt-word-list
/// project (https://github.com/elzup/jlpt-word-list, MIT), whose underlying
/// data traces to Jonathan Waller's JLPT Resources (tanos.co.uk), CC BY.
class JlptService {
  static const _assetPath = 'assets/jlpt/jlpt_wordlist.csv';

  Map<String, JlptLevel>? _lookup;

  /// Loads (and caches) the full word -> level map, for callers that need
  /// to look up many words at once (e.g. the distribution bar).
  Future<Map<String, JlptLevel>> loadWordlist() async {
    final cached = _lookup;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final map = <String, JlptLevel>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final commaIndex = trimmed.lastIndexOf(',');
      if (commaIndex < 0) continue;
      final word = trimmed.substring(0, commaIndex);
      final level = JlptLevel.fromLabel(trimmed.substring(commaIndex + 1));
      if (level != null) map[word] = level;
    }
    _lookup = map;
    return map;
  }

  /// Returns the JLPT level for [japanese], or null if the word isn't in
  /// the wordlist.
  Future<JlptLevel?> lookup(String japanese) async {
    final map = await loadWordlist();
    return map[japanese.trim().toLowerCase()];
  }
}
