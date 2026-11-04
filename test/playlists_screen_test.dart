import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/playlist_detail_screen.dart';
import 'package:flax/features/library/playlists_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/album_group_header.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

class _Repo extends Fake implements LibraryRepository {
  _Repo({
    this.stored = const [],
    this.downloaded = const [],
    this.storedSongs = const [],
    this.downloadedSongs = const [],
    Set<String>? fullyCached,
  }) : fullyCached = fullyCached ?? const {};

  final List<Playlist> stored;
  final List<Playlist> downloaded;
  final List<Song> storedSongs;
  final List<Song> downloadedSongs;
  final Set<String> fullyCached;

  int listRefreshes = 0;
  int playlistRefreshes = 0;

  /// Left unset, a refresh hangs, as one in flight does.
  Completer<void> refresh = Completer<void>();

  @override
  Stream<List<Playlist>> watchPlaylists() => Stream.value(stored);

  @override
  Stream<List<Playlist>> watchDownloadedPlaylists() => Stream.value(downloaded);

  @override
  Stream<Playlist?> watchPlaylist(String playlistId) => Stream.value(
    [...stored, ...downloaded].where((p) => p.id == playlistId).firstOrNull,
  );

  @override
  Stream<List<Song>> watchPlaylistSongs(String playlistId) =>
      Stream.value(storedSongs);

  @override
  Stream<List<Song>> watchDownloadedPlaylistSongs(String playlistId) =>
      Stream.value(downloadedSongs);

  @override
  Stream<Set<String>> watchDownloadedPlaylistIds() => Stream.value(fullyCached);

  @override
  Stream<Set<String>> watchDownloadedSongIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchDownloadingSongIds() => Stream.value(const {});

  @override
  Future<void> refreshPlaylists() {
    listRefreshes++;
    return refresh.future;
  }

  @override
  Future<void> refreshPlaylist(String playlistId) {
    playlistRefreshes++;
    return refresh.future;
  }
}

class _Player extends StateNotifier<PlayerState> implements PlayerNotifier {
  _Player() : super(const PlayerState());

  List<Song>? queue;
  int? index;

