import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/equalizer_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'EqualizerScreen renders on phone dimensions (390x844) without overflow',
    (tester) async {
      tester.view.physicalSize = const ui.Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: EqualizerScreen())),
      );
      await tester.pumpAndSettle();

      // Verify all header controls are within screen bounds
      final autoLevelFinder = find.byTooltip(
        'Lower the whole curve so the loudest band is 0 dB',
      );
      expect(autoLevelFinder, findsOneWidget);
      final autoLevelRect = tester.getRect(autoLevelFinder);
      expect(autoLevelRect.right, lessThanOrEqualTo(390));

      final resetFinder = find.byTooltip('Reset bands and preamp to flat');
      expect(resetFinder, findsOneWidget);
      final resetRect = tester.getRect(resetFinder);
      expect(resetRect.right, lessThanOrEqualTo(390));

      // Zero all should no longer be present
      expect(find.text('Zero all'), findsNothing);
    },
  );

  testWidgets(
    'EqualizerScreen renders on compact phone dimensions (360x640) without overflow',
    (tester) async {
      tester.view.physicalSize = const ui.Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: EqualizerScreen())),
      );
      await tester.pumpAndSettle();

      final resetFinder = find.byTooltip('Reset bands and preamp to flat');
      expect(resetFinder, findsOneWidget);
      final resetRect = tester.getRect(resetFinder);
      expect(resetRect.right, lessThanOrEqualTo(360));
    },
  );

  testWidgets('Reset button resets equalizer state to flat and 0 dB preamp', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Apply a preset
    container.read(eqProvider.notifier).applyPreset('Rock');
    container.read(eqProvider.notifier).setPreamp(-4.0);

    expect(container.read(eqProvider).presetName, 'Rock');
    expect(container.read(eqProvider).preamp, -4.0);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EqualizerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap reset button
    final resetFinder = find.byTooltip('Reset bands and preamp to flat');
    await tester.tap(resetFinder);
    await tester.pumpAndSettle();

    expect(container.read(eqProvider).presetName, 'Flat');
    expect(container.read(eqProvider).preamp, 0.0);
  });
}
