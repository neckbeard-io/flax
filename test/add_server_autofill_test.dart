import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'AddServerScreen configures AutofillGroup and autofillHints for credentials',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AddServerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AutofillGroup wraps the form fields
      expect(find.byType(AutofillGroup), findsOneWidget);

      // Find all text fields
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(textFields.length, greaterThanOrEqualTo(4));

      // Find password field
      final passwordField = textFields.firstWhere(
        (tf) => tf.autofillHints?.contains(AutofillHints.password) ?? false,
      );
      expect(passwordField.obscureText, isTrue);

      // Find username field
      final usernameField = textFields.firstWhere(
        (tf) => tf.autofillHints?.contains(AutofillHints.username) ?? false,
      );
      expect(usernameField, isNotNull);

      // Find url field
      final urlField = textFields.firstWhere(
        (tf) => tf.autofillHints?.contains(AutofillHints.url) ?? false,
      );
      expect(urlField, isNotNull);
    },
  );
}
