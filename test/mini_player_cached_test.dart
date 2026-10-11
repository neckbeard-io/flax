import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/player/mini_player.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/transcoding/transcoding_service.dart';

const _cellular = TranscodeParameters(
  maxBitRate: 256,
  format: 'opus',
  quality: StreamQuality.kbps256,
  isTranscoded: true,
);

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
                  cachedFormat: 'flac',
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

  // The badge describes what is playing. A download that finished after the
  // track started streaming does not play until the next time it comes up.
  testWidgets(
    'MiniPlayer shows the stream, not the badge, for a song downloaded mid-play',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: true,
                  activeTranscode: _cellular,
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

      expect(find.byIcon(Icons.offline_pin), findsNothing);
      expect(find.textContaining('OPUS 256k'), findsOneWidget);
    },
  );

  testWidgets(
    'MiniPlayer shows a downloaded song as its file, not the stream',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: true,
                  activeTranscode: _cellular,
                  cachedFormat: 'flac',
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
      expect(find.textContaining('FLAC 1411k'), findsOneWidget);
      expect(find.textContaining('OPUS'), findsNothing);
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
                const PlayerState(currentSong: testSong, isPlaying: true),
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

  testWidgets('MiniPlayer displays format badge and bitrate when active', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(
            (ref) => MockPlayerNotifier(
              const PlayerState(currentSong: testSong, isPlaying: true),
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

    expect(find.textContaining('FLAC 1411k'), findsOneWidget);
  });

  testWidgets(
    'MiniPlayer displays playbackError when player state has an error',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(
              (ref) => MockPlayerNotifier(
                const PlayerState(
                  currentSong: testSong,
                  isPlaying: false,
                  playbackError: 'Connection refused',
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

      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.textContaining('FLAC'), findsNothing);
    },
  );
}

class MockPlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  MockPlayerNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
