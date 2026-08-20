import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/features/settings/transcoding_screen.dart';
import 'package:flax/shared/widgets/in_window_toaster.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineModeToggle & InWindowToaster widget tests', () {
    testWidgets(
      'OfflineModeToggle displays Offline label and toggles state on tap',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: Center(child: OfflineModeToggle())),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);

        // Tap to toggle offline mode
        await tester.tap(find.byType(OfflineModeToggle));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.offline_pin), findsOneWidget);
      },
    );

    testWidgets('InWindowToaster shows and dismisses toast message', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [InWindowToaster()])),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Server unreachable'), findsNothing);

      // Post message
      container
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable (3s timeout). Switched to Offline mode.');
      await tester.pumpAndSettle();

      expect(
        find.text('Server unreachable (3s timeout). Switched to Offline mode.'),
        findsOneWidget,
      );

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.text('Server unreachable (3s timeout). Switched to Offline mode.'),
        findsNothing,
      );
    });

    testWidgets(
      'Settings screen renders on phone dimensions without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const server = Server(
          id: 'srv-1',
          name: 'Test Server',
          url: 'http://localhost:4533',
          username: 'admin',
          tokenHash: 'secret',
          salt: 'salt123',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWithValue(server),
              serverListProvider.overrideWith(
                (ref) => ServerListNotifier()..state = [server],
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Offline Mode'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Offline Mode'), findsOneWidget);
      },
    );

    testWidgets(
      'Transcoding screen renders on phone dimensions without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const server = Server(
          id: 'srv-1',
          name: 'Test Server',
          url: 'http://localhost:4533',
          username: 'admin',
          tokenHash: 'secret',
          salt: 'salt123',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [activeServerProvider.overrideWithValue(server)],
            child: const MaterialApp(home: TranscodingScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline when not on Wi-Fi'), findsOneWidget);
      },
    );
  });
}
