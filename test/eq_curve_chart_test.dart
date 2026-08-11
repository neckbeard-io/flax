import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/shared/widgets/eq_curve_chart.dart';

/// Real oratory1990 correction curve for the Sennheiser HD 650, taken verbatim
/// from the AutoEQ package archive. Using real data rather than a synthetic ramp
/// is the point: it exercises the actual point count, spacing, and dB range the
/// chart has to cope with.
const _fixture = 'test/fixtures/hd650_graphic.txt';

/// Set FLAX_CHART_PNG to a path to dump a rendered PNG for eyeballing.
const _pngEnvVar = 'FLAX_CHART_PNG';

void main() {
  group('GraphicEQ parsing', () {
    test('parses a real AutoEQ curve', () {
      final raw = File(_fixture).readAsStringSync();
      final points = AutoEqProfile.parseGraphicEq(raw);

      expect(points.length, 127);
      // The "GraphicEQ:" prefix must not survive into the first frequency.
      expect(points.first.frequency, 20);
      expect(points.first.gain, closeTo(-0.2, 1e-9));
      expect(points.last.frequency, greaterThan(19000));
      // Frequencies must come out ascending, or log interpolation walks
      // backwards and the curve renders as a scribble.
      for (var i = 1; i < points.length; i++) {
        expect(points[i].frequency, greaterThan(points[i - 1].frequency));
      }
    });

    test('a profile with no raw data yields no points', () {
      // This is the state a broken cache left every profile in, and the reason
      // AutoEQ applied nothing while appearing configured.
      final profile = AutoEqProfile(id: 1, name: 'x', source: 'y');
      expect(profile.points, isEmpty);
    });

    test('ignores malformed pairs instead of throwing', () {
      final points = AutoEqProfile.parseGraphicEq(
        'GraphicEQ: 20 -1.0; garbage; 100 2.5; 200; 400 -3',
      );
      expect(points.map((p) => p.frequency), [20, 100, 400]);
    });
  });

  group('EqCurveChart', () {
    testWidgets('renders a real curve without overflowing or throwing', (
      tester,
    ) async {
      final points = AutoEqProfile.parseGraphicEq(
        File(_fixture).readAsStringSync(),
      );
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 420,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EqCurveChart(
                      height: 140,
                      curves: [
                        EqCurve(
                          points: [
                            for (final p in points)
                              CurvePoint(p.frequency, p.gain),
                          ],
                          color: const Color(0xFF7CE9C3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EqCurveChart), findsOneWidget);

      final pngPath = Platform.environment[_pngEnvVar];
      if (pngPath != null) {
        // toImage drives real async work, which deadlocks inside the test's
        // fake-async zone unless it runs via runAsync.
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(pngPath).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    });

    testWidgets('layers multiple curves', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: EqCurveChart(
                curves: [
                  const EqCurve(
                    points: [CurvePoint(20, -6), CurvePoint(20000, 3)],
                    color: Colors.blue,
                  ),
                  const EqCurve(
                    points: [CurvePoint(20, 2), CurvePoint(20000, -4)],
                    color: Colors.orange,
                    showDots: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single point is not enough to draw, and must not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: EqCurveChart(
                curves: const [
                  EqCurve(points: [CurvePoint(1000, 0)], color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty curve list renders an empty plot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: EqCurveChart(curves: [])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
