import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'providers/providers.dart';
import 'repositories/activity_repository.dart';
import 'screens/splash_screen.dart';
import 'services/windows_protocol_service.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

/// Custom URL scheme used to hand an OAuth redirect (opened in the system
/// browser for sign-in) back to this app — see windows_protocol_service.dart
/// and windows/runner/main.cpp for how Windows specifically handles this.
const supabaseAuthCallbackScheme = 'fuetan';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerWindowsProtocol(supabaseAuthCallbackScheme);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(activityRepositoryProvider).recordActivity(ActivityType.appOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(effectiveLocaleProvider),
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
