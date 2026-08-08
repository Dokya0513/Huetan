import '../l10n/app_localizations.dart';
import 'part_of_speech.dart';

enum CharacterEmotion {
  studyingPc('assets/character/studying_pc.png'),
  studyingTablet('assets/character/studying_tablet.png'),
  beginnerPointing('assets/character/beginner_pointing.png'),
  troubled('assets/character/troubled.png'),
  angry('assets/character/angry.png'),
  admiration('assets/character/admiration.png'),
  question('assets/character/question.png'),
  convinced('assets/character/convinced.png'),
  surprised('assets/character/surprised.png');

  final String assetPath;
  const CharacterEmotion(this.assetPath);
}

/// [message] is a closure rather than a resolved [String] because these
/// candidates are built inside pure Riverpod [Provider]s (no [BuildContext]
/// access) — resolution happens later wherever a [BuildContext] is
/// available, e.g. in [CharacterCard]'s build method.
class CharacterAdvice {
  final CharacterEmotion emotion;
  final String Function(AppLocalizations l10n) message;
  const CharacterAdvice(this.emotion, this.message);
}

/// Derived from part-of-speech data so the character can comment on *what*
/// the user is studying, not just how much — computed in providers.dart
/// from [posDistributionProvider] and per-word leitner boxes, then
/// threaded through [characterAdviceCandidates] as extra candidates.
class GenreInsight {
  /// Part of speech most struggled with (weak-word ratio >= 50% among
  /// categories with >=3 words) — takes priority over balance comments
  /// since it's actionable.
  final PartOfSpeech? weakPos;

  /// Set together: the most- and least-registered part of speech when one
  /// category makes up >=50% of categorized words (and there are >=3
  /// distinct categories in use).
  final PartOfSpeech? dominantPos;
  final PartOfSpeech? sparsePos;

  /// True when >=3 categories exist and counts are roughly even (no
  /// dominant one) — worth a compliment rather than a nudge.
  final bool balanced;

  const GenreInsight({
    this.weakPos,
    this.dominantPos,
    this.sparsePos,
    this.balanced = false,
  });
}

/// After this local hour, an unstudied streak is genuinely at risk of
/// breaking before midnight — this is the only case that uses the angry
/// expression. Every other state stays encouraging/neutral so a pile of
/// new (unreviewed) words never reads as the character being upset.
const int streakUrgentHour = 21;

enum _TimeBucket { morning, day, evening, night }

_TimeBucket _timeBucketFor(int hour) {
  if (hour < 5) return _TimeBucket.night;
  if (hour < 11) return _TimeBucket.morning;
  if (hour < 17) return _TimeBucket.day;
  if (hour < 22) return _TimeBucket.evening;
  return _TimeBucket.night;
}

/// Returns every message that fits the user's current state — the caller
/// picks one (randomly, or by cycling on tap) for variety instead of
/// always showing the same line for a given state.
List<CharacterAdvice> characterAdviceCandidates({
  required int wordCount,
  required int streak,
  required int dueCount,
  required int weakCount,
  required int currentHour,
  GenreInsight? genreInsight,
}) {
  if (wordCount == 0) {
    return [
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        (l10n) => l10n.adviceNoWords1,
      ),
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        (l10n) => l10n.adviceNoWords2,
      ),
    ];
  }

  // streak == 0 means today's flashcard session hasn't happened yet
  // (currentStreak() only counts backward from today).
  if (streak == 0) {
    if (currentHour >= streakUrgentHour) {
      return [
        CharacterAdvice(
          CharacterEmotion.angry,
          (l10n) => l10n.adviceStreakUrgent1,
        ),
        CharacterAdvice(
          CharacterEmotion.angry,
          (l10n) => l10n.adviceStreakUrgent2,
        ),
      ];
    }
    return [
      CharacterAdvice(
        CharacterEmotion.question,
        (l10n) => l10n.adviceNotDoneYet1,
      ),
      CharacterAdvice(
        CharacterEmotion.studyingPc,
        (l10n) => l10n.adviceNotDoneYet2,
      ),
    ];
  }

  if (weakCount >= 10) {
    return [
      CharacterAdvice(
        CharacterEmotion.troubled,
        (l10n) => l10n.adviceManyWeak1(weakCount),
      ),
      CharacterAdvice(
        CharacterEmotion.troubled,
        (l10n) => l10n.adviceManyWeak2,
      ),
    ];
  }

  if (dueCount > 0) {
    return [
      CharacterAdvice(
        CharacterEmotion.studyingPc,
        (l10n) => l10n.adviceDueRemaining1(dueCount),
      ),
      CharacterAdvice(
        CharacterEmotion.studyingTablet,
        (l10n) => l10n.adviceDueRemaining2(dueCount),
      ),
    ];
  }

  if (streak >= 7) {
    return [
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceStreak7Home1(streak),
      ),
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceStreak7Home2(streak),
      ),
    ];
  }

  // Everything's fine — vary the greeting by time of day, and mix in an
  // analytical comment about genre balance/weakness when there's one to make.
  final base = switch (_timeBucketFor(currentHour)) {
    _TimeBucket.morning => [
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceMorning1),
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceMorning2),
    ],
    _TimeBucket.day => [
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceDay1),
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceDay2),
    ],
    _TimeBucket.evening => [
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceEvening1),
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceEvening2),
    ],
    _TimeBucket.night => [
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceNight1),
      CharacterAdvice(CharacterEmotion.convinced, (l10n) => l10n.adviceNight2),
    ],
  };

  return [...base, ..._genreAdvice(genreInsight)];
}

