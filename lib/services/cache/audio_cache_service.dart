import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/art_cache.dart';

/// Configuration for the audio cache and offline storage.
class AudioCacheConfig {
  final int rollingCacheLimitMb;
  final bool autoCacheStreamed;
  final bool offlineOnlyMode;

  const AudioCacheConfig({
    this.rollingCacheLimitMb = 2048,
    this.autoCacheStreamed = false,
    this.offlineOnlyMode = false,
  });

  AudioCacheConfig copyWith({
    int? rollingCacheLimitMb,
    bool? autoCacheStreamed,
    bool? offlineOnlyMode,
  }) {
    return AudioCacheConfig(
      rollingCacheLimitMb: rollingCacheLimitMb ?? this.rollingCacheLimitMb,
      autoCacheStreamed: autoCacheStreamed ?? this.autoCacheStreamed,
      offlineOnlyMode: offlineOnlyMode ?? this.offlineOnlyMode,
    );
  }
}

class AudioCacheConfigNotifier extends StateNotifier<AudioCacheConfig> {
  static const _limitKey = 'flax_rolling_cache_limit_mb';
  static const _autoCacheKey = 'flax_auto_cache_streamed';
  static const _offlineOnlyKey = 'flax_offline_only_mode';

  AudioCacheConfigNotifier() : super(const AudioCacheConfig()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AudioCacheConfig(
        rollingCacheLimitMb: prefs.getInt(_limitKey) ?? 2048,
        autoCacheStreamed: prefs.getBool(_autoCacheKey) ?? false,
        offlineOnlyMode: prefs.getBool(_offlineOnlyKey) ?? false,
      );
    } catch (_) {}
  }

  Future<void> setRollingCacheLimitMb(int limitMb) async {
    state = state.copyWith(rollingCacheLimitMb: limitMb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitKey, limitMb);
  }

  Future<void> setAutoCacheStreamed(bool enabled) async {
    state = state.copyWith(autoCacheStreamed: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCacheKey, enabled);
  }

  Future<void> setOfflineOnlyMode(bool offlineOnly) async {
    state = state.copyWith(offlineOnlyMode: offlineOnly);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineOnlyKey, offlineOnly);
  }
}

final audioCacheConfigProvider =
    StateNotifierProvider<AudioCacheConfigNotifier, AudioCacheConfig>((ref) {
      return AudioCacheConfigNotifier();
    });

final audioCacheServiceProvider = Provider<AudioCacheService>((ref) {
  return AudioCacheService(ref);
});

/// Audio caching and offline synchronization service.
class AudioCacheService {
  final Ref _ref;
  final Dio _dio;

