import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/app/screen_recovery.dart';

FlutterErrorDetails _details() => FlutterErrorDetails(
  exception: StateError('Bad route state'),
  stack: StackTrace.current,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScreenRecovery.resetForTest();
  });

  tearDown(ScreenRecovery.resetForTest);

  testWidgets('a failed screen says what happened and offers a restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var restarts = 0;
    ScreenRecovery.restartOverride = () async => restarts++;

    // Nothing above it: whatever failed may be what provides the theme.
    await tester.pumpWidget(RecoveryView(_details()));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Bad route state'), findsOneWidget);
    expect(ScreenRecovery.isBroken, isTrue);

    final restart = tester.getRect(find.text('Restart flax'));
    expect(restart.right, lessThanOrEqualTo(390));
    await tester.tap(find.text('Restart flax'));
    await tester.pump();
    expect(restarts, 1);
  });

  testWidgets('copying the error puts it on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(RecoveryView(_details()));
    await tester.tap(find.text('Copy error'));
    await tester.pump();

    expect(copied, contains('Bad route state'));
  });

  testWidgets('a small failure, like one tile, stays a quiet placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 120,
          height: 48,
          child: RecoveryView(_details()),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsNothing);
    expect(tester.getSize(find.byType(RecoveryView)), const Size(120, 48));
    expect(ScreenRecovery.isBroken, isFalse);
  });

  testWidgets('without bounds the placeholder keeps a small fixed size', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [RecoveryView(_details())]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RecoveryView)).width, 24);
  });

  testWidgets('coming back to a broken screen returns home and rebuilds', (
    tester,
  ) async {
    var homes = 0;
    ScreenRecovery.install(goHome: () => homes++);
    await tester.pumpWidget(RecoveryView(_details()));
    expect(ScreenRecovery.isBroken, isTrue);

    await tester.pumpWidget(const SizedBox());
    ScreenRecovery.heal();
    await tester.pump();

    expect(homes, 1);
    expect(ScreenRecovery.isBroken, isFalse);
  });

  testWidgets('coming back to a healthy app changes nothing', (tester) async {
    var homes = 0;
    ScreenRecovery.install(goHome: () => homes++);

    ScreenRecovery.heal();

    expect(homes, 0);
  });

  test('a failed screen makes the next launch start from home, once', () async {
    ScreenRecovery.markBroken();
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();

    expect(ScreenRecovery.takePreviousFailure(prefs), isTrue);
    await pumpEventQueue();
    expect(ScreenRecovery.takePreviousFailure(prefs), isFalse);
  });
}
