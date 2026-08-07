import 'package:flutter/material.dart';

/// Font used for English word displays only (flashcard word, "Lv.N", "+XP"
/// popups) — it has no Japanese glyphs, so it must never be applied to
/// Japanese text or it silently falls back to a mismatched system font.
const englishDisplayFontFamily = 'Baloo 2';

/// Default font for all Japanese UI text (screen titles, labels, body).
const _bodyFontFamily = 'Zen Maru Gothic';

/// Brand + semantic colors that differ between light and dark mode. Exposed
/// as a [ThemeExtension] so every screen reads colors from `context.colors`
/// instead of hardcoded constants, keeping dark mode consistent everywhere.
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color successBg;
  final Color danger;
  final Color dangerBg;
  final Color warning;
  final Color warningBg;
  final Color caution;
  final Color cautionBg;

  const AppColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.warning,
    required this.warningBg,
    required this.caution,
    required this.cautionBg,
  });

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    // Colors don't animate between light/dark — MaterialApp wraps its
    // subtree in an implicit AnimatedTheme, so without this override the
    // framework would try to interpolate between two AppColors instances
    // frame-by-frame. Snapping straight to the target on any lerp call
    // (rather than waiting for t >= 0.5) avoids list rows catching a
    // half-transitioned frame and staying visually stuck on the old
    // theme's colors.
    return (other as AppColors?) ?? this;
  }
}

/// Palette A ("pop / vivid"): white background with a sky-blue primary
/// accent — chosen over orange/yellow-green so the accent color never gets
/// confused with the red/orange/yellow/green word-condition labels
/// (苦手/要注意/注意/完璧).
const lightAppColors = AppColors(
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  primary: Color(0xFF0EA5E9),
  primaryDark: Color(0xFF0284C7),
  secondary: Color(0xFFDB2777),
  cardBorder: Color(0xFFBAE6FD),
  textPrimary: Color(0xFF1C1917),
  textSecondary: Color(0xFF78716C),
  success: Color(0xFF16A34A),
  successBg: Color(0xFFDCFCE7),
  danger: Color(0xFFDC2626),
  dangerBg: Color(0xFFFEE2E2),
  warning: Color(0xFFEA580C),
  warningBg: Color(0xFFFFEDD5),
  caution: Color(0xFFCA8A04),
  cautionBg: Color(0xFFFEF9C3),
);

/// Dark mode: slate background, brightened accents/condition colors for
/// contrast against the dark surface.
const darkAppColors = AppColors(
  background: Color(0xFF0F172A),
  surface: Color(0xFF1E293B),
  primary: Color(0xFF38BDF8),
  primaryDark: Color(0xFF0EA5E9),
  secondary: Color(0xFFF472B6),
  cardBorder: Color(0xFF334155),
  textPrimary: Color(0xFFF1F5F9),
  textSecondary: Color(0xFF94A3B8),
  success: Color(0xFF4ADE80),
  successBg: Color(0xFF052E16),
  danger: Color(0xFFF87171),
  dangerBg: Color(0xFF450A0A),
  warning: Color(0xFFFB923C),
  warningBg: Color(0xFF431407),
  caution: Color(0xFFFACC15),
  cautionBg: Color(0xFF422006),
);

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Maps a word's Leitner box (1-5, lower = weaker) to a condition label and
/// color, similar to a baseball game's player-condition indicator: 苦手 →
/// 要注意 → 注意 → 完璧.
class WordCondition {
  final String label;
  final Color color;
  final Color backgroundColor;
  const WordCondition(this.label, this.color, this.backgroundColor);

  factory WordCondition.forBox(int box, AppColors colors) {
    if (box <= 1) {
      return WordCondition('苦手', colors.danger, colors.dangerBg);
    }
    if (box == 2) {
      return WordCondition('要注意', colors.warning, colors.warningBg);
    }
    if (box == 3) {
      return WordCondition('注意', colors.caution, colors.cautionBg);
    }
    return WordCondition('完璧', colors.success, colors.successBg);
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final appColors = brightness == Brightness.light
      ? lightAppColors
      : darkAppColors;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: appColors.primary,
    brightness: brightness,
    primary: appColors.primary,
    secondary: appColors.secondary,
    surface: appColors.surface,
  );

  final textTheme =
      TextTheme(
        displayLarge: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w500,
        ),
      ).apply(
        bodyColor: appColors.textPrimary,
        displayColor: appColors.textPrimary,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: appColors.background,
    fontFamily: _bodyFontFamily,
    textTheme: textTheme,
    extensions: [appColors],
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.background,
      foregroundColor: appColors.textPrimary,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
    cardTheme: CardThemeData(
      color: appColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: appColors.cardBorder, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: appColors.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: appColors.secondary,
        side: BorderSide(color: appColors.secondary, width: 2),
        textStyle: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: appColors.primary,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: appColors.surface,
      selectedColor: appColors.primary,
      labelStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: appColors.textPrimary,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: Colors.white,
      ),
      side: BorderSide(color: appColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: appColors.primary, width: 2),
      ),
    ),
  );
}
