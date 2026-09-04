import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';

const _albumWithArtist = Album(
  id: 'alb-1',
  serverId: 'srv-1',
  name: 'The Human Equation',
  artistId: 'art-1',
  artistName: 'Ayreon',
  songCount: 20,
  duration: 6000,
);

const _albumWithoutArtist = Album(
  id: 'alb-2',
  serverId: 'srv-1',
  name: 'Compilation Album',
  artistId: null,
  artistName: null,
  songCount: 10,
  duration: 3000,
);

Future<void> _pumpContextMenu(
  WidgetTester tester, {
  required Album album,
  List<dynamic> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: AlbumContextMenu(
              album: album,
              child: Container(
                key: const ValueKey('album_target'),
                width: 100,
                height: 100,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('AlbumContextMenu', () {
    testWidgets('shows context menu without Go to Album when right clicked', (
      tester,
    ) async {
      await _pumpContextMenu(tester, album: _albumWithArtist);

      // Right-click the target container
      final target = find.byKey(const ValueKey('album_target'));
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // "Go to Album" must not be present
      expect(find.text('Go to Album'), findsNothing);

      // "Go to Artist", "Play Now", "Add to Queue", and "Cache Offline" must be present
      expect(find.text('Go to Artist'), findsOneWidget);
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Cache Offline'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsNWidgets(2));
    });

    testWidgets('omits Go to Artist when artistId is null', (tester) async {
      await _pumpContextMenu(tester, album: _albumWithoutArtist);

      // Right-click the target container
      final target = find.byKey(const ValueKey('album_target'));
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Neither Go to Album nor Go to Artist should be present
      expect(find.text('Go to Album'), findsNothing);
      expect(find.text('Go to Artist'), findsNothing);
      expect(find.byType(PopupMenuDivider), findsOneWidget);

      // Playback options and Cache Offline are still present
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Cache Offline'), findsOneWidget);
    });

    testWidgets(
      'shows both Complete Caching and Remove from Cache when partially cached',
      (tester) async {
        await _pumpContextMenu(
          tester,
          album: _albumWithArtist,
          overrides: [
            downloadedAlbumIdsProvider.overrideWith(
              (ref) => Stream.value(const {}),
            ),
            anyDownloadedAlbumIdsProvider.overrideWith(
              (ref) => Stream.value({'alb-1'}),
            ),
          ],
        );

        final target = find.byKey(const ValueKey('album_target'));
        await tester.tap(target, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Complete Caching'), findsOneWidget);
        expect(find.text('Remove from Cache'), findsOneWidget);
        expect(find.text('Cache Offline'), findsNothing);
      },
    );

    testWidgets('shows only Remove from Cache when fully cached', (
      tester,
    ) async {
      await _pumpContextMenu(
        tester,
        album: _albumWithArtist,
        overrides: [
          downloadedAlbumIdsProvider.overrideWith(
            (ref) => Stream.value({'alb-1'}),
          ),
          anyDownloadedAlbumIdsProvider.overrideWith(
            (ref) => Stream.value({'alb-1'}),
          ),
        ],
      );

      final target = find.byKey(const ValueKey('album_target'));
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Remove from Cache'), findsOneWidget);
      expect(find.text('Complete Caching'), findsNothing);
      expect(find.text('Cache Offline'), findsNothing);
    });
  });
}
