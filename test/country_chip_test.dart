
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/widgets/country_chip.dart';

void main() {
  testWidgets('flag and icon chips align with each other', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: Container(
                color: const Color(0xFF141418),
                padding: const EdgeInsets.all(16),
                child: const Wrap(
                  spacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InfoChip(label: 'Canada', countryCode: 'CA'),
                    InfoChip(label: '1999–present', icon: Icons.calendar_today),
                    InfoChip(label: 'Bergen', icon: Icons.public),
                    InfoChip(label: 'Norway', countryCode: 'NO'),
                  ],
                ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The point of the fixed-size leading slot: every chip's label must share a
    // vertical centre, whatever its leading glyph is. Before this, an emoji and
    // a Material icon had different intrinsic heights and the row stepped.
    final labels = ['Canada', '1999–present', 'Bergen', 'Norway']
        .map((t) => tester.getCenter(find.text(t)).dy)
        .toList();
    for (final dy in labels) {
      expect(dy, closeTo(labels.first, 0.5),
          reason: 'chip labels should share a centre line: $labels');
    }

    // And the leading slots themselves.
    final flag = tester.getCenter(find.byType(CountryFlagIcon).first).dy;
    final icon = tester.getCenter(find.byIcon(Icons.calendar_today)).dy;
    expect(flag, closeTo(icon, 0.5),
        reason: 'a flag and an icon should sit at the same height');

  });

  testWidgets('an unknown code falls back to the icon, not a blank',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoChip(
            label: 'Bergen',
            icon: Icons.public,
            countryCode: 'Bergen',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CountryFlagIcon), findsNothing);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });
}