/// Turns part-of-speech stats into a couple of candidate lines. Weak-POS
/// takes priority over balance comments since it's the more actionable one.
List<CharacterAdvice> _genreAdvice(GenreInsight? insight) {
  if (insight == null) return const [];

  if (insight.weakPos != null) {
    final pos = insight.weakPos!;
    return [
      CharacterAdvice(
        CharacterEmotion.troubled,
        (l10n) => l10n.adviceWeakPos1(pos.displayLabel(l10n)),
      ),
      CharacterAdvice(
        CharacterEmotion.troubled,
        (l10n) => l10n.adviceWeakPos2(pos.displayLabel(l10n)),
      ),
    ];
  }

  if (insight.dominantPos != null && insight.sparsePos != null) {
    final dominant = insight.dominantPos!;
    final sparse = insight.sparsePos!;
    return [
      CharacterAdvice(
        CharacterEmotion.question,
        (l10n) => l10n.adviceDominantSparse1(
          dominant.displayLabel(l10n),
          sparse.displayLabel(l10n),
        ),
      ),
      CharacterAdvice(
        CharacterEmotion.question,
        (l10n) => l10n.adviceDominantSparse2(dominant.displayLabel(l10n)),
      ),
    ];
  }

  if (insight.balanced) {
    return [
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceBalanced1,
      ),
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceBalanced2,
      ),
    ];
  }

  return const [];
}

/// Calendar-tab-specific commentary. Unlike [characterAdviceCandidates],
/// this always stays positive — a broken streak or a quiet stretch should
/// read as "keep going," never as a scolding, since the calendar is meant
/// to encourage the next small step rather than guilt-trip a lapse.
List<CharacterAdvice> calendarAdviceCandidates({
  required int streak,
  required int activeDaysLast30,
  required int totalActiveDays,
}) {
  if (totalActiveDays == 0) {
    return [
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        (l10n) => l10n.adviceCalNoData1,
      ),
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        (l10n) => l10n.adviceCalNoData2,
      ),
    ];
  }

  if (streak >= 7) {
    return [
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceCalStreak7_1(streak),
      ),
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceCalStreak7_2(streak),
      ),
    ];
  }

  if (streak >= 2) {
    return [
      CharacterAdvice(
        CharacterEmotion.admiration,
        (l10n) => l10n.adviceCalStreak2_1(streak),
      ),
      CharacterAdvice(
        CharacterEmotion.convinced,
        (l10n) => l10n.adviceCalStreak2_2(streak),
      ),
    ];
  }

  // Streak is 0 or 1 (today not logged yet, or a streak just restarted) —
  // look at the bigger picture instead of dwelling on the broken chain.
  if (activeDaysLast30 >= 10) {
    return [
      CharacterAdvice(
        CharacterEmotion.convinced,
        (l10n) => l10n.adviceCalActive30_1,
      ),
      CharacterAdvice(
        CharacterEmotion.convinced,
        (l10n) => l10n.adviceCalActive30_2,
      ),
    ];
  }

  if (activeDaysLast30 >= 3) {
    return [
      CharacterAdvice(
        CharacterEmotion.convinced,
        (l10n) => l10n.adviceCalActive3_1,
      ),
      CharacterAdvice(
        CharacterEmotion.studyingPc,
        (l10n) => l10n.adviceCalActive3_2,
      ),
    ];
  }

  return [
    CharacterAdvice(
      CharacterEmotion.studyingPc,
      (l10n) => l10n.adviceCalDefault1,
    ),
    CharacterAdvice(
      CharacterEmotion.beginnerPointing,
      (l10n) => l10n.adviceCalDefault2,
    ),
  ];
}
