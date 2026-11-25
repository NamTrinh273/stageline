import 'package:material_ui/material_ui.dart';

/// Strict OLED concert palette and lightweight theme (system fonts only).
abstract final class StageLineColors {
  /// True OLED black — turns off background pixels to save battery & prevent glare.
  static const Color background = Color(0xFF000000);

  /// Subtle elevated surface for cards, bottom sheets, and HUD containers.
  static const Color surface = Color(0xFF0E0E12);

  /// Active lyric line focus surface in Concert Mode.
  static const Color activeSurface = Color(0xFF121216);

  /// Subtle hairline border for dark cards and pills.
  static const Color border = Color(0xFF22222A);

  /// Primary anti-glare off-white lyric text (never harsh #FFFFFF).
  static const Color primaryText = Color(0xFFE2E2E6);

  /// Dimmed surrounding lyric lines so the eye locks onto the active line.
  static const Color secondaryText = Color(0xFF8E8E93);

  /// Optional short translation line color.
  static const Color translationText = Color(0xFF6E6E73);

  /// Warm gold highlight for [Chorus] / [Sing-along] sections.
  static const Color singAlongGold = Color(0xFFFFD166);

  /// Subtle gold tint for sing-along active line surface.
  static const Color singAlongSurface = Color(0xFF1B170C);

  /// Destructive / error accent.
  static const Color danger = Color(0xFFFF6B6B);
}

abstract final class StageLineTheme {
  static ThemeData buildDarkTheme() {
    const colorScheme = ColorScheme.dark(
      surface: StageLineColors.background,
      surfaceContainerHighest: StageLineColors.surface,
      primary: StageLineColors.singAlongGold,
      onPrimary: StageLineColors.background,
      secondary: StageLineColors.primaryText,
      onSecondary: StageLineColors.background,
      onSurface: StageLineColors.primaryText,
      error: StageLineColors.danger,
      outline: StageLineColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StageLineColors.background,
      canvasColor: StageLineColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: StageLineColors.background,
        foregroundColor: StageLineColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: StageLineColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: StageLineColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: StageLineColors.border,
        thickness: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: StageLineColors.singAlongGold,
        foregroundColor: StageLineColors.background,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StageLineColors.surface,
        hintStyle: const TextStyle(color: StageLineColors.translationText),
        labelStyle: const TextStyle(color: StageLineColors.secondaryText),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageLineColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageLineColors.singAlongGold),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: StageLineColors.activeSurface,
        contentTextStyle: TextStyle(color: StageLineColors.primaryText),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
