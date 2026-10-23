import 'package:flutter/material.dart';
import 'package:flax/app/theme/theme_palette.dart';

class FlaxTheme {
  static ThemeData light({ColorScheme? dynamicScheme}) =>
      _build(dynamicScheme ?? ThemePalette.flax.fixedScheme(Brightness.light)!);

  static ThemeData dark({ColorScheme? dynamicScheme, bool amoled = false}) {
    final colorScheme =
        dynamicScheme ?? ThemePalette.flax.fixedScheme(Brightness.dark)!;
    return _build(amoled ? amoledScheme(colorScheme) : colorScheme);
  }

  /// [scheme] with pure black where the background shows, so an OLED panel
  /// switches those pixels off. Raised surfaces keep their color, or cards and
  /// bars would vanish into the background.
  static ColorScheme amoledScheme(ColorScheme scheme) => scheme.copyWith(
    surface: Colors.black,
    onSurface: Colors.white,
    surfaceDim: Colors.black,
    surfaceContainerLowest: Colors.black,
  );

  static ThemeData _build(ColorScheme colorScheme) {
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
      scaffoldBackgroundColor: colorScheme.surface,
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
}
