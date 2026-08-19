import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/artist_context_menu.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';

const _testSong = Song(
  id: 'song-1',
  serverId: 'srv-1',
  albumId: 'alb-1',
  artistId: 'art-1',
  title: 'Hallowed Be Thy Name',
  artistName: 'Iron Maiden',
  duration: 432,
);

const _testArtist = Artist(
  id: 'art-1',
  serverId: 'srv-1',
  name: 'Iron Maiden',
  albumCount: 16,
);

void main() {
  group('SongContextMenu', () {
    testWidgets('shows context menu options on right click', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SongContextMenu(
                  song: _testSong,
                  child: Container(
                    key: const ValueKey('song_target'),
                    width: 100,
                    height: 50,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final target = find.byKey(const ValueKey('song_target'));
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Go to Artist'), findsOneWidget);
      expect(find.text('Go to Album'), findsOneWidget);
      expect(find.text('Cache Offline'), findsOneWidget);
    });
  });

  group('ArtistContextMenu', () {
    testWidgets('shows context menu options on right click', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ArtistContextMenu(
                  artist: _testArtist,
                  child: Container(
                    key: const ValueKey('artist_target'),
                    width: 100,
                    height: 50,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final target = find.byKey(const ValueKey('artist_target'));
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('View Artist'), findsOneWidget);
      expect(find.text('Play Artist'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Cache Offline'), findsOneWidget);
    });
  });
}
