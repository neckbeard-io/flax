import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/autoeq_screen.dart';
import 'package:flax/services/autoeq/autoeq_database.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/shared/widgets/eq_curve_chart.dart';

/// Mounts the real AutoEQ screen against a real on-disk database, reproducing
/// what the app does on launch: restore the saved profile, load its curve, and
/// draw it.
///
/// Point FLAX_AUTOEQ_CACHE at a populated cache directory (one containing
/// index.json, meta.json and data/) to run. Without it the test skips, since it
/// cannot fabricate 8850 curves.
///
///   FLAX_AUTOEQ_CACHE="$HOME/Library/Containers/com.flaxplayer.flax/Data/\
///   Library/Application Support/com.flaxplayer.flax/autoeq" flutter test \
///   test/autoeq_screen_test.dart
const _cacheEnvVar = 'FLAX_AUTOEQ_CACHE';
const _pngEnvVar = 'FLAX_SCREEN_PNG';

void main() {
  final cachePath = Platform.environment[_cacheEnvVar];
  if (cachePath == null) {
    // ignore: avoid_print
    print('skipping: set $_cacheEnvVar to a populated AutoEQ cache directory');
  }

  testWidgets(
    'restores a saved profile and plots its correction curve',
    (tester) async {
      final cacheDir = Directory(cachePath!);

      // The same shape AutoEqProfile.toJson writes, so this is exactly what the
      // app finds in prefs after a profile has been chosen.
      SharedPreferences.setMockInitialValues({
        'flax_autoeq_profile': jsonEncode({
          'id': 6253,
          'name': 'Sennheiser HD 650',
          'source': 'oratory1990',
          'rank': 1,
        }),
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoEqDatabaseProvider.overrideWithValue(
              AutoEqDatabase(cacheDirOverride: cacheDir),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: RepaintBoundary(key: key, child: const AutoEqScreen()),
          ),
        ),
      );

      // Restore is async (file IO plus prefs), so settle before asserting.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);

      // The profile came back from prefs and resolved to a real curve.
      expect(find.text('Sennheiser HD 650'), findsOneWidget);

      // The whole point: a curve is present and plotted. Before the extraction
      // fix this profile restored with zero points and the screen showed the
      // "no correction curve" warning instead.
      expect(
        find.byType(EqCurveChart),
        findsOneWidget,
        reason: 'the correction curve must be plotted',
      );
      expect(
        find.textContaining('No correction curve loaded'),
        findsNothing,
        reason: 'the profile must have loaded actual curve data',
      );
      expect(find.textContaining('points'), findsOneWidget);
      expect(find.textContaining('Peak '), findsOneWidget);

      final pngPath = Platform.environment[_pngEnvVar];
      if (pngPath != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(pngPath).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    },
    skip: cachePath == null,
  );
}
