# ふえたん

会話で知らなかった英単語をサッと記録し、暗記カードで復習できる英単語学習アプリ。

## 主な機能

- 単語の登録・編集（英単語 / 意味 / 例文 / 品詞 / 複数タグ）
- クイック追加（英単語だけサッと登録し、意味は後から入力）
- 暗記カード（Leitner Systemで苦手な単語ほど出題されやすい重み付け）
- SRS方式の復習期限管理（正解を重ねるごとに次回復習までの間隔が伸びる）
- 辞書API連携（品詞・例文・発音の自動取得）
- 発音再生（辞書の音声 / 端末TTSの読み上げ）
- XP・レベル、バッジ、連続学習日数（ストリーク）などのゲーミフィケーション
- タグ別のジャンル内訳表示
- マスコットキャラクターによる状況別コメント
- ダークモード対応

## 技術構成

- [Flutter](https://flutter.dev/) / Dart
- [Drift](https://drift.simonbinder.eu/)（SQLiteベースのローカルDB）
- [flutter_riverpod](https://riverpod.dev/)（状態管理）

## セットアップ

```bash
flutter pub get
flutter pub run build_runner build
```

## 実行

```bash
flutter run -d windows
```

Windows版のビルドには Visual Studio（C++ によるデスクトップ開発ワークロード）と `nuget.exe`（`flutter_tts` のビルドに使用）が必要です。
