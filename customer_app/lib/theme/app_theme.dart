import 'package:flutter/material.dart';

/// Nature Fete theme — Chowdeck-inspired: deep green, clean white surfaces,
/// near-black text, amber highlights. Bold, friendly, uncluttered.
class LuxTheme {
  // Brand greens (measured from the reference app's palette)
  static const Color primary = Color(0xFF008050);       // deep chow-green
  static const Color primaryDark = Color(0xFF005030);   // darker shade
  static const Color primaryLight = Color(0xFF00C071);  // bright accent

  // Accents
  static const Color amber = Color(0xFFF5B301);         // ratings / highlights

  // Surfaces
  static const Color bg = Color(0xFFF7F7F8);            // app background
  static const Color surface = Color(0xFFEEEEF0);       // subtle panels
  static const Color surfaceElevated = Color(0xFFFFFFFF); // cards

  // Text
  static const Color textPrimary = Color(0xFF111111);   // near-black
  static const Color textSecondary = Color(0xFF6B7280); // grey

  // Semantics
  static const Color success = Color(0xFF008050);
  static const Color error = Color(0xFFE5484D);

  // Backwards-compatible aliases used across the app.
  static const Color gold = primary;
  static const Color goldLight = primaryLight;
  static const Color deepBlack = bg;

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      fontFamily: 'Inter',
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, color: textPrimary, fontSize: 32),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, color: textPrimary, fontSize: 24),
        titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: textPrimary, fontSize: 18),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textSecondary, fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: primary, fontSize: 14, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
