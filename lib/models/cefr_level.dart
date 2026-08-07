/// CEFR-J levels covered by the bundled wordlist — only A1 through B2 are
/// present in the dataset (no Pre-A1/C1/C2), so those are the only values
/// modeled here.
enum CefrLevel {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2');

  final String label;
  const CefrLevel(this.label);

  static CefrLevel? fromLabel(String raw) {
    for (final level in CefrLevel.values) {
      if (level.label == raw.trim().toUpperCase()) return level;
    }
    return null;
  }
}
