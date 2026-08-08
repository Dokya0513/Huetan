/// JLPT levels — N5 (easiest) through N1 (hardest). Shown as-is for
/// Japanese-learning-mode words rather than converted to a CEFR letter
/// grade (the two systems are kept independent, not cross-mapped).
enum JlptLevel {
  n5('N5'),
  n4('N4'),
  n3('N3'),
  n2('N2'),
  n1('N1');

  final String label;
  const JlptLevel(this.label);

  static JlptLevel? fromLabel(String raw) {
    for (final level in JlptLevel.values) {
      if (level.label == raw.trim().toUpperCase()) return level;
    }
    return null;
  }
}
