import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/app.dart';

void main() {
  testWidgets('Flax app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlaxApp()));
    await tester.pumpAndSettle();

    // On first launch with no server, should show the add server screen
    expect(find.text('Flax'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
