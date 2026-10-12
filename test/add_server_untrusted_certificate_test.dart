import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/l10n/app_localizations.dart';

/// Refuses the certificate unless asked to skip the check, like a
/// self-signed server.
class _SelfSignedServers extends ServerListNotifier {
  _SelfSignedServers() : super(initialServers: []);

  final calls = <bool>[];

  @override
  Future<Server> addServer({
    required String name,
    required String url,
    required String username,
    required String password,
    bool verifyCertificates = true,
  }) async {
    calls.add(verifyCertificates);
    if (verifyCertificates) throw const UntrustedCertificateException();
    return Server(
      id: 'srv',
      name: name,
      url: url,
      username: username,
      tokenHash: password,
      salt: '',
      verifyCertificates: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_SelfSignedServers> pumpAndConnect(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final servers = _SelfSignedServers();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AddServerScreen()),
        GoRoute(
          path: '/albums',
          builder: (_, _) => const Scaffold(body: Text('Albums')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serverListProvider.overrideWith((ref) => servers)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Home');
    await tester.enterText(fields.at(1), 'https://music.home.lan');
    await tester.enterText(fields.at(2), 'alice');
    await tester.enterText(fields.at(3), 'pw');
    await tester.ensureVisible(find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    return servers;
  }

  final addAnyway = find.widgetWithText(
    OutlinedButton,
    'Add without verifying',
  );

  testWidgets('says the certificate is the problem and offers to add anyway', (
    tester,
  ) async {
    final servers = await pumpAndConnect(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining("certificate isn't trusted"), findsOneWidget);
    await tester.ensureVisible(addAnyway);
    expect(tester.getRect(addAnyway).right, lessThanOrEqualTo(390));

    await tester.tap(addAnyway);
    await tester.pumpAndSettle();

    expect(servers.calls, [true, false]);
    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('withdraws the offer when the URL changes', (tester) async {
    await pumpAndConnect(tester);
    expect(addAnyway, findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://music.example.com',
    );
    await tester.pump();

    expect(addAnyway, findsNothing);
    expect(find.textContaining("certificate isn't trusted"), findsNothing);
  });
}
