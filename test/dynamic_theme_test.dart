import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicColorSchemes & Pure-Dart Fallback', () {
    test('DynamicColorSchemes.fromSeed creates light and dark schemes', () {
      const seedColor = Color(0xFF1E88E5);
      final schemes = DynamicColorSchemes.fromSeed(seedColor);

      expect(schemes.light, isNotNull);
      expect(schemes.dark, isNotNull);
      expect(schemes.light!.brightness, equals(Brightness.light));
      expect(schemes.dark!.brightness, equals(Brightness.dark));
    });

    test('resolveThemeMode maps enum to ThemeMode correctly', () {
      expect(
        resolveThemeMode(ThemeModeSetting.system),
        equals(ThemeMode.system),
      );
      expect(resolveThemeMode(ThemeModeSetting.light), equals(ThemeMode.light));
      expect(resolveThemeMode(ThemeModeSetting.dark), equals(ThemeMode.dark));
    });
  });

  group('FlaxTheme Theme Generation', () {
    test('FlaxTheme.light uses default seed when dynamicScheme is null', () {
      final theme = FlaxTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.colorScheme.brightness, equals(Brightness.light));
    });

    test('FlaxTheme.light uses custom dynamicScheme when provided', () {
      const dynamicScheme = ColorScheme.light(primary: Color(0xFF00FF00));
      final theme = FlaxTheme.light(dynamicScheme: dynamicScheme);
      expect(theme.colorScheme.primary, equals(const Color(0xFF00FF00)));
    });

    test('FlaxTheme.dark uses default seed when dynamicScheme is null', () {
      final theme = FlaxTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.colorScheme.brightness, equals(Brightness.dark));
    });

    test('FlaxTheme.dark uses custom dynamicScheme when provided', () {
      const dynamicScheme = ColorScheme.dark(primary: Color(0xFFFF00FF));
      final theme = FlaxTheme.dark(dynamicScheme: dynamicScheme);
      expect(theme.colorScheme.primary, equals(const Color(0xFFFF00FF)));
    });

    test('FlaxTheme.dark applies AMOLED pure black when amoled is true', () {
      final standardDark = FlaxTheme.dark(amoled: false);
      final amoledDark = FlaxTheme.dark(amoled: true);

      expect(standardDark.scaffoldBackgroundColor, isNot(Colors.black));
      expect(amoledDark.scaffoldBackgroundColor, equals(Colors.black));
      expect(amoledDark.colorScheme.surface, equals(Colors.black));
      expect(amoledDark.colorScheme.onSurface, equals(Colors.white));
    });
  });

  group('Theme Widget Rendering', () {
    testWidgets('Theme applied to widgets on mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final dynamicSchemes = DynamicColorSchemes.fromSeed(
        const Color(0xFF6750A4),
      );
      final theme = FlaxTheme.dark(
        dynamicScheme: dynamicSchemes.dark,
        amoled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: AppBar(title: const Text('Dynamic Theme Test')),
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dynamic Theme Test'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });
  });
}
