import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/cache/storage_manager.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lyrics LRC Parser', () {
    test('parses standard LRC timestamps correctly', () {
      const lrc = '''
[00:12.34]First line of the song
[01:05.67]Second line after a minute
[02:30.00]Final line
''';
      final lyrics = Lyrics.fromLrcText(lrc);
      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isTrue);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].text, equals('First line of the song'));
      expect(
        lyrics.lines[0].start,
        equals(const Duration(seconds: 12, milliseconds: 340)),
      );
      expect(lyrics.lines[1].text, equals('Second line after a minute'));
      expect(
        lyrics.lines[1].start,
        equals(const Duration(minutes: 1, seconds: 5, milliseconds: 670)),
      );
      expect(lyrics.lines[2].text, equals('Final line'));
      expect(
        lyrics.lines[2].start,
        equals(const Duration(minutes: 2, seconds: 30)),
      );
    });

    test('falls back to plain text when no timestamps present', () {
      const plain = '''
Just some lyrics
Without timestamps
At all
''';
      final lyrics = Lyrics.fromLrcText(plain);
      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isFalse);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].text, equals('Just some lyrics'));
      expect(lyrics.lines[0].start, isNull);
    });
  });

  group('AudioCacheConfig', () {
    test('default configuration values', () {
      const config = AudioCacheConfig();
      expect(config.rollingCacheLimitMb, equals(5120));
      expect(config.rollingCacheLimitGb, equals(5));
      expect(config.limitDisplayString, equals('5 GB'));
      expect(config.autoCacheStreamed, isTrue);
      expect(config.offlineOnlyMode, isFalse);
      expect(config.downloadConcurrency, equals(4));
      expect(config.storageLocationId, equals('internal_app'));
    });

    test('copyWith and custom GB limits', () {
      const config = AudioCacheConfig();
      final updated = config.copyWith(
        rollingCacheLimitMb: 10240,
        autoCacheStreamed: false,
        downloadConcurrency: 4,
        storageLocationId: 'external_0',
        storageLocationPath: '/storage/1234-5678/music',
      );
      expect(updated.rollingCacheLimitMb, equals(10240));
      expect(updated.rollingCacheLimitGb, equals(10));
      expect(updated.limitDisplayString, equals('10 GB'));
      expect(updated.autoCacheStreamed, isFalse);
      expect(updated.downloadConcurrency, equals(4));
      expect(updated.storageLocationId, equals('external_0'));
      expect(updated.storageLocationPath, equals('/storage/1234-5678/music'));

      final unlimited = config.copyWith(rollingCacheLimitMb: 0);
      expect(unlimited.rollingCacheLimitGb, equals(0));
      expect(unlimited.limitDisplayString, equals('Unlimited'));
    });
  });

  group('StorageManager', () {
    test('queries native disk space on current platform', () {
      final diskInfo = StorageManager.getDiskSpace(Directory.current.path);
      if (diskInfo != null) {
        expect(diskInfo.totalBytes, greaterThan(0));
        expect(diskInfo.availableBytes, greaterThan(0));
        expect(diskInfo.freeFraction, greaterThan(0.0));
        expect(diskInfo.freeFraction, lessThanOrEqualTo(1.0));
      }
    });

    test('isDiskSpaceSafe reports safe when buffer is met', () {
      final isSafe = StorageManager.isDiskSpaceSafe(
        Directory.current.path,
        additionalBytes: 1024,
      );
      expect(isSafe, isTrue);
    });

    test('migrates cache directory contents cleanly', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flax_test_storage_',
      );
      try {
        final srcDir = Directory(p.join(tempDir.path, 'source'));
        final dstDir = Directory(p.join(tempDir.path, 'destination'));
        await srcDir.create(recursive: true);

        // Create dummy track files
        final track1 = File(
          p.join(srcDir.path, 'music', 'offline', 'srv1', 'song1.mp3'),
        );
        await track1.parent.create(recursive: true);
        await track1.writeAsString('track 1 dummy audio data');

        final lyrics1 = File(
          p.join(srcDir.path, 'lyrics', 'srv1', 'song1.lrc'),
        );
        await lyrics1.parent.create(recursive: true);
        await lyrics1.writeAsString('[00:01.00]test lyrics');

        var progressCalls = 0;
        final success = await StorageManager.migrateCacheDirectory(
          sourcePath: srcDir.path,
          targetPath: dstDir.path,
          onProgress: (fraction, status) {
            progressCalls++;
          },
        );

        expect(success, isTrue);
        expect(progressCalls, greaterThan(0));

        // Destination has files
        final destTrack = File(
          p.join(dstDir.path, 'music', 'offline', 'srv1', 'song1.mp3'),
        );
        expect(destTrack.existsSync(), isTrue);
        expect(
          await destTrack.readAsString(),
          equals('track 1 dummy audio data'),
        );

        final destLyrics = File(
          p.join(dstDir.path, 'lyrics', 'srv1', 'song1.lrc'),
        );
        expect(destLyrics.existsSync(), isTrue);
        expect(
          await destLyrics.readAsString(),
          equals('[00:01.00]test lyrics'),
        );

        // Source is cleared
        expect(track1.existsSync(), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('LibraryDao Offline Downloads & Migration', () {
    late FlaxDatabase db;
    late LibraryDao dao;
    late DateTime now;
    const serverId = 'srv-test-1';

    setUp(() {
      now = DateTime.utc(2026, 8, 19, 12);
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('updates song download state and watches downloaded ids', () async {
      const artist = Artist(
        id: 'art-1',
        serverId: serverId,
        name: 'Iron Maiden',
        albumCount: 1,
      );
      const album = Album(
        id: 'alb-1',
        serverId: serverId,
        name: 'Powerslave',
        artistId: 'art-1',
        artistName: 'Iron Maiden',
        songCount: 2,
        duration: 600,
      );
      const song1 = Song(
        id: 's-1',
        serverId: serverId,
        albumId: 'alb-1',
        artistId: 'art-1',
        title: 'Aces High',
        duration: 271,
      );
      const song2 = Song(
        id: 's-2',
        serverId: serverId,
        albumId: 'alb-1',
        artistId: 'art-1',
        title: '2 Minutes to Midnight',
        duration: 359,
      );

      await dao.upsertArtists([artist], now);
      await dao.upsertAlbums([album], now);
      await dao.upsertSongs([song1, song2], now);

      // Initially no songs are downloaded
      expect(await dao.watchDownloadedSongIds(serverId).first, isEmpty);
      expect(await dao.watchDownloadedAlbumIds(serverId).first, isEmpty);
      expect(await dao.watchDownloadedArtistIds(serverId).first, isEmpty);

      // Download song1 only (song2 is not complete yet)
      await dao.updateSongDownload(
        serverId,
        song1.id,
        localPath: '/tmp/music/offline/s-1.mp3',
        state: DownloadState.complete,
      );

      final downloadedSongIds = await dao
          .watchDownloadedSongIds(serverId)
          .first;
      expect(downloadedSongIds, contains('s-1'));
      expect(downloadedSongIds, isNot(contains('s-2')));

      // Download song2 as well
      await dao.updateSongDownload(
        serverId,
        song2.id,
        localPath: '/tmp/music/offline/s-2.mp3',
        state: DownloadState.complete,
      );

      // Now both Album and Artist are cached
      final downloadedAlbumIds = await dao
          .watchDownloadedAlbumIds(serverId)
          .first;
      expect(downloadedAlbumIds, contains('alb-1'));

      final downloadedArtistIds = await dao
          .watchDownloadedArtistIds(serverId)
          .first;
      expect(downloadedArtistIds, contains('art-1'));

      // Test path migration
      await dao.migrateLocalPaths('/tmp/music', '/sdcard/flax_cache');
      final migratedSong1 = await dao.watchSong(serverId, song1.id).first;
      expect(
        migratedSong1?.localPath,
        equals('/sdcard/flax_cache/offline/s-1.mp3'),
      );

      // Clear all downloads
      await dao.clearAllSongDownloads(serverId);
      expect(await dao.watchDownloadedSongIds(serverId).first, isEmpty);
    });
  });

  group('AudioCacheSummary', () {
    test('constructs with defaults and custom properties', () {
      const summary = AudioCacheSummary(
        cachedSongCount: 15,
        audioBytes: 104857600,
      );
      expect(summary.cachedSongCount, equals(15));
      expect(summary.audioBytes, equals(104857600));
    });
  });
}
