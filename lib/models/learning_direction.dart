/// Which language a word belongs to studying: [enTarget] for a Japanese
/// speaker learning English (the app's original mode), [jaTarget] for an
/// English speaker learning Japanese. Stamped onto each word at creation
/// time and never changed afterward, so switching the app-wide mode never
/// reinterprets existing data.
///
/// Distinct from [ReviewDirection] in word_repository.dart, which is the
/// per-quiz presentation direction (en2ja/ja2en) and unrelated to this.
enum LearningDirection {
  enTarget('enTarget'),
  jaTarget('jaTarget');

  final String dbValue;
  const LearningDirection(this.dbValue);

  static LearningDirection fromDbValue(String value) => values.firstWhere(
    (d) => d.dbValue == value,
    orElse: () => LearningDirection.enTarget,
  );
}
