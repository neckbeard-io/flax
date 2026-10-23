import 'package:flax/app/bootstrap.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_palette.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/settings/theme_palette_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('palettes', () {
    test('every palette has a light and a dark scheme', () {
      for (final palette in ThemePalette.values) {
        for (final brightness in Brightness.values) {
          final scheme = resolvePaletteScheme(palette, brightness);
          expect(scheme.brightness, brightness, reason: '$palette');
        }
      }
    });

    test('dark versions are darker than light ones', () {
      for (final palette in ThemePalette.values) {
        final light = resolvePaletteScheme(palette, Brightness.light);
        final dark = resolvePaletteScheme(palette, Brightness.dark);
        expect(
          dark.surface.computeLuminance(),
          lessThan(light.surface.computeLuminance()),
          reason: '$palette',
        );
      }
    });

    test('text is readable on every fixed palette background', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final palette in ThemePalette.values) {
        for (final brightness in Brightness.values) {
          final s = resolvePaletteScheme(palette, brightness);
          expect(
            contrast(s.onSurface, s.surface),
            greaterThanOrEqualTo(7),
            reason: '$palette $brightness text',
          );
          expect(
            contrast(s.primary, s.surface),
            greaterThanOrEqualTo(3),
            reason: '$palette $brightness accent',
          );
        }
      }
    });

    test('a named palette keeps its own background', () {
      expect(
        resolvePaletteScheme(ThemePalette.nord, Brightness.dark).surface,
        const Color(0xFF2E3440),
      );
    });

    test('device and album fall back to flax until they have colors', () {
      final flax = resolvePaletteScheme(ThemePalette.flax, Brightness.dark);
      expect(
        resolvePaletteScheme(ThemePalette.album, Brightness.dark).primary,
        flax.primary,
      );
      final album = DynamicColorSchemes.fromSeed(const Color(0xFFE53935));
      expect(
        resolvePaletteScheme(
          ThemePalette.album,
          Brightness.dark,
          album: album,
        ).primary,
        album.dark!.primary,
      );
    });

    test('AMOLED turns any dark palette black', () {
      final theme = FlaxTheme.dark(
        dynamicScheme: resolvePaletteScheme(
          ThemePalette.dracula,
          Brightness.dark,
        ),
        amoled: true,
      );
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.surface, Colors.black);
    });

    test('an unknown saved name falls back to the default', () {
      expect(ThemePalette.fromName('gone'), ThemePalette.fallback);
    });
  });

  group('saved choices', () {
    test('survive a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(themePaletteProvider.notifier)
          .set(ThemePalette.gruvbox);
      await container
          .read(themeModeProvider.notifier)
          .set(ThemeModeSetting.dark);
      await container.read(amoledProvider.notifier).set(true);

      final startup = StartupState.fromPrefs(
        await SharedPreferences.getInstance(),
      );
      expect(startup.themePalette, ThemePalette.gruvbox);
      expect(startup.themeMode, ThemeModeSetting.dark);
      expect(startup.amoled, isTrue);

      final restarted = ProviderContainer(overrides: startup.overrides);
      addTearDown(restarted.dispose);
      expect(restarted.read(themePaletteProvider), ThemePalette.gruvbox);
      expect(restarted.read(themeModeProvider), ThemeModeSetting.dark);
      expect(restarted.read(amoledProvider), isTrue);
    });

    test('default to device colors, system mode and no AMOLED', () async {
      SharedPreferences.setMockInitialValues({});
      final startup = StartupState.fromPrefs(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(overrides: startup.overrides);
      addTearDown(container.dispose);
      expect(container.read(themePaletteProvider), ThemePalette.device);
      expect(container.read(themeModeProvider), ThemeModeSetting.system);
      expect(container.read(amoledProvider), isFalse);
    });
  });

  group('picker', () {
    Widget picker({
      required ThemePalette selected,
      required ValueChanged<ThemePalette> onSelected,
    }) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ThemePalettePicker(
            selected: selected,
            schemeFor: (p) => resolvePaletteScheme(p, Brightness.light),
            onSelected: onSelected,
          ),
        ),
      ),
    );

    testWidgets('fits a phone, two swatches across', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        picker(selected: ThemePalette.device, onSelected: (_) {}),
      );

      for (final palette in ThemePalette.values) {
        final rect = tester.getRect(
          find.byKey(ValueKey('theme-palette-${palette.name}')),
        );
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$palette');
        expect(rect.right, lessThanOrEqualTo(390), reason: '$palette');
      }
      final first = tester.getRect(
        find.byKey(const ValueKey('theme-palette-device')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('theme-palette-flax')),
      );
      expect(second.top, first.top);
    });

    testWidgets('tapping a swatch chooses it', (tester) async {
      ThemePalette? chosen;
      await tester.pumpWidget(
        picker(selected: ThemePalette.device, onSelected: (p) => chosen = p),
      );
      await tester.tap(find.text('Nord'));
      expect(chosen, ThemePalette.nord);
    });
  });
}
