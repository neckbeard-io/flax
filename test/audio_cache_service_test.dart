import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/database/mappers.dart';
import 'package:flax/services/database/tables/orderings.dart';

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
      expect(config.rollingCacheLimitMb, equals(2048));
      expect(config.autoCacheStreamed, isFalse);
      expect(config.offlineOnlyMode, isFalse);
    });

    test('copyWith updates specific fields', () {
      const config = AudioCacheConfig();
      final updated = config.copyWith(
        rollingCacheLimitMb: 5120,
        autoCacheStreamed: true,
      );
      expect(updated.rollingCacheLimitMb, equals(5120));
      expect(updated.autoCacheStreamed, isTrue);
      expect(updated.offlineOnlyMode, isFalse);
    });
  });

  group('LibraryDao Offline Downloads', () {
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

      // Download song1
      await dao.updateSongDownload(
        serverId,
        song1.id,
        localPath: '/tmp/music/s-1.mp3',
        state: DownloadState.complete,
      );

      final downloadedSongIds = await dao
          .watchDownloadedSongIds(serverId)
          .first;
      expect(downloadedSongIds, contains('s-1'));
      expect(downloadedSongIds, isNot(contains('s-2')));

      // Album is cached because at least one song is complete
      final downloadedAlbumIds = await dao
          .watchDownloadedAlbumIds(serverId)
          .first;
      expect(downloadedAlbumIds, contains('alb-1'));

      // Artist is cached
      final downloadedArtistIds = await dao
          .watchDownloadedArtistIds(serverId)
          .first;
      expect(downloadedArtistIds, contains('art-1'));

      // Server refresh preserves localPath and downloadState
      await dao.upsertSongs([song1], now);
      final preservedSong = await dao.watchSong(serverId, song1.id).first;
      expect(preservedSong?.localPath, equals('/tmp/music/s-1.mp3'));
      expect(preservedSong?.downloadState, equals(DownloadState.complete));

      // Clear all downloads
      await dao.clearAllSongDownloads(serverId);
      expect(await dao.watchDownloadedSongIds(serverId).first, isEmpty);
      expect(await dao.watchDownloadedAlbumIds(serverId).first, isEmpty);
      expect(await dao.watchDownloadedArtistIds(serverId).first, isEmpty);
    });
  });
}
