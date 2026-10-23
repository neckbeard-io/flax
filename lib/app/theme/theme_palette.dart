import 'package:flutter/material.dart';

/// The color theme the whole interface is drawn in. Each has a light and a
/// dark version; [ThemeModeSetting] picks between them.
enum ThemePalette {
  /// The platform's own colors: the wallpaper palette on Android 12+, the
  /// accent color elsewhere. Falls back to [flax] where there is neither.
  device,

  /// Flax's own violet.
  flax,

  /// Follows the cover of the song that is playing.
  album,
  evergreen,
  nord,
  catppuccin,
  dracula,
  gruvbox,
  synthwave;

  static const fallback = ThemePalette.device;

  static ThemePalette fromName(String? name) => ThemePalette.values.firstWhere(
    (p) => p.name == name,
    orElse: () => fallback,
  );

  /// The fixed scheme for this palette, or null for [device] and [album],
  /// whose colors are only known at run time.
  ColorScheme? fixedScheme(Brightness brightness) {
    if (this == flax) {
      return ColorScheme.fromSeed(
        seedColor: flaxSeedColor,
        brightness: brightness,
      );
    }
    final tones = _tones[this];
    if (tones == null) return null;
    return _schemeFromTones(
      brightness == Brightness.dark ? tones.dark : tones.light,
      brightness,
    );
  }
}

const flaxSeedColor = Color(0xFF6750A4);

/// The handful of colors that make a palette recognizable. Everything else in
/// the [ColorScheme] is derived from them.
class _Tones {
  const _Tones({
    required this.background,
    required this.foreground,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color background;
  final Color foreground;
  final Color primary;
  final Color secondary;
  final Color tertiary;
}

typedef _Pair = ({_Tones light, _Tones dark});

const Map<ThemePalette, _Pair> _tones = {
  ThemePalette.evergreen: (
    light: _Tones(
      background: Color(0xFFF2F7F2),
      foreground: Color(0xFF1B2A20),
      primary: Color(0xFF2E7D4F),
      secondary: Color(0xFF4F7A5B),
      tertiary: Color(0xFF8A6D1F),
    ),
    dark: _Tones(
      background: Color(0xFF151D18),
      foreground: Color(0xFFDDE8DF),
      primary: Color(0xFF6FCF97),
      secondary: Color(0xFFA3D9A5),
      tertiary: Color(0xFFE3C27A),
    ),
  ),
  ThemePalette.nord: (
    light: _Tones(
      background: Color(0xFFECEFF4),
      foreground: Color(0xFF2E3440),
      primary: Color(0xFF4C6F9A),
      secondary: Color(0xFF5E81AC),
      tertiary: Color(0xFF8F6A89),
    ),
    dark: _Tones(
      background: Color(0xFF2E3440),
      foreground: Color(0xFFECEFF4),
      primary: Color(0xFF88C0D0),
      secondary: Color(0xFF81A1C1),
      tertiary: Color(0xFFB48EAD),
    ),
  ),
  ThemePalette.catppuccin: (
    light: _Tones(
      background: Color(0xFFEFF1F5),
      foreground: Color(0xFF4C4F69),
      primary: Color(0xFF8839EF),
      secondary: Color(0xFFEA76CB),
      tertiary: Color(0xFF7287FD),
    ),
    dark: _Tones(
      background: Color(0xFF1E1E2E),
      foreground: Color(0xFFCDD6F4),
      primary: Color(0xFFCBA6F7),
      secondary: Color(0xFFF5C2E7),
      tertiary: Color(0xFFB4BEFE),
    ),
  ),
  ThemePalette.dracula: (
    light: _Tones(
      background: Color(0xFFFFFBEB),
      foreground: Color(0xFF1F1F1F),
      primary: Color(0xFF644AC9),
      secondary: Color(0xFFA3144D),
      tertiary: Color(0xFF036A96),
    ),
    dark: _Tones(
      background: Color(0xFF282A36),
      foreground: Color(0xFFF8F8F2),
      primary: Color(0xFFBD93F9),
      secondary: Color(0xFFFF79C6),
      tertiary: Color(0xFF8BE9FD),
    ),
  ),
  ThemePalette.gruvbox: (
    light: _Tones(
      background: Color(0xFFFBF1C7),
      foreground: Color(0xFF3C3836),
      primary: Color(0xFFAF3A03),
      secondary: Color(0xFFB57614),
      tertiary: Color(0xFF427B58),
    ),
    dark: _Tones(
      background: Color(0xFF282828),
      foreground: Color(0xFFEBDBB2),
      primary: Color(0xFFFE8019),
      secondary: Color(0xFFFABD2F),
      tertiary: Color(0xFF8EC07C),
    ),
  ),
  ThemePalette.synthwave: (
    light: _Tones(
      background: Color(0xFFFDF4FF),
      foreground: Color(0xFF2A1036),
      primary: Color(0xFFC2187A),
      secondary: Color(0xFF00838F),
      tertiary: Color(0xFF8A6A00),
    ),
    dark: _Tones(
      background: Color(0xFF1A1029),
      foreground: Color(0xFFF2E9FF),
      primary: Color(0xFFFF3EA5),
      secondary: Color(0xFF2DE2E6),
      tertiary: Color(0xFFFFD319),
    ),
  ),
};

/// Text drawn on [color]: near-black on light accents, white on dark ones.
Color _onColor(Color color) =>
    color.computeLuminance() > 0.35 ? const Color(0xFF15131A) : Colors.white;

/// Seeds a Material scheme from [t.primary] for the roles nobody notices, then
/// pins the ones that carry the palette's character — background, text and
/// accents — to its real colors. The surface containers step from background
/// toward text, as Material's own tones do in both brightnesses.
ColorScheme _schemeFromTones(_Tones t, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  Color mix(double amount) => Color.lerp(t.background, t.foreground, amount)!;
  Color container(Color accent) =>
      Color.lerp(t.background, accent, dark ? 0.32 : 0.2)!;

  return ColorScheme.fromSeed(
    seedColor: t.primary,
    brightness: brightness,
  ).copyWith(
    primary: t.primary,
    onPrimary: _onColor(t.primary),
    primaryContainer: container(t.primary),
    onPrimaryContainer: t.foreground,
    secondary: t.secondary,
    onSecondary: _onColor(t.secondary),
    secondaryContainer: container(t.secondary),
    onSecondaryContainer: t.foreground,
    tertiary: t.tertiary,
    onTertiary: _onColor(t.tertiary),
    tertiaryContainer: container(t.tertiary),
    onTertiaryContainer: t.foreground,
    surface: t.background,
    onSurface: t.foreground,
    onSurfaceVariant: mix(0.72),
    surfaceDim: dark ? Color.lerp(t.background, Colors.black, 0.25) : mix(0.08),
    surfaceBright: dark ? mix(0.12) : t.background,
    surfaceContainerLowest: dark
        ? Color.lerp(t.background, Colors.black, 0.3)
        : Color.lerp(t.background, Colors.white, 0.6),
    surfaceContainerLow: mix(0.03),
    surfaceContainer: mix(0.06),
    surfaceContainerHigh: mix(0.09),
    surfaceContainerHighest: mix(0.13),
    outline: mix(0.45),
    outlineVariant: mix(0.2),
    inverseSurface: t.foreground,
    onInverseSurface: t.background,
    surfaceTint: t.primary,
  );
}
