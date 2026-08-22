import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ratnex palette.
///
/// The members are getters rather than constants so every existing call site
/// (`RatnexColors.surface`, `RatnexColors.ink`, …) follows the active
/// brightness without needing a `BuildContext`. [RatnexPalette.apply] is
/// called by the root widget whenever the theme mode resolves.
class RatnexColors {
  static bool _dark = false;

  static bool get isDark => _dark;

  static Color get surface => _dark ? const Color(0xFF0E0F13) : const Color(0xFFF7F6F4);
  static Color get panel => _dark ? const Color(0xFF171922) : const Color(0xFFFFFFFF);
  static Color get ink => _dark ? const Color(0xFFF2F0EC) : const Color(0xFF12141A);
  static Color get muted => _dark ? const Color(0xFF9AA0AD) : const Color(0xFF5C6370);
  static Color get gold => _dark ? const Color(0xFFD7B369) : const Color(0xFF9A7B2F);
  static Color get goldSoft => _dark ? const Color(0xFF2A2519) : const Color(0xFFEDE6D4);
  static Color get rateBoard => _dark ? const Color(0xFF1C1F2A) : const Color(0xFF12141A);
  static Color get rateAccent => const Color(0xFFD4C4A0);
  static Color get hairline => _dark ? const Color(0xFF272B36) : const Color(0xFFE2E0DB);
  static Color get up => _dark ? const Color(0xFF34C77B) : const Color(0xFF1B7A4E);
  static Color get down => _dark ? const Color(0xFFFF6B5E) : const Color(0xFFB42318);

  /// Always-dark ink, for text drawn on top of the gold/dark rate board.
  static const Color onRateBoard = Color(0xFFF2F0EC);

  /// Semantic accents used by the newer modules (ledger, schemes, repairs).
  static Color get info => _dark ? const Color(0xFF6FA8FF) : const Color(0xFF1F5FBF);
  static Color get warn => _dark ? const Color(0xFFE0A94A) : const Color(0xFF9A6A11);
  static Color get violet => _dark ? const Color(0xFFB08CFF) : const Color(0xFF6B3FBF);
}

class RatnexPalette {
  RatnexPalette._();

  /// Switches the palette. Returns true when the brightness actually changed
  /// so the caller can trigger a rebuild.
  static bool apply(Brightness brightness) {
    final wantDark = brightness == Brightness.dark;
    if (RatnexColors._dark == wantDark) return false;
    RatnexColors._dark = wantDark;
    return true;
  }
}

class RatnexTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark ? const Color(0xFF0E0F13) : const Color(0xFFF7F6F4);
    final panel = isDark ? const Color(0xFF171922) : const Color(0xFFFFFFFF);
    final ink = isDark ? const Color(0xFFF2F0EC) : const Color(0xFF12141A);
    final muted = isDark ? const Color(0xFF9AA0AD) : const Color(0xFF5C6370);
    final gold = isDark ? const Color(0xFFD7B369) : const Color(0xFF9A7B2F);

    final dmSans = GoogleFonts.dmSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    final fraunces = GoogleFonts.frauncesTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: gold,
        onPrimary: isDark ? const Color(0xFF12141A) : Colors.white,
        secondary: ink,
        onSecondary: isDark ? const Color(0xFF12141A) : Colors.white,
        error: isDark ? const Color(0xFFFF6B5E) : const Color(0xFFB42318),
        onError: Colors.white,
        surface: panel,
        onSurface: ink,
      ),
      textTheme: dmSans.copyWith(
        displayLarge: fraunces.displayLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: fraunces.displayMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: fraunces.headlineLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: fraunces.headlineMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: fraunces.headlineSmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: dmSans.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: dmSans.titleMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: dmSans.bodyLarge?.copyWith(color: ink),
        bodyMedium: dmSans.bodyMedium?.copyWith(color: ink),
        bodySmall: dmSans.bodySmall?.copyWith(color: muted),
        labelLarge: dmSans.labelLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: panel),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: panel),
      popupMenuTheme: PopupMenuThemeData(color: panel),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF272B36) : const Color(0xFFE2E0DB),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF272B36) : ink,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white),
        actionTextColor: const Color(0xFFD4C4A0),
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
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? RatnexColors.ink,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle label({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? RatnexColors.muted,
      height: 1.2,
    );
  }
}
