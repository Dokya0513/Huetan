import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'badges_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'weak_words_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    RepaintBoundary(child: DashboardScreen()),
    RepaintBoundary(child: HomeScreen()),
    RepaintBoundary(child: WeakWordsScreen()),
    RepaintBoundary(child: CalendarScreen()),
    RepaintBoundary(child: BadgesScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: colors.primary),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: colors.primary),
            label: '単語',
          ),
          NavigationDestination(
            icon: const Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber, color: colors.primary),
            label: '苦手',
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: colors.primary),
            label: 'カレンダー',
          ),
          NavigationDestination(
            icon: const Icon(Icons.military_tech_outlined),
            selectedIcon: Icon(Icons.military_tech, color: colors.primary),
            label: 'バッジ',
          ),
        ],
      ),
    );
  }
}
