import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/player/mini_player.dart';
import 'package:flax/features/player/player_provider.dart';

void main() {
  const testSong = Song(
    id: 's1',
    serverId: 'server1',
    title: 'Leather Lord',
    artistName: '3 Inches of Blood',
    suffix: 'flac',
    bitRate: 1411,
    duration: 225,
  );

  testWidgets(
    'MiniPlayer displays offline checkmark badge when playing cached song',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: true,
                  isPlayingCached: true,
                ),
              ),
            ),
            downloadedSongIdsProvider.overrideWith(
              (ref) => Stream.value({'s1'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: MiniPlayer()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Leather Lord'), findsOneWidget);
      expect(find.textContaining('3 Inches of Blood'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    },
  );

  testWidgets(
    'MiniPlayer displays offline checkmark badge when song id is in downloadedSongIds',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: true,
                  isPlayingCached: false,
                ),
              ),
            ),
            downloadedSongIdsProvider.overrideWith(
              (ref) => Stream.value({'s1'}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: MiniPlayer()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    },
  );

  testWidgets(
    'MiniPlayer does not display offline checkmark badge when song is not cached',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: true,
                  isPlayingCached: false,
                ),
              ),
            ),
            downloadedSongIdsProvider.overrideWith(
              (ref) => Stream.value(const {}),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: MiniPlayer()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.offline_pin), findsNothing);
    },
  );
}

class MockPlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  MockPlayerNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
