import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/l10n/app_localizations.dart';

Widget createTestApp({Locale? initialLocale}) {
  return ProviderScope(
    overrides: [
      if (initialLocale != null)
        localeProvider.overrideWith((ref) => LocaleNotifier(initialLocale)),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final locale = ref.watch(localeProvider);
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale ?? const Locale('en'),
          home: const AddServerScreen(),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'AddServerScreen renders with localized strings and language selector',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Default English strings
      expect(find.text('Connect to your music server'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.byType(DropdownButton<String?>), findsOneWidget);

      // Trigger validation to check English error messages
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(4));

      // Tap language dropdown to switch to German
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();

      // Select Deutsch
      final germanItem = find.text('Deutsch').last;
      await tester.tap(germanItem);
      await tester.pumpAndSettle();

      // Verify UI updated live to German
      expect(find.text('Mit Musikserver verbinden'), findsOneWidget);
      expect(find.text('Verbinden'), findsOneWidget);

      // Trigger validation in German
      await tester.ensureVisible(find.text('Verbinden'));
      await tester.tap(find.text('Verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('Erforderlich'), findsNWidgets(4));
    },
  );

  testWidgets('AddServerScreen renders on phone dimensions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Connect to your music server'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
