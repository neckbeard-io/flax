import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/features/settings/hotkeys_screen.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/hotkeys/hotkey_service.dart';

import 'hotkey_service_test.dart';

Widget createTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HotkeysScreen renders shortcuts and switches without errors', (
    tester,
  ) async {
    final mockClient = MockHotKeyClient();
    final prefs = await SharedPreferences.getInstance();
    final notifier = HotKeyNotifier(
      client: mockClient,
      isDesktop: true,
      prefs: prefs,
    );
    await notifier.init();

    await tester.pumpWidget(
      createTestApp(
        const HotkeysScreen(),
        overrides: [hotKeyServiceProvider.overrideWith((ref) => notifier)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    expect(find.text('Enable Global Hotkeys'), findsOneWidget);
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Next Track'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('IN-APP SHORTCUTS'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('IN-APP SHORTCUTS'), findsOneWidget);
  });

  testWidgets('HotkeysScreen renders on mobile dimensions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockClient = MockHotKeyClient();
    final prefs = await SharedPreferences.getInstance();
    final notifier = HotKeyNotifier(
      client: mockClient,
      isDesktop: true,
      prefs: prefs,
    );
    await notifier.init();

    await tester.pumpWidget(
      createTestApp(
        const HotkeysScreen(),
        overrides: [hotKeyServiceProvider.overrideWith((ref) => notifier)],
      ),
    );
    await tester.pumpAndSettle();

    // Verify all widgets render inside mobile bounds without overflow
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Displays warning icon when shortcut registration fails', (
    tester,
  ) async {
    final mockClient = MockHotKeyClient();
    mockClient.failNextRegister = true;
    final prefs = await SharedPreferences.getInstance();
    final notifier = HotKeyNotifier(
      client: mockClient,
      isDesktop: true,
      prefs: prefs,
    );
    await notifier.init();
    await notifier.updateBinding(
      HotKeyAction.playPause,
      HotKeyAction.playPause.suggestedHotKey(),
    );

    await tester.pumpWidget(
      createTestApp(
        const HotkeysScreen(),
        overrides: [hotKeyServiceProvider.overrideWith((ref) => notifier)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });
}
