import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/settings/diagnostics_dialog.dart';
import 'package:flax/services/diagnostics/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleReport = DiagnosticsReport(
    appVersion: 'v0.5.6',
    buildNumber: '185',
    updateChannel: 'Dev',
    buildMode: 'Release',
    osName: 'Android',
    osVersion: 'Android 14 (API 34)',
    architecture: 'arm64-v8a',
    dartVersion: '3.12.2',
    outputDevice: 'auto',
    outputDescription: 'Speaker',
    outputEngine: 'OpenSL ES',
    exclusiveMode: false,
    sampleRate: '48000',
    bitDepth: '24',
    eqEnabled: false,
    eqPreset: 'Flat',
    eqPreamp: 0.0,
    serverType: 'Navidrome',
    serverVersion: '0.53.0',
    subsonicApiVersion: '1.16.1',
    openSubsonicSupported: true,
    cacheLimit: '5 GB',
    audioCachedBytes: 52428800,
    audioCachedTracks: 15,
    backgroundSyncStatus: 'Scheduled',
    recentLogs: ['[INFO] Sample runtime log entry'],
  );

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        diagnosticsReportProvider.overrideWith((ref) async => sampleReport),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets(
    'DiagnosticsDialog renders cleanly on mobile dimensions without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestApp(const DiagnosticsDialog()));
      await tester.pumpAndSettle();

      // Ensure key UI sections are visible without overflow
      expect(find.text('Diagnostics & System Info'), findsOneWidget);
      expect(find.textContaining('v0.5.6'), findsWidgets);
      expect(find.textContaining('Android 14'), findsWidgets);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(find.text('Open GitHub Issue'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Verify that interactive action buttons stay within phone screen bounds
      final copyRect = tester.getRect(find.text('Copy to Clipboard'));
      expect(copyRect.right, lessThanOrEqualTo(390));
      expect(copyRect.left, greaterThanOrEqualTo(0));

      final issueRect = tester.getRect(find.text('Open GitHub Issue'));
      expect(issueRect.right, lessThanOrEqualTo(390));
      expect(issueRect.left, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'Tapping Copy to Clipboard copies sanitized markdown and shows snackbar feedback',
    (tester) async {
      final methodCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          methodCalls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(createTestApp(const DiagnosticsDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pump();

      // Check method call was made to clipboard
      expect(
        methodCalls.any((call) => call.method == 'Clipboard.setData'),
        isTrue,
      );
      final setCall = methodCalls.firstWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(setCall.arguments['text'], contains('### Environment & Client'));
      expect(setCall.arguments['text'], contains('v0.5.6'));

      // Check snackbar feedback
      expect(
        find.text('Diagnostics report copied to clipboard'),
        findsOneWidget,
      );
    },
  );
}