  AudioCacheService(this._ref, {Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  Future<Directory> _getBaseDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'audio_cache'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getMusicDir(
    String serverId, {
    required bool isPinned,
  }) async {
    final base = await _getBaseDir();
    final sub = isPinned ? 'offline' : 'rolling';
    final dir = Directory(p.join(base.path, 'music', sub, serverId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getLyricsDir(String serverId) async {
    final base = await _getBaseDir();
    final dir = Directory(p.join(base.path, 'lyrics', serverId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Downloads and caches a single song's audio file and cascades metadata/lyrics.
  Future<String?> cacheSong(Song song, {bool isPinned = true}) async {
    final client = _ref.read(subsonicClientProvider);
    final dao = _ref.read(libraryDaoProvider);
    final repo = _ref.read(libraryRepositoryProvider);
    if (client == null || repo == null) return null;

    final serverId = song.serverId;
    final ext = song.suffix?.isNotEmpty == true ? song.suffix! : 'mp3';
    final musicDir = await _getMusicDir(serverId, isPinned: isPinned);
    final destFile = File(p.join(musicDir.path, '${song.id}.$ext'));

    try {
      // Mark as downloading
      await dao.updateSongDownload(
        serverId,
        song.id,
        localPath: destFile.path,
        state: DownloadState.downloading,
      );

      if (!destFile.existsSync() || destFile.lengthSync() == 0) {
        final streamUri = client.getStreamUri(song.id);
        final tempFile = File('${destFile.path}.tmp');

        await _dio.download(
          streamUri.toString(),
          tempFile.path,
          options: Options(responseType: ResponseType.bytes),
        );

        if (tempFile.existsSync()) {
          if (destFile.existsSync()) destFile.deleteSync();
          await tempFile.rename(destFile.path);
        }
      }

      // Mark as complete in database
      await dao.updateSongDownload(
        serverId,
        song.id,
        localPath: destFile.path,
        state: DownloadState.complete,
      );

      // Cascade: Lyrics
      _cacheLyrics(client, serverId, song);

      // Cascade: Cover Art & Metadata
      if (song.coverArtId != null) {
        final coverUri = client.getCoverArtUri(song.coverArtId!);
        ArtCache.instance.downloadFile(coverUri.toString()).catchError((_) {});
      }

      if (song.albumId != null) {
        repo.refreshAlbum(song.albumId!).catchError((_) {});
      }
      if (song.artistId != null) {
        repo.refreshArtist(song.artistId!).catchError((_) {});
      }

      // If rolling cache, check size limit and evict if needed
      if (!isPinned) {
        _enforceRollingCacheLimit(serverId);
      }

      return destFile.path;
    } catch (e) {
      developer.log(
        'Failed to cache song ${song.id}: $e',
        name: 'AudioCacheService',
      );
      await dao.updateSongDownload(
        serverId,
        song.id,
        localPath: null,
        state: DownloadState.error,
      );
      return null;
    }
  }

  Future<void> _cacheLyrics(
    SubsonicClient client,
    String serverId,
    Song song,
  ) async {
    try {
      final lyricsDir = await _getLyricsDir(serverId);
      final lrcFile = File(p.join(lyricsDir.path, '${song.id}.lrc'));
      if (lrcFile.existsSync()) return;

      final structured = await client.getSongLyrics(song.id);
      if (structured != null && structured.lines.isNotEmpty) {
        final buffer = StringBuffer();
        for (final line in structured.lines) {
          final ms = line.start?.inMilliseconds ?? 0;
          final min = (ms ~/ 60000).toString().padLeft(2, '0');
          final sec = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
          final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
          buffer.writeln('[$min:$sec.$hundredths]${line.text}');
        }
        await lrcFile.writeAsString(buffer.toString());
      } else if (song.artistName != null && song.title.isNotEmpty) {
        final plain = await client.getLyrics(
          artist: song.artistName,
          title: song.title,
        );
        if (plain != null && plain.isNotEmpty) {
          await lrcFile.writeAsString(plain);
        }
      }
    } catch (_) {}
  }

  /// Caches all songs in an album.
  Future<void> cacheAlbum(String albumId, {bool isPinned = true}) async {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    var songs = await repo.watchAlbumSongs(albumId).first;
    if (songs.isEmpty) {
      await repo.refreshAlbum(albumId);
      songs = await repo.watchAlbumSongs(albumId).first;
    }

    for (final song in songs) {
      await cacheSong(song, isPinned: isPinned);
    }
  }

  /// Caches all albums and songs for an artist.
  Future<void> cacheArtist(String artistId, {bool isPinned = true}) async {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    var albums = await repo.watchArtistAlbums(artistId).first;
    if (albums.isEmpty) {
      await repo.refreshArtist(artistId);
      albums = await repo.watchArtistAlbums(artistId).first;
    }

    for (final album in albums) {
      await cacheAlbum(album.id, isPinned: isPinned);
    }
  }

  /// Removes a song from offline cache.
  Future<void> removeCachedSong(String songId) async {
    final dao = _ref.read(libraryDaoProvider);
    final server = _ref.read(activeServerProvider);
    if (server == null) return;

    final song = await dao.watchSong(server.id, songId).first;
    if (song?.localPath != null) {
      final file = File(song!.localPath!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }

    final lyricsDir = await _getLyricsDir(server.id);
    final lrcFile = File(p.join(lyricsDir.path, '$songId.lrc'));
    if (lrcFile.existsSync()) {
      try {
        lrcFile.deleteSync();
      } catch (_) {}
    }

    await dao.updateSongDownload(
      server.id,
      songId,
      localPath: null,
      state: DownloadState.none,
    );
  }

  /// Removes all songs belonging to an album from cache.
  Future<void> removeCachedAlbum(String albumId) async {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    final songs = await repo.watchAlbumSongs(albumId).first;
    for (final song in songs) {
      await removeCachedSong(song.id);
    }
  }

  /// Removes all songs by an artist from cache.
  Future<void> removeCachedArtist(String artistId) async {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    final albums = await repo.watchArtistAlbums(artistId).first;
    for (final album in albums) {
      await removeCachedAlbum(album.id);
    }
  }

  /// Purges audio cache files.
  Future<void> clearAudioCache({bool keepPinned = false}) async {
    final server = _ref.read(activeServerProvider);
    final dao = _ref.read(libraryDaoProvider);
    if (server == null) return;

    final base = await _getBaseDir();
    final rollingDir = Directory(
      p.join(base.path, 'music', 'rolling', server.id),
    );
    if (rollingDir.existsSync()) {
      try {
        rollingDir.deleteSync(recursive: true);
      } catch (_) {}
    }

    if (!keepPinned) {
      final offlineDir = Directory(
        p.join(base.path, 'music', 'offline', server.id),
      );
      if (offlineDir.existsSync()) {
        try {
          offlineDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      await dao.clearAllSongDownloads(server.id);
    }
  }

  /// Purges metadata and artwork caches.
  Future<void> clearMetadataAndArtworkCache() async {
    await ArtCache.instance.emptyCache();
  }

  /// Returns total audio cache size in bytes.
  Future<int> getAudioCacheBytes() async {
    final base = await _getBaseDir();
    if (!base.existsSync()) return 0;
    return _calculateDirSize(base);
  }

  /// Returns rolling cache size in bytes.
  Future<int> getRollingCacheBytes() async {
    final server = _ref.read(activeServerProvider);
    if (server == null) return 0;
    final base = await _getBaseDir();
    final dir = Directory(p.join(base.path, 'music', 'rolling', server.id));
    if (!dir.existsSync()) return 0;
    return _calculateDirSize(dir);
  }

  /// Returns pinned offline cache size in bytes.
  Future<int> getOfflinePinnedBytes() async {
    final server = _ref.read(activeServerProvider);
    if (server == null) return 0;
    final base = await _getBaseDir();
    final dir = Directory(p.join(base.path, 'music', 'offline', server.id));
    if (!dir.existsSync()) return 0;
    return _calculateDirSize(dir);
  }

  int _calculateDirSize(Directory dir) {
    var total = 0;
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _enforceRollingCacheLimit(String serverId) async {
    final config = _ref.read(audioCacheConfigProvider);
    if (config.rollingCacheLimitMb <= 0) return; // 0 = unlimited

    final maxBytes = config.rollingCacheLimitMb * 1024 * 1024;
    final base = await _getBaseDir();
    final rollingDir = Directory(
      p.join(base.path, 'music', 'rolling', serverId),
    );
    if (!rollingDir.existsSync()) return;

    final files = <File>[];
    for (final entity in rollingDir.listSync()) {
      if (entity is File) files.add(entity);
    }

    // Sort oldest modified first (LRU)
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    var currentBytes = _calculateDirSize(rollingDir);
    for (final file in files) {
      if (currentBytes <= maxBytes) break;
      final size = file.lengthSync();
      final songId = p.basenameWithoutExtension(file.path);
      try {
        file.deleteSync();
        currentBytes -= size;
        _ref
            .read(libraryDaoProvider)
            .updateSongDownload(
              serverId,
              songId,
              localPath: null,
              state: DownloadState.none,
            );
      } catch (_) {}
    }
  }

  /// Resolves local cached lyrics if available.
  Future<String?> getCachedLyricsString(String songId) async {
    final server = _ref.read(activeServerProvider);
    if (server == null) return null;
    final lyricsDir = await _getLyricsDir(server.id);
    final lrcFile = File(p.join(lyricsDir.path, '$songId.lrc'));
    if (lrcFile.existsSync()) {
      try {
        return await lrcFile.readAsString();
      } catch (_) {}
    }
    return null;
  }
}
