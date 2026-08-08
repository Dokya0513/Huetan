import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'onboarding_screen.dart';
import 'root_shell.dart';

/// Shown immediately on launch while the database opens and the schema
/// migration runs, so RootShell's first frame doesn't stall on it.
///
/// On Windows the app window appears with no other loading indicator, so
/// this shows the logo for a minimum stretch of time to avoid a blank
/// flash. On Android the OS's own splash screen (see
/// android/app/src/main/res/values-v31/styles.xml) already covers this
/// same window, so this widget stays invisible and skips the artificial
/// minimum delay — showing our logo on top of/after the OS one would just
/// be a redundant second splash.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _warmUp();
  }

  Future<void> _warmUp() async {
    // Forces the sqlite connection open and the schema migration to run,
    // so RootShell's first frame doesn't stall on it. Runs before the
    // learning-mode setting is necessarily loaded, so this deliberately
    // doesn't go through a mode-filtered query.
    final dbReady = ref
        .read(databaseProvider)
        .customSelect('SELECT 1')
        .get();
    final onboardingSeenFuture = ref
        .read(settingsServiceProvider)
        .loadOnboardingSeen();
    bool onboardingSeen;
    if (Platform.isAndroid) {
      onboardingSeen = await onboardingSeenFuture;
      await dbReady;
    } else {
      final minimumSplash = Future.delayed(const Duration(milliseconds: 1200));
      final results = await Future.wait([
        minimumSplash,
        dbReady,
        onboardingSeenFuture,
      ]);
      onboardingSeen = results[2] as bool;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            onboardingSeen ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return Scaffold(backgroundColor: context.colors.background);
    }
    return Scaffold(
      backgroundColor: context.colors.background,
      body: const Center(child: AppLogoHorizontal()),
    );
  }
}
