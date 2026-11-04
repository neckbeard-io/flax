import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/router.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

const _server = Server(
  id: 'srv',
  name: 'Test',
  url: 'http://localhost:4533',
  username: 'u',
  tokenHash: 't',
  salt: 's',
  isActive: true,
);

class _FakeServers extends ServerListNotifier {
  _FakeServers() {
    state = [_server];
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<GoRouter> _pumpMobileApp(WidgetTester tester) async {
  // Mobile width (e.g. 400x800)
  tester.view.physicalSize = const ui.Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [serverListProvider.overrideWith((ref) => _FakeServers())],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return router;
}

Finder _navItem(String text) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(text));

void main() {
  testWidgets(
    'mobile layout shows bottom bar with Artists, Albums, Search, Playlists, '
    'and Settings',
    (tester) async {
      final router = await _pumpMobileApp(tester);

      // Sidebar should NOT be rendered on mobile
      expect(find.byType(DesktopSidebar), findsNothing);

      // Bottom NavigationBar should be present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify destinations in bottom bar
      expect(_navItem('Artists'), findsOneWidget);
      expect(_navItem('Albums'), findsOneWidget);
      expect(_navItem('Search'), findsOneWidget);
      expect(_navItem('Playlists'), findsOneWidget);
      expect(_navItem('Settings'), findsOneWidget);
      expect(_navItem('Songs'), findsNothing);

      // Tap Playlists
      await tester.tap(_navItem('Playlists'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/playlists'));

      // Tap Settings
      await tester.tap(_navItem('Settings'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/settings'));

      // Tap Search
      await tester.tap(_navItem('Search'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/search'));

      // Tap Artists
      await tester.tap(_navItem('Artists'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/artists'));

      // Tap Albums
      await tester.tap(_navItem('Albums'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/albums'));
    },
  );

  // A label wider than its share of the bar wraps, and the bar cuts it off.
  testWidgets('every bottom bar label fits a 360px phone in every language', (
    tester,
  ) async {
    // Beside the test runner in Flutter's cache. Chinese and Japanese aren't in
    // this font; they fall back to the test font, whose glyphs are one em wide,
    // as theirs are.
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final font = File(
      '${artifacts.path}/material_fonts/Roboto-Medium.ttf',
    ).readAsBytesSync();
    await (FontLoader('Roboto')..addFont(
          Future.value(ByteData.sublistView(Uint8List.fromList(font))),
        ))
        .load();

    final style = FlaxTheme.dark().navigationBarTheme.labelTextStyle!
        .resolve(const {})!
        .copyWith(fontFamily: 'Roboto');
    const slot = 360 / 5;

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final label in [
        l10n.navArtists,
        l10n.navAlbums,
        l10n.navSearch,
        l10n.navPlaylistsShort,
        l10n.navSettings,
      ]) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(
          painter.width,
          lessThanOrEqualTo(slot),
          reason: '"$label" (${locale.languageCode})',
        );
        painter.dispose();
      }
    }
  });

  testWidgets('the desktop sidebar lists Playlists below Downloads', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [serverListProvider.overrideWith((ref) => _FakeServers())],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _settle(tester);

    double y(String label) => tester
        .getCenter(
          find.descendant(
            of: find.byType(DesktopSidebar),
            matching: find.text(label),
          ),
        )
        .dy;

    expect(y('Playlists'), greaterThan(y('Downloads')));
    expect(y('Playlists'), lessThan(y('Settings')));

    await tester.tap(
      find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.text('Playlists'),
      ),
    );
    await _settle(tester);
    expect(router.state.uri.path, equals('/playlists'));
  });
}
