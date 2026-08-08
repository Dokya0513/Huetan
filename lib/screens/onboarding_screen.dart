import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_utils.dart';
import '../models/learning_direction.dart';
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

List<_OnboardingPage> _buildPages(AppLocalizations l10n) => [
  _OnboardingPage(
    assetPath: 'assets/character/beginner_pointing.png',
    title: l10n.onboardingWelcomeTitle,
    description: l10n.onboardingWelcomeDescription,
  ),
  _OnboardingPage(
    assetPath: 'assets/character/studying_pc.png',
    title: l10n.onboardingHomeTitle,
    description: l10n.onboardingHomeDescription,
  ),
  _OnboardingPage(
    assetPath: 'assets/character/studying_tablet.png',
    title: l10n.onboardingWordsTitle,
    description: l10n.onboardingWordsDescription,
  ),
  _OnboardingPage(
    assetPath: 'assets/character/convinced.png',
    title: l10n.onboardingTestTitle,
    description: l10n.onboardingTestDescription,
  ),
  _OnboardingPage(
    assetPath: 'assets/character/admiration.png',
    title: l10n.onboardingCalendarBadgesTitle,
    description: l10n.onboardingCalendarBadgesDescription,
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
  bool _modeChosen = false;

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

  Future<void> _chooseMode(LearningDirection mode) async {
    await ref.read(learningModeProvider.notifier).setMode(mode);
    if (mounted) setState(() => _modeChosen = true);
  }

  void _next(int pageCount) {
    if (_index == pageCount - 1) {
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
    final l10n = AppLocalizations.of(context)!;

    if (!_modeChosen) {
      return SystemLocaleOverride(
        child: _ModeChoiceView(onChoose: _chooseMode),
      );
    }

    final pages = _buildPages(l10n);
    final isLast = _index == pages.length - 1;

    return SystemLocaleOverride(
      child: Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  l10n.onboardingSkip,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = pages[i];
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
              children: List.generate(pages.length, (i) {
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
                  onPressed: () => _next(pages.length),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLast ? l10n.onboardingStart : l10n.onboardingNext,
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
      ),
    );
  }
}

/// First screen shown on launch, before anything else — lets the user pick
/// which language they're learning. Deliberately always bilingual (not
/// routed through AppLocalizations) rather than following system locale:
/// this is the one screen where "which language can you read" is exactly
/// the question being asked, so picking a single language to ask it in
/// would be circular — a reader of the *other* language couldn't
/// understand the choice in front of them (see also the equivalent
/// section in settings_screen.dart).
class _ModeChoiceView extends StatelessWidget {
  final void Function(LearningDirection mode) onChoose;
  const _ModeChoiceView({required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '何を学びますか？\nWhat are you learning?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onChoose(LearningDirection.enTarget),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '英語を学ぶ\nLearn English',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onChoose(LearningDirection.jaTarget),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '日本語を学ぶ\nLearn Japanese',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'あとで設定画面からいつでも変更できます\n'
                'You can change this anytime in Settings',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
