import '../l10n/app_localizations.dart';

/// Fixed set of categories the app uses for 品詞, deliberately coarser than
/// a dictionary's full grammatical tagging — a handful of buckets keeps the
/// genre breakdown bar / analytics readable, and gives the user a picker
/// instead of free text (which drifted between "verb"/"動詞"/etc).
enum PartOfSpeech {
  noun('名詞'),
  verb('動詞'),
  adjective('形容詞'),
  adverb('副詞'),
  phrase('フレーズ'),
  other('その他');

  final String label;
  const PartOfSpeech(this.label);
}

/// UI-facing localized text, kept separate from [PartOfSpeech.label] which
/// is persisted into the DB and used for exact-string filter matching — that
/// value must stay fixed Japanese regardless of the app's locale.
extension PartOfSpeechDisplay on PartOfSpeech {
  String displayLabel(AppLocalizations l10n) {
    switch (this) {
      case PartOfSpeech.noun:
        return l10n.posNoun;
      case PartOfSpeech.verb:
        return l10n.posVerb;
      case PartOfSpeech.adjective:
        return l10n.posAdjective;
      case PartOfSpeech.adverb:
        return l10n.posAdverb;
      case PartOfSpeech.phrase:
        return l10n.posPhrase;
      case PartOfSpeech.other:
        return l10n.posOther;
    }
  }
}

/// Reverse-lookup by the stored label (the DB column just holds this
/// string — no separate encoding).
PartOfSpeech? partOfSpeechFromLabel(String? label) {
  if (label == null) return null;
  for (final pos in PartOfSpeech.values) {
    if (pos.label == label) return pos;
  }
  return null;
}

/// Maps a dictionaryapi.dev part-of-speech string ("noun", "verb", ...)
/// onto our fixed categories. Also tolerant of already-Japanese-labeled or
/// raw English values, so words saved before this feature existed (when
/// 品詞 was free text) still resolve to a sensible bucket instead of
/// showing as unset.
PartOfSpeech mapToPartOfSpeech(String raw) {
  final byLabel = partOfSpeechFromLabel(raw);
  if (byLabel != null) return byLabel;

  switch (raw.toLowerCase().trim()) {
    case 'noun':
      return PartOfSpeech.noun;
    case 'verb':
      return PartOfSpeech.verb;
    case 'adjective':
      return PartOfSpeech.adjective;
    case 'adverb':
      return PartOfSpeech.adverb;
    default:
      return PartOfSpeech.other;
  }
}
