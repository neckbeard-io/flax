import 'package:flutter/material.dart';

class FlaxTheme {
  static const _seedColor = Color(0xFF6750A4);

  static ThemeData light({ColorScheme? dynamicScheme}) {
    final colorScheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        );

    return ThemeData(
      useMaterial3: true,
      // One back arrow everywhere. Automatic AppBar back buttons are
      // platform-adaptive and drew a bare chevron on macOS, so the artist page
      // disagreed with the album page's explicit arrow. Setting it here fixes
      // every screen at once, including ones not written yet.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      colorScheme: colorScheme,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData dark({ColorScheme? dynamicScheme, bool amoled = false}) {
    final colorScheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        );

    final effectiveScheme = amoled
        ? colorScheme.copyWith(surface: Colors.black, onSurface: Colors.white)
        : colorScheme;

    return ThemeData(
      useMaterial3: true,
      // One back arrow everywhere. Automatic AppBar back buttons are
      // platform-adaptive and drew a bare chevron on macOS, so the artist page
      // disagreed with the album page's explicit arrow. Setting it here fixes
      // every screen at once, including ones not written yet.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      colorScheme: effectiveScheme,
      scaffoldBackgroundColor: amoled ? Colors.black : null,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: effectiveScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 2,
        backgroundColor: effectiveScheme.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: effectiveScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: effectiveScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
