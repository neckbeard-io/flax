import 'package:cached_network_image/cached_network_image.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/app/theme/theme_palette.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';

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

  ColorScheme? of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

const kThemeModePrefKey = 'flax_theme_mode';
const kThemePalettePrefKey = 'flax_theme_palette';
const kAmoledPrefKey = 'flax_amoled_black';

/// A setting saved to preferences. Bootstrap hands the saved value in as
/// [initialValue] so the first frame is drawn in the right colors; without
/// one, the default shows until preferences answer.
abstract class _SavedSetting<T> extends StateNotifier<T> {
  _SavedSetting(T? initialValue, T fallback) : super(initialValue ?? fallback) {
    if (initialValue == null) _load();
  }

  T? read(SharedPreferences prefs);
  Future<void> write(SharedPreferences prefs, T value);

  Future<void> _load() async {
    try {
      final saved = read(await SharedPreferences.getInstance());
      if (saved != null && mounted) state = saved;
    } catch (_) {}
  }

  Future<void> set(T value) async {
    state = value;
    try {
      await write(await SharedPreferences.getInstance(), value);
    } catch (_) {}
  }
}

class ThemeModeNotifier extends _SavedSetting<ThemeModeSetting> {
  ThemeModeNotifier({ThemeModeSetting? initialValue})
    : super(initialValue, ThemeModeSetting.system);

  static ThemeModeSetting? loadFromPrefs(SharedPreferences prefs) {
    final name = prefs.getString(kThemeModePrefKey);
    for (final mode in ThemeModeSetting.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }

  @override
  ThemeModeSetting? read(SharedPreferences prefs) => loadFromPrefs(prefs);

  @override
  Future<void> write(SharedPreferences prefs, ThemeModeSetting value) =>
      prefs.setString(kThemeModePrefKey, value.name);
}

class ThemePaletteNotifier extends _SavedSetting<ThemePalette> {
  ThemePaletteNotifier({ThemePalette? initialValue})
    : super(initialValue, ThemePalette.fallback);

  static ThemePalette? loadFromPrefs(SharedPreferences prefs) {
    final name = prefs.getString(kThemePalettePrefKey);
    return name == null ? null : ThemePalette.fromName(name);
  }

  @override
  ThemePalette? read(SharedPreferences prefs) => loadFromPrefs(prefs);

  @override
  Future<void> write(SharedPreferences prefs, ThemePalette value) =>
      prefs.setString(kThemePalettePrefKey, value.name);
}

class AmoledNotifier extends _SavedSetting<bool> {
  AmoledNotifier({bool? initialValue}) : super(initialValue, false);

  static bool? loadFromPrefs(SharedPreferences prefs) =>
      prefs.getBool(kAmoledPrefKey);

  @override
  bool? read(SharedPreferences prefs) => loadFromPrefs(prefs);

  @override
  Future<void> write(SharedPreferences prefs, bool value) =>
      prefs.setBool(kAmoledPrefKey, value);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>(
      (ref) => ThemeModeNotifier(),
    );

final themePaletteProvider =
    StateNotifierProvider<ThemePaletteNotifier, ThemePalette>(
      (ref) => ThemePaletteNotifier(),
    );

/// Pure black behind every dark theme, for OLED screens.
final amoledProvider = StateNotifierProvider<AmoledNotifier, bool>(
  (ref) => AmoledNotifier(),
);

/// The platform's own colors: the wallpaper palette on Android 12+, the accent
/// color on desktops. Null where the platform offers neither.
final platformColorSchemesProvider = FutureProvider<DynamicColorSchemes?>((
  ref,
) async {
  try {
    final core = await DynamicColorPlugin.getCorePalette();
    if (core != null) {
      return DynamicColorSchemes(
        light: core.toColorScheme(),
        dark: core.toColorScheme(brightness: Brightness.dark),
      );
    }
  } on PlatformException catch (_) {
  } on MissingPluginException catch (_) {}
  try {
    final accent = await DynamicColorPlugin.getAccentColor();
    if (accent != null) return DynamicColorSchemes.fromSeed(accent);
  } on PlatformException catch (_) {
  } on MissingPluginException catch (_) {}
  return null;
});

/// Colors drawn from the playing song's cover, while the Album theme is
/// chosen. Null until a cover has been read.
///
/// The thumbnail the mini player stores is used when there is one, so this
/// rarely costs a request; offline, only a stored copy is used.
final albumColorSchemesProvider = FutureProvider<DynamicColorSchemes?>((
  ref,
) async {
  if (ref.watch(themePaletteProvider) != ThemePalette.album) return null;
  final coverArtId = ref.watch(
    playerProvider.select((s) => s.currentSong?.coverArtId),
  );
  if (coverArtId == null) return null;
  final cache = ref.watch(artCacheProvider);
  final client = ref.watch(subsonicClientProvider);
  final offline = ref.watch(isOfflineModeProvider);

  const size = 128;
  final ImageProvider image;
  final stored = await CoverArtCache.findCached(
    cache,
    coverArtId,
    preferredSize: size,
  );
  if (stored != null) {
    image = FileImage(stored);
  } else if (!offline && client != null) {
    image = CachedNetworkImageProvider(
      client.getCoverArtUri(coverArtId, size: size).toString(),
      cacheKey: coverCacheKey(coverArtId, size),
      cacheManager: cache,
    );
  } else {
    return null;
  }

  try {
    // Fidelity keeps the cover's own hue and strength rather than the muted
    // tone a tonal-spot scheme settles on, so the theme reads as the sleeve.
    final schemes = await Future.wait([
      for (final brightness in Brightness.values)
        ColorScheme.fromImageProvider(
          provider: image,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
    ]);
    return DynamicColorSchemes(
      dark: schemes[Brightness.values.indexOf(Brightness.dark)],
      light: schemes[Brightness.values.indexOf(Brightness.light)],
    );
  } catch (_) {
    return null;
  }
});

/// The scheme [palette] draws in at [brightness]. [device] and [album] come
/// from the providers above and fall back to flax's own violet until — or
/// unless — they have colors.
ColorScheme resolvePaletteScheme(
  ThemePalette palette,
  Brightness brightness, {
  DynamicColorSchemes? device,
  DynamicColorSchemes? album,
}) {
  final runtime = switch (palette) {
    ThemePalette.device => device?.of(brightness),
    ThemePalette.album => album?.of(brightness),
    _ => null,
  };
  return runtime ??
      palette.fixedScheme(brightness) ??
      ThemePalette.flax.fixedScheme(brightness)!;
}

ThemeMode resolveThemeMode(ThemeModeSetting setting) {
  return switch (setting) {
    ThemeModeSetting.system => ThemeMode.system,
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
  };
}
