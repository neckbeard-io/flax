import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/search/search_screen.dart';

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier() : super(const PlayerState());

  Song? lastPlayedSong;
  List<Song>? lastPlayedQueue;
  int? lastPlayedIndex;

  @override
  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    lastPlayedSong = song;
    lastPlayedQueue = queue;
    lastPlayedIndex = index;
    final newQueue = queue ?? [song];
    state = state.copyWith(
      queue: newQueue,
      queueIndex: index ?? 0,
      currentSong: song,
      isPlaying: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping a search result song only queues that single song', (
    tester,
  ) async {
    final fakePlayer = _FakePlayerNotifier();

    const song1 = Song(
      id: 's1',
      serverId: 'srv',
      albumId: 'a1',
      title: 'Song One',
      artistName: 'Artist A',
      albumName: 'Album A',
    );
    const song2 = Song(
      id: 's2',
      serverId: 'srv',
      albumId: 'a1',
      title: 'Song Two',
      artistName: 'Artist A',
      albumName: 'Album A',
    );

    final searchResult = SearchResult(
      artists: const [],
      albums: const [],
      songs: const [song1, song2],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith((ref) => fakePlayer),
          searchResultsProvider.overrideWith(
            (ref) => Stream.value(searchResult),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SearchScreen(initialQuery: 'test')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Song One'), findsOneWidget);
    expect(find.text('Song Two'), findsOneWidget);

    // Tap the first song
    await tester.tap(find.text('Song One'));
    await tester.pump();

    expect(fakePlayer.lastPlayedSong, song1);
    expect(fakePlayer.lastPlayedQueue, isNull); // Queue should not be passed
    expect(fakePlayer.state.queue, [song1]); // Queue should only contain song1
  });
}
