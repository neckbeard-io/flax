import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/domain/enums.dart';

/// Represents dynamic light and dark [ColorScheme] pairs.
class DynamicColorSchemes {
  const DynamicColorSchemes({this.light, this.dark});

  final ColorScheme? light;
  final ColorScheme? dark;

  /// Generate dynamic light and dark color schemes from a pure-Dart seed color
  /// using Material 3 tonal palette generation (via [ColorScheme.fromSeed]).
  factory DynamicColorSchemes.fromSeed(Color seedColor) {
    return DynamicColorSchemes(
      light: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      dark: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}

final themeModeProvider = StateProvider<ThemeModeSetting>(
  (ref) => ThemeModeSetting.system,
);

final amoledProvider = StateProvider<bool>((ref) => false);

/// Holds dynamic color schemes extracted from platform wallpaper/Material You
/// or a fallback pure-Dart seed color.
final dynamicColorSchemesProvider = StateProvider<DynamicColorSchemes?>(
  (ref) => null,
);

ThemeMode resolveThemeMode(ThemeModeSetting setting) {
  return switch (setting) {
    ThemeModeSetting.system => ThemeMode.system,
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
  };
}
