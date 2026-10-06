import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class _Client extends Fake implements SubsonicClient {}

/// Auto-caches are recorded as downloading while they run, the same as a
/// download, and resuming downloads used to pick them up as pinned ones — a
/// track that had only streamed, or that another device had queued, became a
/// download nobody asked for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverId = 'srv-resume';
  late FlaxDatabase db;
  late LibraryDao dao;
  late ProviderContainer container;
  late Directory base;
  late String rolling;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  Song song(String id) => Song(
    id: id,
    serverId: serverId,
    albumId: 'alb-1',
    artistId: 'art-1',
    title: id,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    base = Directory.systemTemp.createTempSync('flax_resume_');
    AudioCacheService.cachedBasePath = base.path;
    rolling = p.join(base.path, 'music', 'rolling', serverId);
    Directory(rolling).createSync(recursive: true);

    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    final now = DateTime.utc(2026, 10, 3);
    await dao.upsertArtists([
      const Artist(id: 'art-1', serverId: serverId, name: 'Disillusion'),
    ], now);
    await dao.upsertAlbums([
      const Album(
        id: 'alb-1',
        serverId: serverId,
        name: 'Ayam',
        artistId: 'art-1',
        artistName: 'Disillusion',
      ),
    ], now);
    await dao.upsertSongs([song('abandoned'), song('running')], now);
    for (final id in ['abandoned', 'running']) {
      await dao.updateSongDownload(
        serverId,
        id,
        localPath: p.join(rolling, '$id.flac'),
        state: DownloadState.downloading,
      );
    }
    File(p.join(rolling, 'abandoned.flac.tmp')).writeAsBytesSync([1, 2, 3]);

    container = ProviderContainer(
      overrides: [
        libraryDaoProvider.overrideWithValue(dao),
        subsonicClientProvider.overrideWithValue(_Client()),
        serverListProvider.overrideWith(
          (ref) => ServerListNotifier(
            initialServers: const [
              Server(
                id: serverId,
                name: 'Home',
                url: 'https://music.example.com',
                username: 'me',
                tokenHash: 'secret',
                salt: '',
                isActive: true,
              ),
            ],
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    AudioCacheService.cachedBasePath = null;
    await db.close();
    base.deleteSync(recursive: true);
  });

  Future<Song?> row(String id) => dao.watchSong(serverId, id).first;

  test('resuming never turns an auto-cache into a download', () async {
    final service = container.read(audioCacheServiceProvider);
    // Still being cached by this process, as when the app comes back to the
    // foreground mid-track.
    service.autoCaching.add('running');

    await service.resumePendingDownloads();

    // Cut off when its process died: cleared, partial file and all.
    final abandoned = await row('abandoned');
    expect(abandoned?.downloadState, DownloadState.none);
    expect(abandoned?.localPath, isNull);
    expect(File(p.join(rolling, 'abandoned.flac.tmp')).existsSync(), isFalse);

    // Still running: left for this process to finish.
    expect((await row('running'))?.downloadState, DownloadState.downloading);
  });

  test('only downloading rows in the rolling cache are auto-caches', () {
    final offline = p.join(base.path, 'music', 'offline', serverId, 'x.flac');
    Song withRow(DownloadState state, String? path) =>
        song('x').copyWith(downloadState: state, localPath: path);

    expect(
      AudioCacheService.isAutoCacheRow(
        withRow(DownloadState.downloading, p.join(rolling, 'x.flac')),
        rolling,
      ),
      isTrue,
    );
    // Pinned downloads: queued, started natively without a path yet, or
    // writing to the offline folder.
    for (final pinned in [
      withRow(DownloadState.queued, p.join(rolling, 'x.flac')),
      withRow(DownloadState.downloading, null),
      withRow(DownloadState.downloading, offline),
    ]) {
      expect(AudioCacheService.isAutoCacheRow(pinned, rolling), isFalse);
    }
  });
}
