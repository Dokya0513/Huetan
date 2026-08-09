# ふえたん / Fuetan

[日本語](README.md) | [English](README.en.md)

[![CI](https://github.com/Dokya0513/Huetan/actions/workflows/ci.yml/badge.svg)](https://github.com/Dokya0513/Huetan/actions/workflows/ci.yml)

会話で知らなかった単語をサッと記録し、暗記カードで復習できる語学学習アプリ（Windows デスクトップ版 / Android版）。日本語話者が英単語を学ぶモードと、英語話者が日本語の単語を学ぶモードの両方に対応しています。

## ご利用前に（免責事項・開発について）

これは個人が趣味で開発しているアプリで、動作の保証やサポート体制はありません。**利用によって生じたいかなる損害（データの消失、PCの不具合など）についても、開発者は責任を負いかねます。** ご自身の判断・自己責任でご利用いただける方のみ、ダウンロードをお願いします。

**本アプリのコードは Anthropic の Claude（AIコーディングアシスタント）を使用して開発されています。** この点をご理解・ご了承いただける方のみ、ダウンロード・ご利用をお願いします。

## インストール方法（PCに詳しくない方向け）

### Windows版

1. [Releases ページ](https://github.com/Dokya0513/Huetan/releases/latest) を開く
2. `fuetan-windows-vX.X.X.zip` をクリックしてダウンロード
3. ダウンロードした zip ファイルを右クリック →「すべて展開」を選び、好きな場所（デスクトップなど）に展開する
4. 展開してできたフォルダの中にある `english_learning.exe` をダブルクリックして起動

   > 初回起動時に「Windows によって PC が保護されました」という青い画面が出ることがあります。これは配布元の証明書が付いていない個人アプリに対して Windows が表示する一般的な警告で、危険なものではありません。
   > 画面の **「詳細情報」** をクリックし、出てきた **「実行」** ボタンを押すと起動できます。

5. 次回からは `english_learning.exe` を右クリック →「送る」→「デスクトップ（ショートカットを作成）」しておくと、デスクトップのアイコンから起動できて便利です

**注意点**

- フォルダごと展開してください。`english_learning.exe` だけを取り出して別の場所に移動すると起動できません
- 登録した単語などのデータはこの PC 内（ドキュメントフォルダ）に保存されます。別の PC に引き継ぎたい場合は、アプリ内の 設定 →「データ」からエクスポートしたファイルを、もう一方の PC で「インポート」してください
- Flutter などの開発ツールをインストールする必要は一切ありません。上記の手順だけで動きます

### Android版

1. [Releases ページ](https://github.com/Dokya0513/Huetan/releases/latest) を開く
2. `fuetan-android-vX.X.X.apk` をタップしてダウンロード
3. ダウンロードした apk ファイルをタップしてインストール

   > 「不明なアプリのインストール」を許可するかどうかの確認画面が出ることがあります。これはストア（Google Play）以外から配布された個人アプリに対して Android が表示する一般的な警告で、危険なものではありません。案内に従ってこのアプリからのインストールを許可してください。

**注意点**

- 登録した単語などのデータは端末内に保存されます。別の端末やPCに引き継ぎたい場合は、アプリ内の 設定 →「データ」からエクスポートしたファイルを、もう一方の端末で「インポート」してください

## ライセンス・利用について

このアプリは個人開発の非公開プロジェクトです。**アプリ本体（exeファイル・zip）およびソースコードの二次配布は禁止**します。共有された方はご自身の利用にとどめてください。

### クレジット

- 英単語のレベル判定に [CEFR-J Wordlist Version 1.6](http://www.cefr-j.org/download.html)（東京外国語大学 投野由紀夫研究室）を使用しています
- 日本語単語のレベル判定に [jlpt-word-list](https://github.com/elzup/jlpt-word-list)（MIT、元データ: Jonathan Waller氏 JLPT Resources / tanos.co.uk, CC BY）を使用しています
- 日本語辞書の自動取得に JMdict/EDICT（Electronic Dictionary Research and Development Group、CC BY-SA 4.0）を [jmdict-simplified](https://github.com/scriptin/jmdict-simplified) 経由で使用しています
- キャラクターイラストは [ソコスト](https://soco-st.com/) の素材を使用しています（素材自体の再配布は禁止されています）
- フォントに [Baloo 2](https://fonts.google.com/specimen/Baloo+2) / [Zen Maru Gothic](https://fonts.google.com/specimen/Zen+Maru+Gothic)（いずれも SIL Open Font License）を使用しています

## 主な機能

- **2つの学習モード**: 英語学習（日本語話者向け・UI日本語）/ 日本語学習（英語話者向け・UI英語）を設定画面でいつでも切り替え可能。UIは選んだモードに応じて自動で言語が切り替わります
- 単語の登録・編集（単語 / 意味 / 例文 / 品詞 / 発音）、一覧の検索・並び替え
- クイック追加（対象語だけサッと登録し、意味・品詞は裏側で自動取得）
- 3つの復習形式
  - 暗記カード（Leitner Systemで苦手な単語ほど出題されやすい重み付け、表裏めくって自己採点）
  - 4択クイズ（単語または意味を見せて4択で自動採点）
  - 穴埋めクイズ（例文の単語を空欄にして4択で自動採点）
- 品詞・レベルで絞り込んだ復習セッション（試験前のピンポイント対策などに）
- SRS方式の復習期限管理（正解を重ねるごとに次回復習までの間隔が伸びる）
- 辞書自動連携（英語学習モード: 辞書API、日本語学習モード: JMdict）で品詞・例文・意味・発音を自動取得、複数の語義がある単語は選択可能
- 発音再生（辞書の音声をキャッシュして再生 / 端末TTSの読み上げ、日本語は辞書データの読みを優先して誤読を防止）
- CEFR-J（英語）/ JLPT（日本語）による単語レベル判定・内訳表示
- 品詞ごとのジャンル内訳表示
- 学習カレンダー（活動日ヒートマップ、直近7日間の「追加した単語数／取り組んだ単語数」推移グラフ）
- XP・レベル、バッジ、連続学習日数（ストリーク）などのゲーミフィケーション
- マスコットキャラクターによる状況別コメント（学習状況・品詞バランス・継続日数を分析）
- データのエクスポート・インポート（バックアップ／他PCへの引き継ぎ）
- ダークモード対応

## 開発者向け情報

### 技術構成

- [Flutter](https://flutter.dev/) / Dart
- [Drift](https://drift.simonbinder.eu/)（SQLiteベースのローカルDB）
- [flutter_riverpod](https://riverpod.dev/)（状態管理）

### セットアップ

```bash
flutter pub get
flutter pub run build_runner build
```

### 実行

```bash
flutter run -d windows
# または
flutter run -d <Androidデバイス/エミュレーターのID>
```

Windows版のビルドには Visual Studio（C++ によるデスクトップ開発ワークロード）と `nuget.exe`（`flutter_tts` のビルドに使用）が必要です。
Android版のビルドには Android SDK が必要です。
