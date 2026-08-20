import 'package:flutter/material.dart';

/// Système de Thème Monochrome Élégant & Épuré
/// Appliqué de manière 100% identique sur tous les espaces de l'application.
class AppTheme {
  static const String defaultTheme = 'monochrome';
  static const String defaultBrightness = 'light';

  // ── Palette Monochrome Mode Clair ─────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8FAFC);          // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);     // Blanc Pur
  static const Color lightBorder = Color(0xFFE2E8F0);      // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightAccent = Color(0xFF1E293B);      // Slate 800 (Accent sombre épuré)

  // ── Palette Monochrome Mode Sombre ────────────────────────────────────────
  static const Color darkBg = Color(0xFF090D16);           // Dark Slate 950
  static const Color darkSurface = Color(0xFF161E2E);      // Dark Slate 900
  static const Color darkBorder = Color(0xFF26334D);       // Dark Slate 800
  static const Color darkTextPrimary = Color(0xFFF8FAFC);  // Blanc Cassé
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkAccent = Color(0xFFF1F5F9);       // Blanc Accent pour éléments d'action sombres

  // ── Light Theme Data ──────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightAccent,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightSurface,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightTextSecondary,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightBorder,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: lightTextPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightAccent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: lightTextPrimary, size: 22),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w900, fontSize: 28),
        headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: lightTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: lightTextSecondary, fontSize: 14),
        labelLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  // ── Dark Theme Data ───────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkAccent,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        secondary: darkTextSecondary,
        surface: darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: darkTextPrimary,
        outline: darkBorder,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: darkTextPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkAccent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w900, fontSize: 28),
        headlineMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: darkTextSecondary, fontSize: 14),
        labelLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  static ThemeData getTheme(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkTheme : lightTheme;
  }

  static Color getPrimaryColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkAccent : lightAccent;
  }

  static Color getAccentColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkAccent : lightAccent;
  }

  static Color getTertiaryColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkTextSecondary : lightTextSecondary;
  }

  static List<Color> getGradientColors(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark'
        ? [darkSurface, darkBg]
        : [lightSurface, lightBg];
  }
}
