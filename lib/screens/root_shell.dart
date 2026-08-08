import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'badges_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'flashcard_setup_screen.dart';
import 'home_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      const RepaintBoundary(child: DashboardScreen()),
      const RepaintBoundary(child: HomeScreen()),
      RepaintBoundary(
        child: FlashcardSetupScreen(
          allowedModes: const [QuizMode.choiceQuiz, QuizMode.fillBlank],
          title: l10n.navTest,
        ),
      ),
      const RepaintBoundary(child: CalendarScreen()),
      const RepaintBoundary(child: BadgesScreen()),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: colors.primary),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: colors.primary),
            label: l10n.navWords,
          ),
          NavigationDestination(
            icon: const Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz, color: colors.primary),
            label: l10n.navTest,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: colors.primary),
            label: l10n.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.military_tech_outlined),
            selectedIcon: Icon(Icons.military_tech, color: colors.primary),
            label: l10n.navBadges,
          ),
        ],
      ),
    );
  }
}
