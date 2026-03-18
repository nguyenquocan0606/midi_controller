import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System cho MIDI Controller
/// Dark theme chuyên nghiệp phong cách studio mixing console
class AppTheme {
  AppTheme._();

  // ─── Colors ─────────────────────────────────────────
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252542);
  static const Color surfaceBorder = Color(0xFF2D2D4A);

  static const Color primary = Color(0xFF00D4FF); // Cyan neon
  static const Color primaryDim = Color(0xFF0088AA);
  static const Color accent = Color(0xFFFF6B35); // Cam neon
  static const Color accentDim = Color(0xFFCC5528);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF1744);

  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textDim = Color(0xFF616161);

  // ─── Fader-specific colors ──────────────────────────
  static const Color faderTrack = Color(0xFF2A2A3E);
  static const Color faderThumb = Color(0xFF00D4FF);
  static const Color faderMeterLow = Color(0xFF00E676);
  static const Color faderMeterMid = Color(0xFFFFD600);
  static const Color faderMeterHigh = Color(0xFFFF1744);

  // ─── Knob-specific colors ───────────────────────────
  static const Color knobBackground = Color(0xFF1E1E32);
  static const Color knobArc = Color(0xFF00D4FF);
  static const Color knobPointer = Color(0xFFE0E0E0);

  // ─── Button-specific colors ─────────────────────────
  static const Color buttonOff = Color(0xFF2A2A3E);
  static const Color buttonMute = Color(0xFFFF6B35);
  static const Color buttonSolo = Color(0xFFFFD600);
  static const Color buttonRec = Color(0xFFFF1744);
  static const Color buttonActive = Color(0xFF00D4FF);

  // ─── Pad-specific colors ────────────────────────────
  static const Color padIdle = Color(0xFF1E1E32);
  static const Color padActive = Color(0xFF00D4FF);
  static const Color padHit = Color(0xFFFF6B35);

  // ─── Spacing ────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ─── Border Radius ──────────────────────────────────
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 16.0;

  // ─── ThemeData ──────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textDim,
            letterSpacing: 0.5,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textDim),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
