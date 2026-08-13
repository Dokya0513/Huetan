/// How well a word was recalled when answering a review question — the
/// "quality" input to the SM-2 algorithm (see recordAnswer() in
/// word_repository.dart). SM-2 itself uses a 0-5 scale; this app only
/// surfaces three of those values (see the flashcard screen's three answer
/// buttons), since finer-grained self-rating mostly adds hesitation without
/// meaningfully improving scheduling for a personal vocab app.
///
/// Multiple-choice screens (choice quiz, fill-blank quiz) can only ever
/// observe binary correct/incorrect, so they collapse to [didntKnow] or
/// [knew] — there's no way to detect "got it right but had to think" when
/// the answer was picked from a list rather than recalled freely.
enum AnswerQuality {
  didntKnow(0),
  struggled(3),
  knew(5);

  final int value;
  const AnswerQuality(this.value);

  bool get isCorrect => value >= 3;
}
