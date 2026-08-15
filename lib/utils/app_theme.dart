import 'package:flutter/material.dart';

class AppTheme {
  static const String defaultTheme = 'blue';
  static const String defaultBrightness = 'light';

  // Light Theme Data
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF4F46E5); // Modern Indigo
    const secondaryColor = Color(0xFF06B6D4); // Cyan Accent
    const backgroundColor = Color(0xFFF8FAFC); // Very light slate
    const cardColor = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);

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
        scrolledUnderElevation: 0.5,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Dark Theme Data
  static ThemeData get darkTheme {
    const primaryColor = Color(0xFF6366F1); // Indigo Accent
    const secondaryColor = Color(0xFF22D3EE); // Bright Cyan
    const backgroundColor = Color(0xFF0F172A); // Slate 900
    const cardColor = Color(0xFF1E293B); // Slate 800
    const textPrimary = Color(0xFFF8FAFC);
    const textSecondary = Color(0xFF94A3B8);

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
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
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
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Fallback helper for legacy code calling getTheme()
  static ThemeData getTheme(String themeName, {String brightness = 'light'}) {
    return brightness == 'dark' ? darkTheme : lightTheme;
  }

  // Legacy helper methods for existing screens
  static Color getPrimaryColor(String themeName, {String brightness = 'light'}) {
    final bool isDark = brightness == 'dark';
    return isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
  }

  static Color getAccentColor(String themeName, {String brightness = 'light'}) {
    final bool isDark = brightness == 'dark';
    return isDark ? const Color(0xFF22D3EE) : const Color(0xFF06B6D4);
  }

  static Color getTertiaryColor(String themeName, {String brightness = 'light'}) {
    final bool isDark = brightness == 'dark';
    return isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  }

  static List<Color> getGradientColors(String themeName, {String brightness = 'light'}) {
    final bool isDark = brightness == 'dark';
    return isDark
        ? [const Color(0xFF1E293B), const Color(0xFF6366F1)]
        : [const Color(0xFF4F46E5), const Color(0xFF06B6D4)];
  }
}
