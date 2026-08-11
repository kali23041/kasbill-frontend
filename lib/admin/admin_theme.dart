import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  static const Color bg = Color(0xFF0E1014);
  static const Color panel = Color(0xFF171A21);
  static const Color panelElevated = Color(0xFF1E222B);
  static const Color ink = Color(0xFFF2F0EB);
  static const Color muted = Color(0xFF8B919C);
  static const Color gold = Color(0xFFD4B56A);
  static const Color goldSoft = Color(0xFF2A2418);
  static const Color hairline = Color(0xFF2A2F3A);
  static const Color up = Color(0xFF3DDB8A);
  static const Color down = Color(0xFFFF6B6B);
  static const Color chip = Color(0xFF252A35);
}

class AdminTheme {
  static ThemeData get dark {
    final dmSans = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);
    final fraunces = GoogleFonts.frauncesTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AdminColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.gold,
        onPrimary: AdminColors.bg,
        secondary: AdminColors.ink,
        onSecondary: AdminColors.bg,
        surface: AdminColors.panel,
        onSurface: AdminColors.ink,
      ),
      textTheme: dmSans.copyWith(
        headlineMedium: fraunces.headlineMedium?.copyWith(
          color: AdminColors.ink,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: dmSans.titleLarge?.copyWith(
          color: AdminColors.ink,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: dmSans.bodyMedium?.copyWith(color: AdminColors.ink),
        bodySmall: dmSans.bodySmall?.copyWith(color: AdminColors.muted),
      ),
      dividerColor: AdminColors.hairline,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AdminColors.panelElevated,
        contentTextStyle: TextStyle(color: AdminColors.ink),
      ),
    );
  }

  static TextStyle brand({double size = 28, Color? color}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color ?? AdminColors.ink,
    );
  }

  static TextStyle label({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AdminColors.muted,
    );
  }

  static TextStyle money({double size = 18, Color? color}) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? AdminColors.gold,
      letterSpacing: -0.2,
    );
  }
}
