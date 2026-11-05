import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/audio/flax_audio_handler.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class _Backend implements MusicBackend {
  List<Playlist> playlists = const [];
  final tracks = <String, List<Song>>{};
  bool fails = false;

  /// While set, the playlist list doesn't answer until this completes.
  Completer<void>? listGate;

  @override
  Future<List<Playlist>> getPlaylists() async {
    await listGate?.future;
    if (fails) throw Exception('server error');
    return playlists;
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    if (fails) throw Exception('server error');
    return playlists.firstWhere((p) => p.id == id);
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    if (fails) throw Exception('server error');
    return tracks[playlistId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Client extends Mock implements SubsonicClient {
  @override
  Future<void> whenTargetChosen() async {}

  @override
  Future<String?> tryPing({Duration? timeout}) async => null;

  @override
  Uri getCoverArtUri(String? id, {int? size}) =>
      Uri.parse('https://music.example.com/rest/getCoverArt?id=$id&size=$size');
}

class _Player extends StateNotifier<PlayerState> implements PlayerNotifier {
  _Player() : super(const PlayerState());

  List<Song>? queue;
  int? index;

  @override
  Future<void> playTracks(List<Song> songs, {int initialIndex = 0}) async {
    queue = songs;
    index = initialIndex;
  }

  @override
  Future<void> waitForRestore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv';
  late FlaxDatabase db;
  late _Backend backend;
  late LibraryRepositoryImpl repo;
  late _Player player;
  late ProviderContainer container;
  late FlaxAudioHandler handler;

  Playlist playlist(String id, {int songCount = 0}) =>
      Playlist(id: id, serverId: sid, name: id, songCount: songCount);

  /// Different albums, so a queue of the track's album can't pass for the
  /// playlist's.
  Song song(String id) =>
      Song(id: id, serverId: sid, albumId: 'album-$id', title: 'Song $id');

  /// A server with [ids] as one playlist's tracks, fetched into the database.
  Future<void> stored(String id, List<String> ids) async {
    backend.playlists = [
      ...backend.playlists.where((p) => p.id != id),
      playlist(id, songCount: ids.length),
    ];
    backend.tracks[id] = ids.map(song).toList();
    await repo.refreshPlaylist(id);
  }

  Future<void> markDownloaded(List<String> ids) async {
    await (db.update(db.songs)..where((t) => t.id.isIn(ids))).write(
      SongsCompanion(
        localPath: const Value('/music/track'),
        downloadState: Value(DownloadState.complete.index),
      ),
    );
  }

  void goOffline() =>
      container.read(offlineManualOverrideProvider.notifier).set(true);

  /// Counts the page reloads Android Auto is told about.
  List<void> reloadsOf(String parent) {
    final reloads = <void>[];
    final sub = handler.subscribeToChildren(parent).listen(reloads.add);
    addTearDown(sub.cancel);
    return reloads;
  }

  /// Lets a refresh running behind a browse finish, database writes included.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FlaxDatabase.memory();
    backend = _Backend();
    repo = LibraryRepositoryImpl(
      LibraryDao(db),
      backend,
      sid,
      clock: () => DateTime.utc(2026, 11, 4),
    );
    player = _Player();
    container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repo),
        subsonicClientProvider.overrideWithValue(_Client()),
        activeServerProvider.overrideWithValue(
          const Server(
            id: sid,
            name: 'Home',
            url: 'https://music.example.com',
            username: 'driver',
            tokenHash: 'tok',
            salt: 'salt',
          ),
        ),
        playerProvider.overrideWith((ref) => player),
      ],
    );
    handler = FlaxAudioHandler(container);
  });

  tearDown(() async {
    await settle();
    container.dispose();
    await db.close();
  });

  group('online, the Playlists tab', () {
    test('lists the server\'s playlists on a first browse', () async {
      backend.playlists = [playlist('Zebra', songCount: 2), playlist('Apple')];

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);

      expect(items.map((e) => e.id), ['playlist_Apple', 'playlist_Zebra']);
      expect(items.every((e) => !e.playable!), isTrue);
    });

    test('lists every playlist, not just the first few', () async {
      backend.playlists = [
        for (var i = 0; i < 120; i++)
          playlist('p${i.toString().padLeft(3, '0')}'),
      ];

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);

      expect(items, hasLength(120));
    });

    test('shows stored playlists at once, and reloads when a refresh changes '
        'them', () async {
      backend.playlists = [playlist('Old')];
      await repo.refreshPlaylists();
      final reloads = reloadsOf(FlaxAudioHandler.kPlaylistsNode);

      backend.playlists = [playlist('Old'), playlist('New')];
      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);
      expect(items.map((e) => e.id), ['playlist_Old']);

      await settle();
      expect(reloads, hasLength(1));
      final reloaded = await handler.getChildren(
        FlaxAudioHandler.kPlaylistsNode,
      );
      expect(reloaded.map((e) => e.id), ['playlist_New', 'playlist_Old']);
    });

    test('doesn\'t reload the page when a refresh changes nothing', () async {
      backend.playlists = [playlist('Same')];
      await repo.refreshPlaylists();
      final reloads = reloadsOf(FlaxAudioHandler.kPlaylistsNode);

      await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);
      await settle();

      expect(reloads, isEmpty);
    });

    test('keeps showing stored playlists when the server fails', () async {
      backend.playlists = [playlist('Kept')];
      await repo.refreshPlaylists();
      backend.fails = true;

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);

      expect(items.map((e) => e.id), ['playlist_Kept']);
    });

    test('gives up waiting on a slow first fetch, then reloads', () async {
      backend.playlists = [playlist('Late')];
      backend.listGate = Completer<void>();
      final reloads = reloadsOf(FlaxAudioHandler.kPlaylistsNode);

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);
      expect(items, isEmpty);

      backend.listGate!.complete();
      await settle();
      expect(reloads, hasLength(1));
      final reloaded = await handler.getChildren(
        FlaxAudioHandler.kPlaylistsNode,
      );
      expect(reloaded.map((e) => e.id), ['playlist_Late']);
    });
  });

  group('online, a playlist\'s page', () {
    test(
      'lists its tracks in playlist order, repeats as separate rows',
      () async {
        await stored('p', ['s2', 's1', 's2']);

        final items = await handler.getChildren('playlist_p');

        expect(items.map((e) => e.extras?['songId']), ['s2', 's1', 's2']);
        expect(items.map((e) => e.id).toSet(), hasLength(3));
        expect(items.every((e) => e.playable!), isTrue);
      },
    );

    test('fetches tracks it has never stored', () async {
      backend.playlists = [playlist('p', songCount: 1)];
      backend.tracks['p'] = [song('s1')];

      final items = await handler.getChildren('playlist_p');

      expect(items.map((e) => e.extras?['songId']), ['s1']);
    });

    test('reloads when the server\'s track list changed', () async {
      await stored('p', ['s1']);
      final reloads = reloadsOf('playlist_p');

      backend.tracks['p'] = [song('s1'), song('s2')];
      final items = await handler.getChildren('playlist_p');
      expect(items, hasLength(1));

      await settle();
      expect(reloads, hasLength(1));
    });
  });

  group('offline', () {
    test('the tab lists only playlists with a downloaded track', () async {
      await stored('Cached', ['s1', 's2']);
      await stored('Remote', ['s3']);
      await markDownloaded(['s1']);
      goOffline();

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);

      expect(items.map((e) => e.id), ['playlist_Cached']);
    });

    test(
      'the tab is empty, with no stand-in, when nothing is cached',
      () async {
        await stored('Remote', ['s1']);
        goOffline();

        final items = await handler.getChildren(
          FlaxAudioHandler.kPlaylistsNode,
        );

        expect(items, isEmpty);
      },
    );

    test(
      'a page has only that playlist\'s downloaded tracks, in order',
      () async {
        await stored('p', ['s3', 's1', 's2', 's1']);
        await stored('other', ['s9']);
        await markDownloaded(['s1', 's3', 's9']);
        goOffline();

        final items = await handler.getChildren('playlist_p');

        expect(items.map((e) => e.extras?['songId']), ['s3', 's1', 's1']);
      },
    );

    test('never asks the server', () async {
      await stored('p', ['s1']);
      await markDownloaded(['s1']);
      backend.playlists = [playlist('p', songCount: 1), playlist('New')];
      goOffline();

      final items = await handler.getChildren(FlaxAudioHandler.kPlaylistsNode);
      await settle();

      expect(items.map((e) => e.id), ['playlist_p']);
      expect((await repo.watchPlaylists().first).map((p) => p.id), ['p']);
    });

    test('tapping a track queues the downloaded tracks from there', () async {
      await stored('p', ['s1', 's2', 's3']);
      await markDownloaded(['s1', 's3']);
      goOffline();

      final items = await handler.getChildren('playlist_p');
      await handler.playFromMediaId(items[1].id);

      expect(player.queue?.map((s) => s.id), ['s1', 's3']);
      expect(player.index, 1);
    });
  });

  group('tapping a track', () {
    test('queues the playlist, not the track\'s album', () async {
      await stored('p', ['s1', 's2', 's3']);

      final items = await handler.getChildren('playlist_p');
      await handler.playFromMediaId(items[1].id);

      expect(player.queue?.map((s) => s.id), ['s1', 's2', 's3']);
      expect(player.index, 1);
      expect(handler.mediaItem.value?.extras?['songId'], 's2');
    });

    test('starts from the repeat that was tapped', () async {
      await stored('p', ['s1', 's2', 's1']);

      final items = await handler.getChildren('playlist_p');
      await handler.playFromMediaId(items[2].id);

      expect(player.queue?.map((s) => s.id), ['s1', 's2', 's1']);
      expect(player.index, 2);
    });

    test('finds the track when the list moved since it was browsed', () async {
      await stored('p', ['s1', 's2', 's3']);
      final items = await handler.getChildren('playlist_p');
      await settle();

      await stored('p', ['s3', 's2']);
      await handler.playFromMediaId(items[2].id);

      expect(player.queue?.map((s) => s.id), ['s3', 's2']);
      expect(player.index, 0);
    });

    test('copes with ids that have separators in them', () async {
      await stored('a/b', ['s/1', 's/2']);

      final items = await handler.getChildren('playlist_a/b');
      await handler.playFromMediaId(items[1].id);

      expect(player.queue?.map((s) => s.id), ['s/1', 's/2']);
      expect(player.index, 1);
    });

    test('a track row resolves to its song', () async {
      await stored('p', ['s1']);

      final items = await handler.getChildren('playlist_p');
      final item = await handler.getMediaItem(items.single.id);

      expect(item?.extras?['songId'], 's1');
    });
  });

  test('playing a whole playlist starts it from the top', () async {
    await stored('p', ['s2', 's1']);

    await handler.playFromMediaId('playlist_p');

    expect(player.queue?.map((s) => s.id), ['s2', 's1']);
    expect(player.index, 0);
  });
}
