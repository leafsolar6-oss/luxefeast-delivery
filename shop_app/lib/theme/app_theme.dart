import 'package:flutter/material.dart';

class LuxTheme {
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8C874);
  static const Color deepBlack = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceElevated = Color(0xFF181825);
  static const Color textPrimary = Color(0xFFF5F0E6);
  static const Color textSecondary = Color(0xFF9A948A);
  static const Color success = Color(0xFF4AE8A0);
  static const Color error = Color(0xFFE84A4A);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: gold,
      scaffoldBackgroundColor: deepBlack,
      colorScheme: ColorScheme.dark(
        primary: gold,
        secondary: goldLight,
        surface: surface,
        background: deepBlack,
        error: error,
        onPrimary: deepBlack,
        onSecondary: deepBlack,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700, color: textPrimary, fontSize: 32),
        headlineMedium: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 24),
        titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 18),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, color: textSecondary, fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: gold, fontSize: 14, letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: gold),
        titleTextStyle: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: gold.withOpacity(0.1), width: 1)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: deepBlack,
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          textStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
