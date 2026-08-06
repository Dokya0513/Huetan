// Dev-only helper: backfills partOfSpeech (and example/audio where still
// empty) for words already registered before/without the dictionary
// auto-fetch — queries dictionaryapi.dev for each word missing a part of
// speech and fills it in, same "first sense found" behavior as the
// quick-add background fill. Run with: dart run tool/backfill_pos.dart
import 'dart:io';

import 'package:english_learning/services/dictionary_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  final dbPath = p.join(
    Platform.environment['USERPROFILE']!,
    'Documents',
    'english_learning.sqlite',
  );
  if (!File(dbPath).existsSync()) {
    stderr.writeln(
      'Database not found at $dbPath — run the app at least once first.',
    );
    exit(1);
  }

  final db = sqlite3.open(dbPath);
  final rows = db.select(
    'SELECT id, english FROM words WHERE part_of_speech IS NULL',
  );

  print('${rows.length} word(s) missing part of speech.');

  final service = DictionaryService();
  var updated = 0;
  final notFound = <String>[];

  for (final row in rows) {
    final id = row['id'] as int;
    final english = row['english'] as String;

    // Retry a couple of times with backoff — the free API rate-limits
    // fairly aggressively, and a bare miss reads the same as "not a real
    // word" otherwise.
    DictionaryLookupResult? result;
    for (var attempt = 0; attempt < 3; attempt++) {
      result = await service.lookup(english);
      if (result != null && result.senses.isNotEmpty) break;
      await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
    }

    if (result == null || result.senses.isEmpty) {
      notFound.add(english);
      await Future.delayed(const Duration(milliseconds: 600));
      continue;
    }

    final sense = result.senses.first;
    db.execute(
      'UPDATE words SET part_of_speech = ?, '
      'example_sentence = COALESCE(example_sentence, ?), '
      'audio_url = COALESCE(audio_url, ?) WHERE id = ?',
      [sense.partOfSpeech.label, sense.example, result.audioUrl, id],
    );
    updated++;
    print('  $english -> ${sense.partOfSpeech.label}');

    // Be polite to the free API.
    await Future.delayed(const Duration(milliseconds: 600));
  }

  db.dispose();
  print('Updated $updated word(s).');
  if (notFound.isNotEmpty) {
    print(
      'Not found in dictionary (${notFound.length}): ${notFound.join(", ")}',
    );
  }
}
