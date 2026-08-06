import 'dart:convert';

import 'package:http/http.dart' as http;

class DictionaryLookupResult {
  final String? partOfSpeech;
  final String? example;
  final String? audioUrl;

  DictionaryLookupResult({this.partOfSpeech, this.example, this.audioUrl});
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

      String? partOfSpeech;
      String? example;
      final meanings = entry['meanings'];
      if (meanings is List) {
        for (final meaning in meanings) {
          if (meaning is! Map<String, dynamic>) continue;
          partOfSpeech ??= meaning['partOfSpeech'] as String?;
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
          if (example != null) break;
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

      return DictionaryLookupResult(
        partOfSpeech: partOfSpeech,
        example: example,
        audioUrl: audioUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
