import 'package:flutter/material.dart';

class AppTheme {
  static const String defaultTheme = 'blue';
  static const String defaultBrightness = 'light';

  // Light Theme Data (High Contrast & Modern Material 3)
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF3B82F6); // Vibrant Blue
    const secondaryColor = Color(0xFF0D9488); // Teal Accent
    const backgroundColor = Color(0xFFF1F5F9); // Light Slate Gray
    const cardColor = Colors.white;
    const textPrimary = Color(0xFF0F172A); // Very Dark Slate
    const textSecondary = Color(0xFF475569); // Slate 600

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: textPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 28),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  // Dark Theme Data
  static ThemeData get darkTheme {
    const primaryColor = Color(0xFF60A5FA); // Bright Blue
    const secondaryColor = Color(0xFF2DD4BF); // Teal
    const backgroundColor = Color(0xFF0F172A); // Slate 900
    const cardColor = Color(0xFF1E293B); // Slate 800
    const textPrimary = Color(0xFFF8FAFC);
    const textSecondary = Color(0xFFCBD5E1);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: textPrimary,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 28),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  static ThemeData getTheme(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkTheme : lightTheme;
  }

  static Color getPrimaryColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  }

  static Color getAccentColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  }

  static Color getTertiaryColor(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  }

  static List<Color> getGradientColors(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark'
        ? [const Color(0xFF1E293B), const Color(0xFF3B82F6)]
        : [const Color(0xFF3B82F6), const Color(0xFF0D9488)];
  }
}
