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

class CharacterAdvice {
  final CharacterEmotion emotion;
  final String message;
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
  final String? weakPos;

  /// Set together: the most- and least-registered part of speech when one
  /// category makes up >=50% of categorized words (and there are >=3
  /// distinct categories in use).
  final String? dominantPos;
  final String? sparsePos;

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
    return const [
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        'まずは単語を登録してみよう！',
      ),
      CharacterAdvice(
        CharacterEmotion.beginnerPointing,
        'ホームの入力欄からサクッと単語を追加できるよ',
      ),
    ];
  }

  // streak == 0 means today's flashcard session hasn't happened yet
  // (currentStreak() only counts backward from today).
  if (streak == 0) {
    if (currentHour >= streakUrgentHour) {
      return const [
        CharacterAdvice(
          CharacterEmotion.angry,
          '今日中に復習しないとストリークが途切れちゃうよ！急いで！',
        ),
        CharacterAdvice(
          CharacterEmotion.angry,
          'まだ間に合う…！今日の分だけでもやっておこう',
        ),
      ];
    }
    return const [
      CharacterAdvice(
        CharacterEmotion.question,
        '今日はまだ復習してないね。時間があるときにやってみよう！',
      ),
      CharacterAdvice(
        CharacterEmotion.studyingPc,
        '今日の分、いつやる？空き時間にサクッとどう？',
      ),
    ];
  }

  if (weakCount >= 10) {
    return [
      CharacterAdvice(
        CharacterEmotion.troubled,
        '苦手な単語が$weakCount個たまってるよ、一緒に復習しよう！',
      ),
      const CharacterAdvice(
        CharacterEmotion.troubled,
        '苦手リスト、ちょっと賑わってきたね。整理していこう',
      ),
    ];
  }

  if (dueCount > 0) {
    return [
      CharacterAdvice(
        CharacterEmotion.studyingPc,
        '今日の復習が$dueCount件残ってるよ、頑張ろう！',
      ),
      CharacterAdvice(
        CharacterEmotion.studyingTablet,
        'あと$dueCount件！サクッと終わらせちゃおう',
      ),
    ];
  }

  if (streak >= 7) {
    return [
      CharacterAdvice(CharacterEmotion.admiration, '🔥$streak日連続！その調子だよ！'),
      CharacterAdvice(CharacterEmotion.admiration, 'ここまで$streak日、継続力すごいよ！'),
    ];
  }

  // Everything's fine — vary the greeting by time of day, and mix in an
  // analytical comment about genre balance/weakness when there's one to make.
  final base = switch (_timeBucketFor(currentHour)) {
    _TimeBucket.morning => const [
        CharacterAdvice(CharacterEmotion.convinced, '☀️ 朝から偉い！その調子で一日を始めよう'),
        CharacterAdvice(CharacterEmotion.convinced, 'おはよう！今日も一問からいこう'),
      ],
    _TimeBucket.day => const [
        CharacterAdvice(CharacterEmotion.convinced, '今日もコツコツ偉い！'),
        CharacterAdvice(CharacterEmotion.convinced, 'いい調子！このまま続けよう'),
      ],
    _TimeBucket.evening => const [
        CharacterAdvice(CharacterEmotion.convinced, '🌆 夕方も継続中、ナイスペース！'),
        CharacterAdvice(CharacterEmotion.convinced, '一日お疲れさま、もうひと踏ん張りどう？'),
      ],
    _TimeBucket.night => const [
        CharacterAdvice(CharacterEmotion.convinced, '🌙 遅くまでお疲れさま、無理しすぎないでね'),
        CharacterAdvice(CharacterEmotion.convinced, '今日も一日ありがとう、ゆっくり休んでね'),
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
      CharacterAdvice(CharacterEmotion.troubled, '「$pos」でよく間違えてるみたい。重点的に復習してみる?'),
      CharacterAdvice(CharacterEmotion.troubled, '「$pos」、ちょっと苦手そうだね。一緒に見直そう'),
    ];
  }

  if (insight.dominantPos != null && insight.sparsePos != null) {
    final dominant = insight.dominantPos!;
    final sparse = insight.sparsePos!;
    return [
      CharacterAdvice(
        CharacterEmotion.question,
        '「$dominant」ばかり登録してるね。たまには「$sparse」も増やしてみる?',
      ),
      CharacterAdvice(CharacterEmotion.question, '品詞が「$dominant」に偏ってきてるかも'),
    ];
  }

  if (insight.balanced) {
    return const [
      CharacterAdvice(CharacterEmotion.admiration, '品詞のバランスがいいね！色んな単語を覚えられてる'),
      CharacterAdvice(CharacterEmotion.admiration, '偏りなく単語を登録できてる、いい調子！'),
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
    return const [
      CharacterAdvice(CharacterEmotion.beginnerPointing, 'まずは今日、1日分の記録を作ってみよう！'),
      CharacterAdvice(CharacterEmotion.beginnerPointing, 'カレンダーに色がつくと楽しいよ、やってみよう'),
    ];
  }

  if (streak >= 7) {
    return [
      CharacterAdvice(CharacterEmotion.admiration, '🔥$streak日連続！このペース最高だよ！'),
      CharacterAdvice(CharacterEmotion.admiration, '$streak日も続けられてる、本当にすごいね！'),
    ];
  }

  if (streak >= 2) {
    return [
      CharacterAdvice(CharacterEmotion.admiration, '$streak日連続で順調だね！このまま続けよう'),
      CharacterAdvice(CharacterEmotion.convinced, 'いいペース！$streak日連続キープ中だよ'),
    ];
  }

  // Streak is 0 or 1 (today not logged yet, or a streak just restarted) —
  // look at the bigger picture instead of dwelling on the broken chain.
  if (activeDaysLast30 >= 10) {
    return const [
      CharacterAdvice(CharacterEmotion.convinced, '連続じゃなくても、この30日でしっかり学べてるね！'),
      CharacterAdvice(CharacterEmotion.convinced, 'ペースはまばらでも積み重ねはちゃんとできてるよ'),
    ];
  }

  if (activeDaysLast30 >= 3) {
    return const [
      CharacterAdvice(CharacterEmotion.convinced, '少しずつでも学べてるの、ちゃんと積み重なってるよ！'),
      CharacterAdvice(CharacterEmotion.studyingPc, 'その調子！焦らずコツコツいこう'),
    ];
  }

  return const [
    CharacterAdvice(CharacterEmotion.studyingPc, '継続は力なり。また今日から積み重ねていこう！'),
    CharacterAdvice(CharacterEmotion.beginnerPointing, '一歩ずつでいいよ、また始めてみよう！'),
  ];
}
