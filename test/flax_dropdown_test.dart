import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/widgets/flax_dropdown.dart';

/// The grey slab left behind after picking an option is [DropdownButton]'s
/// focus highlight: it builds an [InkWell] with
/// `focusColor: widget.focusColor ?? Theme.of(context).focusColor`, and
/// selecting leaves focus on the button, so the fill stays painted.
///
/// These assert against that [InkWell] rather than against [FlaxDropdown]'s own
/// field, because the field only matters if it actually reaches the widget doing
/// the painting.
void main() {
  const items = ['Auto', '48 kHz'];

  Widget host({
    required void Function(String?) onChanged,
    String value = 'Auto',
  }) => MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Scaffold(
      body: Center(
        child: FlaxDropdown<String>(
          value: value,
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    ),
  );

  InkWell inkWellOf(WidgetTester tester) => tester.widget<InkWell>(
    find
        .descendant(
          of: find.byType(FlaxDropdown<String>),
          matching: find.byType(InkWell),
        )
        .first,
  );

  testWidgets('the focus fill is transparent before anything is touched', (
    tester,
  ) async {
    await tester.pumpWidget(host(onChanged: (_) {}));

    expect(inkWellOf(tester).focusColor, Colors.transparent);
  });

  testWidgets('picking an option leaves no focus fill behind', (tester) async {
    // The reported bug, start to finish: open the menu, choose the other value,
    // and check that the button holding focus afterwards paints nothing.
    String? picked;
    await tester.pumpWidget(host(onChanged: (v) => picked = v));

    await tester.tap(find.byType(FlaxDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('48 kHz').last);
    await tester.pumpAndSettle();

    expect(picked, '48 kHz', reason: 'the selection must still be reported');
    expect(
      tester.binding.focusManager.primaryFocus?.hasFocus,
      isTrue,
      reason: 'focus does land on the button — that is why the fill showed',
    );
    expect(inkWellOf(tester).focusColor, Colors.transparent);
  });

  testWidgets('the hover affordance is kept, and is rounded', (tester) async {
    await tester.pumpWidget(host(onChanged: (_) {}));

    final inkWell = inkWellOf(tester);
    // Hover still says "this is clickable"; only the meaningless focus fill was
    // removed. The radius is what stops it drawing as a hard-edged block.
    expect(inkWell.hoverColor, isNot(Colors.transparent));
    expect(inkWell.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('a bare DropdownButton still has the fill we are removing', (
    tester,
  ) async {
    // A canary, not a requirement of flax. If this ever fails, Material stopped
    // painting a focus fill on dropdowns and FlaxDropdown's reason for existing
    // has gone away — check before deleting it, then delete it.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: DropdownButton<String>(
              value: 'Auto',
              items: items
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final bare = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byType(DropdownButton<String>),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(bare.focusColor, isNot(Colors.transparent));
  });
}
