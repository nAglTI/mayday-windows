import 'package:flutter/material.dart';

abstract final class MaydayColors {
  static const background = Color(0xFF12120F);
  static const surface = Color(0xFF1A1A15);
  static const sunken = Color(0xFF0C0C0A);
  static const border = Color(0xFF2B2A24);
  static const hairline = Color(0xFF24241E);
  static const text = Color(0xFFECE9E0);
  static const muted = Color(0xFF8B867A);
  static const subtle = Color(0xFF6A6557);
  static const accent = Color(0xFF7CBD96);
  static const accentSoft = Color(0xFF1E2A23);
  static const danger = Color(0xFFD07A5F);
  static const warn = Color(0xFFD4A85A);
  static const chip = Color(0xFF222018);
}

abstract final class MaydayRadii {
  static const small = 6.0;
  static const medium = 10.0;
  static const large = 14.0;
  static const extraLarge = 20.0;
}

abstract final class MaydayTheme {
  static ThemeData dark() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: MaydayColors.accent,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      primary: MaydayColors.accent,
      onPrimary: MaydayColors.sunken,
      primaryContainer: MaydayColors.accentSoft,
      onPrimaryContainer: MaydayColors.text,
      secondary: MaydayColors.muted,
      onSecondary: MaydayColors.sunken,
      secondaryContainer: MaydayColors.chip,
      onSecondaryContainer: MaydayColors.text,
      tertiary: MaydayColors.warn,
      onTertiary: MaydayColors.sunken,
      surface: MaydayColors.surface,
      onSurface: MaydayColors.text,
      error: MaydayColors.danger,
      onError: MaydayColors.sunken,
      outline: MaydayColors.border,
      outlineVariant: MaydayColors.hairline,
    );

    final textTheme = _textTheme.apply(
      bodyColor: MaydayColors.text,
      displayColor: MaydayColors.text,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MaydayColors.background,
      useMaterial3: true,
      fontFamily: 'Inter',
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: MaydayColors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: MaydayColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.large),
          side: const BorderSide(color: MaydayColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MaydayColors.sunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: MaydayColors.subtle),
        helperStyle: textTheme.bodySmall?.copyWith(color: MaydayColors.subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.large),
          borderSide: const BorderSide(color: MaydayColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.large),
          borderSide: const BorderSide(color: MaydayColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.large),
          borderSide: const BorderSide(color: MaydayColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.large),
          borderSide: const BorderSide(color: MaydayColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          backgroundColor: MaydayColors.accent,
          foregroundColor: MaydayColors.sunken,
          textStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          disabledBackgroundColor: MaydayColors.chip,
          disabledForegroundColor: MaydayColors.subtle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: const StadiumBorder(),
          foregroundColor: MaydayColors.text,
          side: const BorderSide(color: MaydayColors.border),
          textStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          disabledForegroundColor: MaydayColors.subtle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: MaydayColors.text,
          disabledForegroundColor: MaydayColors.subtle,
        ),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'InstrumentSerif',
      fontSize: 48,
      height: 52 / 48,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    displayMedium: TextStyle(
      fontFamily: 'InstrumentSerif',
      fontSize: 40,
      height: 44 / 40,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'InstrumentSerif',
      fontSize: 22,
      height: 27 / 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'InstrumentSerif',
      fontSize: 20,
      height: 25 / 20,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 19 / 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      height: 22 / 15,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      height: 17 / 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelMedium: TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
  );
}
