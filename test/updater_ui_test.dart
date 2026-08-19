import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/features/updater/update_button.dart';
import 'package:flax/features/updater/whats_new_dialog.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';

void main() {
  testWidgets('UpdateButton is hidden when no update is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: UpdateButton())),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('UpdateButton renders when update is available', (tester) async {
    final state = UpdateState(
      stage: UpdateStage.available,
      currentVersion: '0.4.5',
      installMethod: InstallMethod.macosDmg,
      latestRelease: ReleaseInfo(
        tagName: 'v0.4.6',
        version: '0.4.6',
        title: 'flax v0.4.6',
        body: 'Improvements',
        htmlUrl: 'http://example.com',
        publishedAt: DateTime.now(),
        isPrerelease: false,
        assets: const [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateNotifierProvider.overrideWith(
            (ref) => _FakeUpdateNotifier(state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: UpdateButton())),
      ),
    );

    expect(find.text('v0.4.6'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('WhatsNewDialog renders version and highlights', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WhatsNewDialog(version: '0.4.6')),
      ),
    );

    expect(find.text("What's New in v0.4.6"), findsOneWidget);
    expect(
      find.text("Don't show What's New after future updates"),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);
  });
}

class _FakeUpdateNotifier extends StateNotifier<UpdateState>
    implements UpdateNotifier {
  _FakeUpdateNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