  @override
  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    this.queue = queue;
    this.index = index;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _long = Playlist(
  id: 'p1',
  serverId: 'srv',
  name: 'A very long playlist name that cannot fit on one line of a phone',
  songCount: 3,
  duration: 61763,
);

const _short = Playlist(id: 'p2', serverId: 'srv', name: 'Road trip');

const _songs = [
  Song(
    id: 's1',
    serverId: 'srv',
    albumId: 'a1',
    albumName: 'Album One',
    title: 'First',
    artistName: 'Artist A',
    track: 4,
    duration: 100,
    year: 2021,
  ),
  Song(
    id: 's2',
    serverId: 'srv',
    albumId: 'a1',
    albumName: 'Album One',
    title: 'Second',
    artistName: 'Artist A',
    track: 5,
    duration: 200,
    year: 2021,
  ),
  Song(
    id: 's3',
    serverId: 'srv',
    albumId: 'a2',
    albumName: 'Album Two',
    title: 'Third',
    artistName: 'Artist B',
    track: 1,
    duration: 250,
  ),
  Song(
    id: 's1',
    serverId: 'srv',
    albumId: 'a1',
    albumName: 'Album One',
    title: 'First',
    artistName: 'Artist A',
    track: 4,
    duration: 100,
    year: 2021,
  ),
];

Widget _app(
  Widget home, {
  required LibraryRepository repo,
  bool offline = false,
  Locale locale = const Locale('en'),
  _Player? player,
}) {
  return ProviderScope(
    overrides: [
      libraryRepositoryProvider.overrideWithValue(repo),
      isOfflineModeProvider.overrideWithValue(offline),
      playerProvider.overrideWith((ref) => player ?? _Player()),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void _phone(WidgetTester tester, {ui.Size size = const ui.Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('playlistsProvider', () {
    ProviderContainer container(_Repo repo, {required bool offline}) {
      final c = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
          isOfflineModeProvider.overrideWithValue(offline),
        ],
      );
      addTearDown(c.dispose);
      c.listen(playlistsProvider, (_, _) {});
      return c;
    }

    test(
      'online draws what is stored without waiting, and refreshes',
      () async {
        final repo = _Repo(stored: const [_short]);
        final c = container(repo, offline: false);

        expect(await c.read(playlistsProvider.future), [_short]);
        expect(repo.listRefreshes, 1);
      },
    );

    test('online with nothing stored waits for the first fetch', () async {
      final repo = _Repo();
      final c = container(repo, offline: false);
      await pumpEventQueue();

      expect(c.read(playlistsProvider).isLoading, isTrue);

      repo.refresh.complete();
      expect(await c.read(playlistsProvider.future), isEmpty);
    });

    test(
      'offline lists only cached playlists and asks the server nothing',
      () async {
        final repo = _Repo(
          stored: const [_short, _long],
          downloaded: const [_long],
        );
        final c = container(repo, offline: true);

        expect(await c.read(playlistsProvider.future), [_long]);
        expect(repo.listRefreshes, 0);
      },
    );
  });

  group('playlistSongsProvider', () {
    test(
      'offline gives only downloaded tracks and asks the server nothing',
      () async {
        final repo = _Repo(
          storedSongs: _songs,
          downloadedSongs: const [
            Song(id: 's2', serverId: 'srv', title: 'Second'),
          ],
        );
        final c = ProviderContainer(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            isOfflineModeProvider.overrideWithValue(true),
          ],
        );
        addTearDown(c.dispose);
        c.listen(playlistSongsProvider('p1'), (_, _) {});

        final songs = await c.read(playlistSongsProvider('p1').future);
        expect(songs.map((s) => s.id), ['s2']);
        expect(repo.playlistRefreshes, 0);
      },
    );

    test('online refreshes on open', () async {
      final repo = _Repo(storedSongs: _songs);
      final c = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
          isOfflineModeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      c.listen(playlistSongsProvider('p1'), (_, _) {});

      expect(await c.read(playlistSongsProvider('p1').future), hasLength(4));
      expect(repo.playlistRefreshes, 1);
    });
  });

  group('the list screen', () {
    testWidgets('fits a phone, long names included', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          const PlaylistsScreen(),
          repo: _Repo(stored: const [_long, _short], fullyCached: const {'p1'}),
        ),
      );
      await tester.pump();

      expect(find.textContaining('A very long playlist'), findsOneWidget);
      expect(find.text('Road trip'), findsOneWidget);
      expect(find.textContaining('3 tracks'), findsOneWidget);
      // Only the fully cached one is marked.
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    });

    testWidgets('says when the server has none', (tester) async {
      _phone(tester);
      final repo = _Repo()..refresh.complete();
      await tester.pumpWidget(_app(const PlaylistsScreen(), repo: repo));
      await tester.pump();
      await tester.pump();

      expect(find.text('No playlists on this server'), findsOneWidget);
    });

    testWidgets('says when offline with none cached', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(const PlaylistsScreen(), repo: _Repo(), offline: true),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No playlists cached for offline use'), findsOneWidget);
    });
  });

  group('the playlist screen', () {
    Future<void> open(
      WidgetTester tester,
      _Repo repo, {
      bool offline = false,
      Locale locale = const Locale('en'),
      _Player? player,
      ui.Size size = const ui.Size(390, 844),
    }) async {
      _phone(tester, size: size);
      await tester.pumpWidget(
        _app(
          const PlaylistDetailScreen(playlistId: 'p1'),
          repo: repo,
          offline: offline,
          locale: locale,
          player: player,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('fits a phone, in the longest language', (tester) async {
      await open(
        tester,
        _Repo(stored: const [_long], storedSongs: _songs),
        locale: const Locale('de'),
        size: const ui.Size(360, 800),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Als Nächstes'), findsOneWidget);
      expect(tester.getRect(find.text('Als Letztes')).right, lessThan(360));
    });

    testWidgets('breaks wherever the album changes, as the queue does', (
      tester,
    ) async {
      // Tall enough that the list builds every row.
      await open(
        tester,
        _Repo(stored: const [_long], storedSongs: _songs),
        size: const ui.Size(390, 1400),
      );

      // One, Two, then One again: a repeat keeps its place in the playlist.
      expect(find.byType(AlbumGroupHeader), findsNWidgets(3));
      expect(find.text('Album One'), findsNWidgets(2));
      expect(find.text('Album Two'), findsOneWidget);
      expect(find.text('2021'), findsNWidgets(2));
      // The first break covers its two tracks: 100s + 200s.
      expect(find.text('0:05:00'), findsOneWidget);
      // Tracks keep their numbers on their albums.
      expect(find.text('4'), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('fits the desktop table too', (tester) async {
      await open(
        tester,
        _Repo(stored: const [_long], storedSongs: _songs),
        size: const ui.Size(1400, 900),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AlbumGroupHeader), findsNWidgets(3));

      // The length and year sit under the artist, not out at the right edge.
      final details = find.text('2021 · 0:05:00');
      final artist = find.text('Artist A').first;
      expect(tester.getTopLeft(details).dx, tester.getTopLeft(artist).dx);
      expect(
        tester.getTopLeft(details).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(artist).dy),
      );
      expect(find.text('2021'), findsNothing);

      // A track with no year just shows its length.
      expect(find.text('0:04:10'), findsOneWidget);

      // Larger art than the queue's 32px.
      final cover = find.descendant(
        of: find.byType(AlbumGroupHeader).first,
        matching: find.byType(CoverArtImage),
      );
      expect(tester.getSize(cover), const Size(64, 64));
    });

    testWidgets('Play queues the whole playlist from the top', (tester) async {
      final player = _Player();
      await open(
        tester,
        _Repo(stored: const [_long], storedSongs: _songs),
        player: player,
      );

      await tester.tap(find.text('Play'));
      await tester.pump();

      expect(player.queue, _songs);
      expect(player.index, 0);
    });

    testWidgets('a track queues the whole playlist from there', (tester) async {
      final player = _Player();
      await open(
        tester,
        _Repo(stored: const [_long], storedSongs: _songs),
        player: player,
      );

      await tester.tap(find.text('Second'));
      await tester.pump();

      expect(player.queue, _songs);
      expect(player.index, 1);

      // Past the first break: still its place in the whole playlist.
      await tester.tap(find.text('Third'));
      await tester.pump();

      expect(player.queue, _songs);
      expect(player.index, 2);
    });

    testWidgets('offline shows no way to download', (tester) async {
      await open(
        tester,
        _Repo(
          downloaded: const [_long],
          downloadedSongs: const [
            Song(id: 's2', serverId: 'srv', title: 'Second'),
          ],
        ),
        offline: true,
      );

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byIcon(Icons.download_for_offline_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('online and uncached offers the download', (tester) async {
      await open(tester, _Repo(stored: const [_long], storedSongs: _songs));

      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('fully cached offers removal only', (tester) async {
      await open(
        tester,
        _Repo(
          stored: const [_long],
          downloaded: const [_long],
          storedSongs: _songs,
          fullyCached: const {'p1'},
        ),
      );

      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('says when the playlist no longer exists', (tester) async {
      final repo = _Repo()..refresh.complete();
      await open(tester, repo, size: const ui.Size(1400, 900));

      expect(find.text('Playlist not found'), findsOneWidget);
    });
  });
}
