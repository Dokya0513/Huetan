import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/part_of_speech.dart';

/// One grammatical sense of a looked-up word (e.g. "play" as a verb vs.
/// as a noun) — the API often returns several, and letting the caller
/// pick avoids silently assuming the first one is the one the user meant.
class DictionarySense {
  final PartOfSpeech partOfSpeech;
  final String? example;
  /// A short meaning/gloss for this sense, if the source provides one —
  /// dictionaryapi.dev (English) doesn't, so this stays null there and the
  /// user always types the meaning by hand; JMdict (Japanese) does, so
  /// JapaneseDictionaryService can use it to suggest a meaning.
  final String? meaning;
  const DictionarySense({
    required this.partOfSpeech,
    this.example,
    this.meaning,
  });
}

class DictionaryLookupResult {
  final List<DictionarySense> senses;
  final String? audioUrl;
  /// Kana reading for the looked-up word, when the source provides one
  /// (JMdict does; dictionaryapi.dev doesn't, so this stays null there).
  /// Used for jaTarget TTS instead of raw kanji — see
  /// [Words.japaneseReading]'s doc comment for why.
  final String? reading;
  const DictionaryLookupResult({
    required this.senses,
    this.audioUrl,
    this.reading,
  });
}

/// Looks up an English word using the free dictionaryapi.dev API
/// (no API key required). Returns null if the word isn't found or the
/// request fails.
class DictionaryService {
  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  Future<DictionaryLookupResult?> lookup(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/${Uri.encodeComponent(trimmed)}'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;
      final entry = data.first as Map<String, dynamic>;

      // Group by our (coarser) PartOfSpeech category, keeping the first
      // example found for each — e.g. the API's "pronoun" and
      // "preposition" both fold into 「その他」 rather than becoming
      // separate picker entries.
      final senses = <PartOfSpeech, String?>{};
      final meanings = entry['meanings'];
      if (meanings is List) {
        for (final meaning in meanings) {
          if (meaning is! Map<String, dynamic>) continue;
          final apiPos = meaning['partOfSpeech'] as String?;
          if (apiPos == null) continue;
          final pos = mapToPartOfSpeech(apiPos);
          if (senses.containsKey(pos)) continue;

          String? example;
          final definitions = meaning['definitions'];
          if (definitions is List) {
            for (final definition in definitions) {
              if (definition is! Map<String, dynamic>) continue;
              final ex = definition['example'] as String?;
              if (ex != null && ex.isNotEmpty) {
                example = ex;
                break;
              }
            }
          }
          senses[pos] = example;
        }
      }

      String? audioUrl;
      final phonetics = entry['phonetics'];
      if (phonetics is List) {
        for (final phonetic in phonetics) {
          if (phonetic is! Map<String, dynamic>) continue;
          final audio = phonetic['audio'] as String?;
          if (audio != null && audio.isNotEmpty) {
            audioUrl = audio;
            break;
          }
        }
      }

      if (senses.isEmpty) {
        return DictionaryLookupResult(senses: const [], audioUrl: audioUrl);
      }

      return DictionaryLookupResult(
        senses: senses.entries
            .map((e) => DictionarySense(partOfSpeech: e.key, example: e.value))
            .toList(),
        audioUrl: audioUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
