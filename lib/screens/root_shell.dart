import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'badges_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'flashcard_setup_screen.dart';
import 'home_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Runs once per launch, after the first frame so a dialog has a valid
    // context to show in. There's deliberately no "back up when the app
    // closes" counterpart — on Windows especially, the process can exit
    // before an in-flight async upload finishes, so that trigger isn't
    // reliable. Instead, uploads happen at points guaranteed to run to
    // completion while the app is fully active: after adding a word (see
    // word_form_screen.dart/dashboard_screen.dart) and after finishing a
    // review session (see session_result_screen.dart) — both call
    // autoBackupIfSignedIn from services/auto_backup.dart.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCloudFreshness());
  }

  Future<void> _checkCloudFreshness() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      final cloudBackup = ref.read(cloudBackupServiceProvider);
      final settings = ref.read(settingsServiceProvider);
      final cloudTime = await cloudBackup.lastUploadedAt();
      if (cloudTime == null) return;
      final lastSync = await settings.loadLastCloudSyncAt();
      if (lastSync != null && !cloudTime.isAfter(lastSync)) return;

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final restore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.cloudNewDataDialogTitle),
          content: Text(l10n.cloudNewDataDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cloudNewDataDialogSkip),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.cloudNewDataDialogRestore),
            ),
          ],
        ),
      );

      // Either way, this cloud version has now been "dealt with" — a
      // decline shouldn't re-prompt again next launch for the same
      // version, only for a genuinely newer one.
      await settings.saveLastCloudSyncAt(cloudTime);

      if (restore == true) {
        final data = await cloudBackup.download();
        if (data != null && mounted) {
          final db = ref.read(databaseProvider);
          await ref.read(backupServiceProvider).importAndReplace(db, data);
        }
      }
    } catch (_) {
      // Best-effort — a failed freshness check just means the user
      // doesn't get prompted this launch, nothing is lost.
    }
  }

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
