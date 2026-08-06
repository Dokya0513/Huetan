import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'root_shell.dart';

/// Shown immediately on launch (white background + title) while the
/// database opens and the schema migration runs, so the window appears
/// right away instead of a blank frame during debug/first-run startup.
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
    final minimumSplash = Future.delayed(const Duration(milliseconds: 1200));
    // Forces the sqlite connection open and the schema migration to run,
    // so RootShell's first frame doesn't stall on it.
    final dbReady = ref.read(wordRepositoryProvider).getAllWords();
    await Future.wait([minimumSplash, dbReady]);
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: const Center(child: AppLogoHorizontal()),
    );
  }
}
