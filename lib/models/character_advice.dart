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

  // Everything's fine — vary the greeting by time of day.
  switch (_timeBucketFor(currentHour)) {
    case _TimeBucket.morning:
      return const [
        CharacterAdvice(CharacterEmotion.convinced, '☀️ 朝から偉い！その調子で一日を始めよう'),
        CharacterAdvice(CharacterEmotion.convinced, 'おはよう！今日も一問からいこう'),
      ];
    case _TimeBucket.day:
      return const [
        CharacterAdvice(CharacterEmotion.convinced, '今日もコツコツ偉い！'),
        CharacterAdvice(CharacterEmotion.convinced, 'いい調子！このまま続けよう'),
      ];
    case _TimeBucket.evening:
      return const [
        CharacterAdvice(CharacterEmotion.convinced, '🌆 夕方も継続中、ナイスペース！'),
        CharacterAdvice(CharacterEmotion.convinced, '一日お疲れさま、もうひと踏ん張りどう？'),
      ];
    case _TimeBucket.night:
      return const [
        CharacterAdvice(CharacterEmotion.convinced, '🌙 遅くまでお疲れさま、無理しすぎないでね'),
        CharacterAdvice(CharacterEmotion.convinced, '今日も一日ありがとう、ゆっくり休んでね'),
      ];
  }
}
