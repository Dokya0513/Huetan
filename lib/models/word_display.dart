import 'dart:convert';

import '../data/database.dart';
import 'learning_direction.dart';

/// Resolves which of a [Word]'s two text columns is the word actually being
/// studied vs. its already-known-language meaning, based on the word's own
/// [Word.learningDirection] — independent of the app's *current* mode, so a
/// word keeps displaying correctly even if the user later switches modes.
///
/// Screens that quiz on literal English-text-vs-Japanese-text pairs (e.g.
/// the flashcard/choice-quiz flip-card format) don't need this: they work
/// the same regardless of which side is the "target", since both sides are
/// always real text. This extension is for screens that need to know
/// specifically which word is being learned — the word list, CEFR/JLPT
/// lookups, and the fill-in-the-blank quiz's example-sentence matching.
extension WordDisplay on Word {
  LearningDirection get direction => LearningDirection.fromDbValue(
    learningDirection,
  );

  /// The word being learned: `english` for enTarget, `japanese` for
  /// jaTarget (always non-null in practice for jaTarget rows, since the
  /// target field is required at entry time).
  String get targetText =>
      direction == LearningDirection.enTarget ? english : (japanese ?? '');

  /// The already-known-language meaning, or null if not filled in yet.
  /// `english` is NOT NULL at the schema level, so a jaTarget word with its
  /// meaning left blank stores '' rather than null — normalized to null
  /// here the same way `japanese` already is for enTarget words.
  String? get meaningText {
    if (direction == LearningDirection.enTarget) return japanese;
    return english.isEmpty ? null : english;
  }

  /// Text to hand to TTS — prefers [Words.japaneseReading] over the raw
  /// kanji spelling for jaTarget words, since Japanese TTS engines
  /// frequently mispronounce kanji with multiple valid readings otherwise
  /// (e.g. 来る as "kitaru" instead of "kuru"). Falls back to [targetText]
  /// when no reading was captured (word entered without a dictionary
  /// lookup) — still correct for enTarget (plain English) and for
  /// kana-only jaTarget words (no reading ambiguity to begin with).
  String get speechText {
    if (direction == LearningDirection.jaTarget && japaneseReading != null) {
      return japaneseReading!;
    }
    return targetText;
  }

  /// All known example sentences for this word — the primary
  /// [exampleSentence] followed by any [extraExamples] captured from a
  /// dictionary lookup that returned more than one. Used to rotate through
  /// varied contexts on review instead of always showing the same sentence.
  /// Empty if the word has no example sentence at all.
  List<String> get allExampleSentences {
    final primary = exampleSentence;
    final extrasJson = extraExamples;
    return [
      if (primary != null && primary.isNotEmpty) primary,
      if (extrasJson != null && extrasJson.isNotEmpty)
        ...(jsonDecode(extrasJson) as List).cast<String>(),
    ];
  }
}
