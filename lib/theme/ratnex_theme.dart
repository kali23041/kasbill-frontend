import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RatnexColors {
  static const Color surface = Color(0xFFF7F6F4);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF12141A);
  static const Color muted = Color(0xFF5C6370);
  static const Color gold = Color(0xFF9A7B2F);
  static const Color goldSoft = Color(0xFFEDE6D4);
  static const Color rateBoard = Color(0xFF12141A);
  static const Color rateAccent = Color(0xFFD4C4A0);
  static const Color hairline = Color(0xFFE2E0DB);
  static const Color up = Color(0xFF1B7A4E);
  static const Color down = Color(0xFFB42318);
}

class RatnexTheme {
  static ThemeData get light {
    final dmSans = GoogleFonts.dmSansTextTheme();
    final fraunces = GoogleFonts.frauncesTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: RatnexColors.surface,
      colorScheme: const ColorScheme.light(
        primary: RatnexColors.gold,
        onPrimary: Colors.white,
        secondary: RatnexColors.ink,
        onSecondary: Colors.white,
        surface: RatnexColors.panel,
        onSurface: RatnexColors.ink,
      ),
      textTheme: dmSans.copyWith(
        displayLarge: fraunces.displayLarge?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: fraunces.displayMedium?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: fraunces.headlineLarge?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: fraunces.headlineMedium?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: fraunces.headlineSmall?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: dmSans.titleLarge?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: dmSans.titleMedium?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: dmSans.bodyLarge?.copyWith(color: RatnexColors.ink),
        bodyMedium: dmSans.bodyMedium?.copyWith(color: RatnexColors.ink),
        bodySmall: dmSans.bodySmall?.copyWith(color: RatnexColors.muted),
        labelLarge: dmSans.labelLarge?.copyWith(
          color: RatnexColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RatnexColors.surface,
        foregroundColor: RatnexColors.ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: RatnexColors.ink,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RatnexColors.ink,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextStyle brand({double size = 32}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: RatnexColors.ink,
      height: 1.1,
      letterSpacing: -0.6,
    );
  }

  static TextStyle money({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = RatnexColors.ink,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle label({
    double size = 12,
    Color color = RatnexColors.muted,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.2,
    );
  }
}
