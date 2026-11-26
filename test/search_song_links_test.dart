import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/search/search_screen.dart';

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier() : super(const PlayerState());

  Song? lastPlayedSong;

  @override
  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    lastPlayedSong = song;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _song = Song(
  id: 's1',
  serverId: 'srv',
  albumId: 'al1',
  artistId: 'ar1',
  title: 'Song One',
  artistName: 'A Rather Long Artist Name For A Phone Screen',
  albumName: 'An Equally Long Album Title That Will Not Fit',
);

Future<_FakePlayerNotifier> _pump(WidgetTester tester) async {
  final player = _FakePlayerNotifier();
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => const SearchScreen(initialQuery: 'song'),
      ),
      GoRoute(
        path: '/artists/:id',
        builder: (_, state) =>
            Scaffold(body: Text('artist page ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/albums/:id',
        builder: (_, state) =>
            Scaffold(body: Text('album page ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerProvider.overrideWith((ref) => player),
        searchResultsProvider.overrideWith(
          (ref) => Stream.value(
            SearchResult(artists: const [], albums: const [], songs: [_song]),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return player;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping a song result artist opens the artist', (tester) async {
    final player = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('song-artist-link')));
    await tester.pumpAndSettle();

    expect(find.text('artist page ar1'), findsOneWidget);
    expect(player.lastPlayedSong, isNull);
  });

  testWidgets('tapping a song result album opens the album', (tester) async {
    final player = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('song-album-link')));
    await tester.pumpAndSettle();

    expect(find.text('album page al1'), findsOneWidget);
    expect(player.lastPlayedSong, isNull);
  });

  testWidgets('tapping the song title still plays it', (tester) async {
    final player = await _pump(tester);

    await tester.tap(find.text('Song One'));
    await tester.pump();

    expect(player.lastPlayedSong, _song);
    expect(find.text('artist page ar1'), findsNothing);
  });

  testWidgets('song links fit a phone screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester);

    for (final key in ['song-artist-link', 'song-album-link']) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(rect.width, greaterThan(0));
    }
  });
}
