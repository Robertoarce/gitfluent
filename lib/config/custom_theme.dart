import 'package:flutter/material.dart';

class CustomColorScheme {
  // Light colors from the provided palette
  static const Color lightBlue1 = Color(0xFF4ED7F1);
  static const Color lightBlue2 = Color(0xFF6FE6FC);
  static const Color lightBlue3 = Color(0xFFA8F1FF);
  static const Color lightYellow = Color(0xFFFFFA8D);

  // Dark colors from the provided palette
  static const Color darkGreen = Color(0xFF303A2B);
  static const Color pink1 = Color(0xFFFF99C9);
  static const Color pink2 = Color(0xFFFF99C9); // Same as pink1
  static const Color darkPink = Color(0xFF893168);

  // Create a custom light color scheme
  static const ColorScheme light = ColorScheme.light(
    primary: darkPink, // #893168 - for primary elements
    onPrimary: Colors.white,
    secondary: lightBlue1, // #4ED7F1 - for secondary elements
    onSecondary: darkGreen, // #303A2B
    tertiary: lightYellow, // #FFFA8D - for accents
    onTertiary: darkGreen,
    surface: Colors.white,
    onSurface: darkGreen,
    surfaceVariant: lightBlue3, // #A8F1FF - for message bubbles
    onSurfaceVariant: darkGreen,
    background: lightBlue2, // #6FE6FC - for background gradient
    onBackground: darkGreen,
    error: Colors.red,
    onError: Colors.white,
    outline: lightBlue1,
    shadow: Colors.black26,
    inversePrimary: lightBlue1,
    inverseSurface: darkGreen,
    onInverseSurface: Colors.white,
  );

  // Create a custom dark color scheme
  static const ColorScheme dark = ColorScheme.dark(
    primary: lightBlue1, // #4ED7F1
    onPrimary: darkGreen,
    secondary: pink1, // #FF99C9
    onSecondary: darkGreen,
    tertiary: lightYellow, // #FFFA8D
    onTertiary: darkGreen,
    surface: darkGreen,
    onSurface: Colors.white,
    surfaceVariant: const Color(0x33893168),
    onSurfaceVariant: Colors.white,
    background: darkGreen,
    onBackground: Colors.white,
    error: Colors.red,
    onError: Colors.white,
    outline: lightBlue1,
    shadow: Colors.black54,
    inversePrimary: lightBlue1,
    inverseSurface: Colors.white,
    onInverseSurface: darkGreen,
  );
}

class CustomTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: CustomColorScheme.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: CustomColorScheme.lightBlue2,
        foregroundColor: CustomColorScheme.darkGreen,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CustomColorScheme.darkPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide:
              const BorderSide(color: CustomColorScheme.darkPink, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: CustomColorScheme.lightBlue3,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: CustomColorScheme.dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: CustomColorScheme.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CustomColorScheme.lightBlue1,
          foregroundColor: CustomColorScheme.darkGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CustomColorScheme.darkGreen.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide:
              const BorderSide(color: CustomColorScheme.lightBlue1, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: const Color(0x33893168),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
