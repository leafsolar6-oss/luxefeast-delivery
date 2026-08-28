import 'package:flutter/material.dart';

/// Nature Fete brand — fresh greens on clean white.
class LuxTheme {
  // Brand greens
  static const Color primary = Color(0xFF1E7B47);      // deep fresh green
  static const Color primaryLight = Color(0xFF57BB7F); // tender leaf green

  // Surfaces (light, airy)
  static const Color bg = Color(0xFFF6FAF7);            // app background — near-white
  static const Color surface = Color(0xFFEDF5EE);       // soft green-tinted panels
  static const Color surfaceElevated = Color(0xFFFFFFFF); // cards

  // Text
  static const Color textPrimary = Color(0xFF14281C);   // deep green-black
  static const Color textSecondary = Color(0xFF5C6E60); // muted sage

  // Semantics
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFDC2626);

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
        displayLarge: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700, color: textPrimary, fontSize: 32),
        headlineMedium: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 24),
        titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 18),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textSecondary, fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: primary, fontSize: 14, letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: primary.withOpacity(0.15), width: 1)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          textStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
