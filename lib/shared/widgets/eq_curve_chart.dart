import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One point on a frequency-response curve.
class CurvePoint {
  const CurvePoint(this.frequency, this.gainDb);

  final double frequency;
  final double gainDb;
}

/// A curve to draw inside an [EqCurveChart].
class EqCurve {
  const EqCurve({
    required this.points,
    required this.color,
    this.fill = true,
    this.showDots = false,
    this.strokeWidth = 2,
  });

  final List<CurvePoint> points;
  final Color color;

  /// Whether to fade a gradient from the line down to the baseline.
  final bool fill;

  /// Draw a dot at each point — suits the handful of bands in a graphic EQ,
  /// but not the hundreds of points in an AutoEQ curve.
  final bool showDots;

  final double strokeWidth;
}

/// Frequency-response plot on a log-frequency axis.
///
/// Used to show what the EQ is actually doing: the AutoEQ correction curve, the
/// manual graphic-EQ curve, or both at once so their interaction is visible.
/// Several curves can be layered — they are drawn in order, so pass the
/// background one first.
class EqCurveChart extends StatelessWidget {
  const EqCurveChart({
    super.key,
    required this.curves,
    this.height = 120,
    this.minFrequency = 20,
    this.maxFrequency = 20000,
    this.gainRangeDb,
    this.showGrid = true,
    this.showFrequencyLabels = true,
    this.backgroundColor,
  });

  final List<EqCurve> curves;
  final double height;
  final double minFrequency;
  final double maxFrequency;

  /// Forces a symmetric range of ±[gainRangeDb]. Left null, the range is fitted
  /// to the data instead.
  final double? gainRangeDb;

  final bool showGrid;
  final bool showFrequencyLabels;

  /// Plot background. Defaults to a tint of the surface, which is fine on a
  /// plain page but needs overriding when the chart sits on an already-colored
  /// card — otherwise the curve is drawn tone-on-tone and vanishes.
  final Color? backgroundColor;

  /// Vertical bounds in dB, fitted to the data.
  ///
  /// Deliberately *not* symmetric about 0: correction curves are frequently all
  /// cut or all boost, and a symmetric range would leave half the plot empty and
  /// squash the detail into a band. 0 dB is always kept in view so the curve
  /// still reads as deviation from flat rather than as an abstract shape.
  ({double min, double max}) _resolveBounds() {
    if (gainRangeDb != null) {
      return (min: -gainRangeDb!, max: gainRangeDb!);
    }

    var lo = 0.0;
    var hi = 0.0;
    for (final c in curves) {
      for (final p in c.points) {
        lo = math.min(lo, p.gainDb);
        hi = math.max(hi, p.gainDb);
      }
    }

    // Pad by a tenth of the span so the line never rides the edge, then round
    // outward to whole dB. The 6 dB floor stops a nearly flat curve from being
    // magnified into dramatic-looking noise.
    final span = math.max(hi - lo, 6.0);
    final pad = span * 0.1;
    return (min: (lo - pad).floorToDouble(), max: (hi + pad).ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = _resolveBounds();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CustomPaint(
              painter: _EqCurvePainter(
                curves: curves,
                minFrequency: minFrequency,
                maxFrequency: maxFrequency,
                minDb: bounds.min,
                maxDb: bounds.max,
                showGrid: showGrid,
                gridColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.35,
                ),
                zeroLineColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ),
        ),
        if (showFrequencyLabels) ...[
          const SizedBox(height: 4),
          _FrequencyAxis(
            minDb: bounds.min,
            maxDb: bounds.max,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

/// Labels beneath the plot: the fitted dB range on the left, decade marks across.
class _FrequencyAxis extends StatelessWidget {
  const _FrequencyAxis({required this.minDb, required this.maxDb, this.style});

  final double minDb;
  final double maxDb;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${minDb.toStringAsFixed(0)}…'
          '${maxDb > 0 ? "+" : ""}${maxDb.toStringAsFixed(0)} dB',
          style: style,
        ),
        const Spacer(),
        Text('100', style: style),
        const Spacer(),
        Text('1k', style: style),
        const Spacer(),
        Text('10k', style: style),
      ],
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({
    required this.curves,
    required this.minFrequency,
    required this.maxFrequency,
    required this.minDb,
    required this.maxDb,
    required this.showGrid,
    required this.gridColor,
    required this.zeroLineColor,
  });

  final List<EqCurve> curves;
  final double minFrequency;
  final double maxFrequency;
  final double minDb;
  final double maxDb;
  final bool showGrid;
  final Color gridColor;
  final Color zeroLineColor;

  /// Horizontal position for a frequency, log-scaled so each decade gets equal
  /// width — the only way a 20 Hz–20 kHz plot is readable.
  double _x(double freq, double width) {
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    final t =
        (math.log(freq.clamp(minFrequency, maxFrequency)) - logMin) /
        (logMax - logMin);
    return t * width;
  }

  /// Vertical position for a gain. Higher gain is higher on screen; 0 dB lands
  /// wherever the fitted range puts it, not necessarily the center.
  double _y(double gainDb, double height) {
    final span = maxDb - minDb;
    if (span <= 0) return height / 2;
    final t = (gainDb.clamp(minDb, maxDb) - minDb) / span;
    return height - t * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);

    for (final curve in curves) {
      if (curve.points.length < 2) continue;
      _paintCurve(canvas, size, curve);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Decade lines, plus the 2..9 minor marks that make a log axis legible.
    for (var decade = 10.0; decade <= maxFrequency; decade *= 10) {
      for (var mult = 1; mult < 10; mult++) {
        final freq = decade * mult;
        if (freq < minFrequency || freq > maxFrequency) continue;
        final x = _x(freq, size.width);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          mult == 1
              ? grid
              : (Paint()..color = gridColor.withValues(alpha: 0.12)),
        );
      }
    }

    // The 0 dB baseline is the reference the eye needs most, so it is stronger
    // than the rest of the grid.
    final zeroY = _y(0, size.height);
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = zeroLineColor
        ..strokeWidth = 1,
    );
  }

  void _paintCurve(Canvas canvas, Size size, EqCurve curve) {
    final path = Path();
    for (var i = 0; i < curve.points.length; i++) {
      final p = curve.points[i];
      final x = _x(p.frequency, size.width);
      final y = _y(p.gainDb, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (curve.fill) {
      // Close down to the 0 dB line rather than the bottom of the box, so cuts
      // fill downward and boosts upward — the shape reads as deviation from
      // flat instead of as a mass under the line.
      final zeroY = _y(0, size.height);
      final fillPath = Path.from(path)
        ..lineTo(_x(curve.points.last.frequency, size.width), zeroY)
        ..lineTo(_x(curve.points.first.frequency, size.width), zeroY)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              curve.color.withValues(alpha: 0.35),
              curve.color.withValues(alpha: 0.04),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = curve.color
        ..strokeWidth = curve.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (curve.showDots) {
      final dot = Paint()..color = curve.color;
      for (final p in curve.points) {
        canvas.drawCircle(
          Offset(_x(p.frequency, size.width), _y(p.gainDb, size.height)),
          2.5,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EqCurvePainter old) =>
      old.curves != curves ||
      old.minDb != minDb ||
      old.maxDb != maxDb ||
      old.minFrequency != minFrequency ||
      old.maxFrequency != maxFrequency;
}
