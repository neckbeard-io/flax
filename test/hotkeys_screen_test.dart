import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/features/settings/hotkeys_screen.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/hotkeys/hotkey_service.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

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

  testWidgets('Tapping a shortcut row opens the record dialog', (tester) async {
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

    // Tap on the 'Play / Pause' row directly
    await tester.tap(find.text('Play / Pause'));
    await tester.pumpAndSettle();

    expect(find.text('Shortcut: Play / Pause'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Shortcut: Play / Pause'), findsNothing);
  });

  testWidgets('Tapping Use Suggested populates suggested shortcuts', (
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

    // Tap 'Use Suggested' button
    await tester.tap(find.text('Use Suggested'));
    await tester.pumpAndSettle();

    expect(notifier.state.bindings.values.every((v) => v != null), isTrue);
  });

  testWidgets('Displays desktop-only notice when opened on mobile platform', (
    tester,
  ) async {
    debugOverrideIsDesktopPlatform = false;
    addTearDown(() => debugOverrideIsDesktopPlatform = null);

    await tester.pumpWidget(createTestApp(const HotkeysScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Keyboard shortcuts and global hotkeys are only available on desktop platforms (macOS, Windows, and Linux).',
      ),
      findsOneWidget,
    );
    expect(find.text('GLOBAL HOTKEYS'), findsNothing);
  });
}
