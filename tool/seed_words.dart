// Dev-only helper: inserts ~100 common English words with Japanese meanings
// directly into the app's SQLite database, for manual testing without
// typing them in one by one. Run with: dart run tool/seed_words.dart
//
// Not part of the app itself; safe to delete once testing is done.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const List<List<String>> words = [
  ['abandon', '捨てる、放棄する'],
  ['ability', '能力'],
  ['absolute', '絶対的な'],
  ['accept', '受け入れる'],
  ['access', 'アクセス、利用する'],
  ['accident', '事故'],
  ['account', '口座、説明'],
  ['achieve', '達成する'],
  ['acquire', '獲得する'],
  ['adapt', '適応する'],
  ['addition', '追加'],
  ['address', '住所、演説する'],
  ['adjust', '調整する'],
  ['admit', '認める'],
  ['adult', '大人'],
  ['advance', '前進する'],
  ['advantage', '利点'],
  ['adventure', '冒険'],
  ['advice', '助言'],
  ['affect', '影響する'],
  ['afford', '(金銭的・時間的に)余裕がある'],
  ['afraid', '怖がって'],
  ['agency', '代理店'],
  ['agree', '同意する'],
  ['agreement', '合意'],
  ['ahead', '前方に'],
  ['aim', '狙う、目標'],
  ['aircraft', '航空機'],
  ['alarm', '警報'],
  ['alive', '生きている'],
  ['allow', '許す'],
  ['almost', 'ほとんど'],
  ['alone', 'ひとりで'],
  ['along', '沿って'],
  ['alter', '変更する'],
  ['although', '～だけれども'],
  ['amazing', '驚くべき'],
  ['among', '～の間で'],
  ['amount', '量'],
  ['ancient', '古代の'],
  ['anger', '怒り'],
  ['angle', '角度'],
  ['angry', '怒っている'],
  ['animal', '動物'],
  ['announce', '発表する'],
  ['annual', '年次の'],
  ['another', 'もう一つの'],
  ['answer', '答え'],
  ['anxious', '心配して'],
  ['apart', '離れて'],
  ['apologize', '謝る'],
  ['appear', '現れる'],
  ['apple', 'りんご'],
  ['apply', '申し込む、適用する'],
  ['appoint', '任命する'],
  ['approach', '近づく、取り組み方'],
  ['appropriate', '適切な'],
  ['approve', '承認する'],
  ['area', '地域'],
  ['argue', '議論する'],
  ['arise', '生じる'],
  ['arm', '腕'],
  ['army', '軍隊'],
  ['around', '～の周りに'],
  ['arrange', '手配する'],
  ['arrest', '逮捕する'],
  ['arrival', '到着'],
  ['arrive', '到着する'],
  ['article', '記事'],
  ['artist', '芸術家'],
  ['ashamed', '恥じて'],
  ['aside', 'わきに'],
  ['ask', '尋ねる'],
  ['aspect', '側面'],
  ['assist', '助ける'],
  ['assume', '想定する'],
  ['assure', '保証する'],
  ['athlete', '運動選手'],
  ['atmosphere', '雰囲気、大気'],
  ['attach', '添付する'],
  ['attack', '攻撃する'],
  ['attempt', '試み'],
  ['attend', '出席する'],
  ['attention', '注意'],
  ['attitude', '態度'],
  ['attract', '引き付ける'],
  ['audience', '観客'],
  ['author', '著者'],
  ['authority', '権威'],
  ['available', '利用可能な'],
  ['average', '平均'],
  ['avoid', '避ける'],
  ['award', '賞'],
  ['aware', '気づいて'],
  ['awful', 'ひどい'],
  ['baby', '赤ちゃん'],
  ['background', '背景'],
  ['balance', 'バランス'],
  ['ball', 'ボール'],
  ['band', 'バンド、帯'],
  ['bank', '銀行'],
  ['base', '基地、基礎'],
  ['basic', '基本的な'],
  ['basis', '基礎'],
];

void main() {
  final dbPath = p.join(
    Platform.environment['USERPROFILE']!,
    'Documents',
    'english_learning.sqlite',
  );
  if (!File(dbPath).existsSync()) {
    stderr.writeln(
      'Database not found at $dbPath — run the app at least once first so '
      'it creates the database.',
    );
    exit(1);
  }

  final db = sqlite3.open(dbPath);
  final stmt = db.prepare(
    'INSERT INTO words (english, japanese, leitner_box, created_at) '
    'VALUES (?, ?, 1, ?)',
  );

  var inserted = 0;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  for (final pair in words) {
    final exists = db.select(
      'SELECT id FROM words WHERE english = ?',
      [pair[0]],
    );
    if (exists.isNotEmpty) continue;
    stmt.execute([pair[0], pair[1], now]);
    inserted++;
  }

  stmt.dispose();
  db.dispose();
  print('Inserted $inserted new word(s) (skipped duplicates).');
}
