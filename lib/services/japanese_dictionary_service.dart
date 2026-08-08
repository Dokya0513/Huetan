import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/part_of_speech.dart';
import 'dictionary_service.dart' show DictionaryLookupResult, DictionarySense;

/// Looks up a Japanese word's meaning/part-of-speech from a bundled,
/// pre-processed subset of JMdict (offline — no network call), the
/// Japanese-learning-mode counterpart to [DictionaryService]. Unlike
/// dictionaryapi.dev, JMdict provides actual English glosses, so results
/// here also carry [DictionarySense.meaning] for auto-filling the meaning
/// field — dictionaryapi.dev's results never do.
///
/// No audio or example sentences are available from this source, so
/// [DictionaryLookupResult.audioUrl] is always null and
/// [DictionarySense.example] is always null.
///
/// Attribution: JMdict/EDICT dictionary files, property of the Electronic
/// Dictionary Research and Development Group (https://www.edrdg.org/),
/// used under Creative Commons Attribution-ShareAlike 4.0. Processed via
/// https://github.com/scriptin/jmdict-simplified (also CC BY-SA 4.0),
/// filtered to common-only entries.
class JapaneseDictionaryService {
  static const _assetPath = 'assets/jmdict/jmdict_common.json';

  Map<String, _JmdictEntry>? _lookup;

  Future<Map<String, _JmdictEntry>> _loadIndex() async {
    final cached = _lookup;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final map = <String, _JmdictEntry>{};
    decoded.forEach((word, entryJson) {
      if (entryJson is! Map<String, dynamic>) return;
      final sensesJson = entryJson['senses'];
      if (sensesJson is! List) return;
      final senses = <DictionarySense>[];
      for (final entry in sensesJson) {
        if (entry is! Map<String, dynamic>) continue;
        final posName = entry['pos'] as String?;
        final gloss = entry['gloss'] as String?;
        if (posName == null) continue;
        final pos = PartOfSpeech.values.asNameMap()[posName];
        if (pos == null) continue;
        senses.add(DictionarySense(partOfSpeech: pos, meaning: gloss));
      }
      if (senses.isNotEmpty) {
        map[word] = _JmdictEntry(
          senses: senses,
          reading: entryJson['reading'] as String?,
        );
      }
    });
    _lookup = map;
    return map;
  }

  Future<DictionaryLookupResult?> lookup(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    final index = await _loadIndex();
    final entry = index[trimmed];
    if (entry == null) return null;
    return DictionaryLookupResult(senses: entry.senses, reading: entry.reading);
  }
}

class _JmdictEntry {
  final List<DictionarySense> senses;
  final String? reading;
  const _JmdictEntry({required this.senses, this.reading});
}
