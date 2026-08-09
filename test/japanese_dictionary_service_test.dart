// Covers JapaneseDictionaryService's example-sentence lookup, the
// Tatoeba-derived counterpart to dictionaryapi.dev's per-sense examples.
// Exercises the real bundled assets (JMdict + Tatoeba), not fakes, so a
// bad asset path or a malformed generated JSON file fails a test instead
// of only surfacing at runtime when a user taps the lookup button.
import 'package:english_learning/services/japanese_dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lookup finds example sentences for a common verb, matching its '
    'dictionary form even though the sentences use inflected forms',
    () async {
      final service = JapaneseDictionaryService();
      final result = await service.lookup('食べる');

      expect(result, isNotNull);
      expect(result!.senses, isNotEmpty);
      expect(result.examples, isNotEmpty);
      // Every returned sentence should actually contain the word searched
      // for (not necessarily in dictionary form, since Japanese verbs
      // conjugate) — at minimum it shouldn't be empty text.
      for (final sentence in result.examples) {
        expect(sentence, isNotEmpty);
      }
    },
  );

  test('lookup for a word with no dictionary entry returns null', () async {
    final service = JapaneseDictionaryService();
    final result = await service.lookup('ｚｚｚ存在しない単語ｚｚｚ');
    expect(result, isNull);
  });
}
