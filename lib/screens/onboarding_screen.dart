import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'root_shell.dart';

class _OnboardingPage {
  final String assetPath;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.assetPath,
    required this.title,
    required this.description,
  });
}

const _pages = [
  _OnboardingPage(
    assetPath: 'assets/character/beginner_pointing.png',
    title: 'ようこそ、ふえたんへ',
    description: '会話で知らなかった英単語をサッと記録して、暗記カードで復習できるアプリです。',
  ),
  _OnboardingPage(
    assetPath: 'assets/character/studying_pc.png',
    title: 'ホームタブ',
    description: 'レベル・連続学習日数・今日の復習件数がひと目でわかります。ここから単語をサッと追加することもできます。',
  ),
  _OnboardingPage(
    assetPath: 'assets/character/studying_tablet.png',
    title: '単語タブ',
    description: '単語の登録・編集・検索はこちら。英単語だけ入力すれば、意味や品詞、発音は自動で調べてくれます。',
  ),
  _OnboardingPage(
    assetPath: 'assets/character/convinced.png',
    title: 'テストタブ',
    description: '暗記カード・4択クイズ・穴埋めクイズの3種類。苦手な単語ほど出題されやすくなっています。',
  ),
  _OnboardingPage(
    assetPath: 'assets/character/admiration.png',
    title: 'カレンダー・バッジ',
    description: '学習の記録はカレンダーで、達成状況はバッジで確認できます。毎日コツコツ続けてみましょう！',
  ),
];

/// Shown once on first launch: a swipeable walkthrough of the app's tabs.
/// Persists the "seen" flag and navigates to [RootShell] itself once the
/// user finishes or skips it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsServiceProvider).saveOnboardingSeen();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
    }
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'スキップ',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(page.assetPath, width: 160, height: 160),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? colors.primary : colors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLast ? 'はじめる' : '次へ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
