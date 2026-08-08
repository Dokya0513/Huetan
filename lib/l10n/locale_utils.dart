import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Best-effort match of the device's preferred locale against the locales
/// this app ships translations for, falling back to English.
Locale systemPreferredLocale() {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return const Locale('en');
}

/// Wraps [child] so its subtree always resolves l10n against the device's
/// locale, ignoring the app-wide learning-mode-driven locale set on
/// [MaterialApp]. Used by the Settings screen and the onboarding flow, which
/// must stay readable regardless of which learning mode ends up chosen.
class SystemLocaleOverride extends StatelessWidget {
  final Widget child;
  const SystemLocaleOverride({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: systemPreferredLocale(),
      child: child,
    );
  }
}
