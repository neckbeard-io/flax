import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Flax',
      packageName: 'io.neckbeard.flax',
      version: '0.5.1',
      buildNumber: '140',
      buildSignature: '',
    );
  });

  group('SettingsScreen & _AboutTile', () {
    testWidgets('renders GitHub repository HoverLink and responds to tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom where About & System lives
      await tester.scrollUntilVisible(
        find.text('About & System'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flax'), findsOneWidget);
      expect(find.text('GPL-3.0-or-later · source at '), findsOneWidget);

      final githubLink = find.byWidgetPredicate(
        (w) => w is HoverLink && w.text == 'github.com/neckbeard-io/flax',
      );
      expect(githubLink, findsOneWidget);

      // Verify tap works cleanly
      await tester.tap(githubLink);
      await tester.pumpAndSettle();
    });

    testWidgets('renders Sync Queue with Server switch tile and toggles state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sync Queue with Server'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Queue with Server'), findsOneWidget);
      expect(
        find.text(
          'Sync active queue and playback position with the server across devices',
        ),
        findsOneWidget,
      );

      // Tap the switch to disable
      await tester.tap(find.text('Sync Queue with Server'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Keep active queue local to this device; prevents other devices from overwriting playback state',
        ),
        findsOneWidget,
      );
    });
  });
}
