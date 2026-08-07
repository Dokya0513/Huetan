/// True if [word] (case-insensitive, whole word) actually occurs in
/// [sentence] — words whose example sentence uses an inflected form
/// ("played" for "play") won't match, and are excluded from the
/// fill-in-the-blank quiz rather than risk showing a sentence where the
/// blank couldn't be created.
bool wordAppearsInSentence(String word, String sentence) {
  final pattern = RegExp(
    r'\b' + RegExp.escape(word) + r'\b',
    caseSensitive: false,
  );
  return pattern.hasMatch(sentence);
}

/// Replaces the first case-insensitive whole-word match of [word] in
/// [sentence] with a blank. Caller must have already checked
/// [wordAppearsInSentence].
String blankOutWord(String word, String sentence) {
  final pattern = RegExp(
    r'\b' + RegExp.escape(word) + r'\b',
    caseSensitive: false,
  );
  return sentence.replaceFirst(pattern, '_____');
}
