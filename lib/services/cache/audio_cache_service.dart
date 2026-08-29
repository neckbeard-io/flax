import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/cache/storage_manager.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/art_cache.dart';

/// Configuration for the audio cache and offline storage.
class AudioCacheConfig {
  final int rollingCacheLimitMb;
  final bool autoCacheStreamed;
  final bool offlineOnlyMode;
  final int downloadConcurrency;
  final String storageLocationId;
  final String? storageLocationPath;

  const AudioCacheConfig({
    this.rollingCacheLimitMb = 5120, // 5 GB default
    this.autoCacheStreamed = true,
    this.offlineOnlyMode = false,
    this.downloadConcurrency = 2,
    this.storageLocationId = 'internal_app',
    this.storageLocationPath,
  });

  int get rollingCacheLimitGb => (rollingCacheLimitMb / 1024).round();

  String get limitDisplayString => rollingCacheLimitMb == 0
      ? 'Unlimited'
      : '${(rollingCacheLimitMb / 1024).toStringAsFixed(rollingCacheLimitMb % 1024 == 0 ? 0 : 1)} GB';

  AudioCacheConfig copyWith({
    int? rollingCacheLimitMb,
    bool? autoCacheStreamed,
    bool? offlineOnlyMode,
    int? downloadConcurrency,
    String? storageLocationId,
    String? storageLocationPath,
  }) {
    return AudioCacheConfig(
      rollingCacheLimitMb: rollingCacheLimitMb ?? this.rollingCacheLimitMb,
      autoCacheStreamed: autoCacheStreamed ?? this.autoCacheStreamed,
      offlineOnlyMode: offlineOnlyMode ?? this.offlineOnlyMode,
      downloadConcurrency: downloadConcurrency ?? this.downloadConcurrency,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      storageLocationPath: storageLocationPath ?? this.storageLocationPath,
    );
  }
}

class AudioCacheConfigNotifier extends StateNotifier<AudioCacheConfig> {
  static const _limitKey = 'flax_rolling_cache_limit_mb';
  static const _autoCacheKey = 'flax_auto_cache_streamed';
  static const _offlineOnlyKey = 'flax_offline_only_mode';
  static const _concurrencyKey = 'flax_audio_download_concurrency';
  static const _locationIdKey = 'flax_audio_cache_volume_id';
  static const _locationPathKey = 'flax_audio_cache_custom_path';

  AudioCacheConfigNotifier() : super(const AudioCacheConfig()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AudioCacheConfig(
        rollingCacheLimitMb: prefs.getInt(_limitKey) ?? 5120,
        autoCacheStreamed: prefs.getBool(_autoCacheKey) ?? true,
        offlineOnlyMode: prefs.getBool(_offlineOnlyKey) ?? false,
        downloadConcurrency: prefs.getInt(_concurrencyKey) ?? 2,
        storageLocationId: prefs.getString(_locationIdKey) ?? 'internal_app',
        storageLocationPath: prefs.getString(_locationPathKey),
      );
    } catch (_) {}
  }

  Future<void> setRollingCacheLimitMb(int limitMb) async {
    state = state.copyWith(rollingCacheLimitMb: limitMb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitKey, limitMb);
  }

  Future<void> setRollingCacheLimitGb(double gb) async {
    final mb = (gb * 1024).round();
    await setRollingCacheLimitMb(mb);
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

  Future<void> setDownloadConcurrency(int concurrency) async {
    state = state.copyWith(downloadConcurrency: concurrency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrencyKey, concurrency);
  }

  Future<void> setStorageLocation(String locationId, String path) async {
    state = state.copyWith(
      storageLocationId: locationId,
      storageLocationPath: path,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationIdKey, locationId);
    await prefs.setString(_locationPathKey, path);
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

  static String? _cachedBasePath;

  /// Initializes the local audio cache base directory path.
  static Future<void> initialize({
    void Function(String missingPath)? onMissingVolume,
  }) async {
    _cachedBasePath = await StorageManager.resolveActiveCacheBasePath(
      onMissingVolume: onMissingVolume,
    );
    final dir = Directory(_cachedBasePath!);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Synchronously checks if a song audio file exists in offline or rolling cache.
  static String? findCachedSongPathSync(
    String serverId,
    String songId, [
    String? suffix,
  ]) {
    final base = _cachedBasePath;
    if (base == null) return null;
    final exts = [
      if (suffix != null && suffix.isNotEmpty) suffix,
      'flac',
      'mp3',
      'opus',
      'm4a',
      'aac',
      'ogg',
      'wav',
    ];
    // Check offline (pinned)
    for (final ext in exts) {
      final f = File(
        p.join(base, 'music', 'offline', serverId, '$songId.$ext'),
      );
      if (f.existsSync() && f.lengthSync() > 0) {
        touchCachedSongSync(f.path);
        return f.path;
      }
    }
    // Check rolling / streaming cache
    for (final ext in exts) {
      final fRolling = File(
        p.join(base, 'music', 'rolling', serverId, '$songId.$ext'),
      );
      if (fRolling.existsSync() && fRolling.lengthSync() > 0) {
        touchCachedSongSync(fRolling.path);
        return fRolling.path;
      }
      final fCache = File(
        p.join(base, 'music', 'cache', serverId, '$songId.$ext'),
      );
      if (fCache.existsSync() && fCache.lengthSync() > 0) {
        touchCachedSongSync(fCache.path);
        return fCache.path;
      }
    }
    return null;
  }

  /// Touches a cached file's modified time to maintain accurate LRU ranking.
  static void touchCachedSongSync(String filePath) {
    try {
      File(filePath).setLastModifiedSync(DateTime.now());
    } catch (_) {}
  }

  AudioCacheService(this._ref, {Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  Future<Directory> _getBaseDir() async {
    if (_cachedBasePath != null) {
      final dir = Directory(_cachedBasePath!);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    _cachedBasePath = await StorageManager.resolveActiveCacheBasePath(
      onMissingVolume: (path) {
        _ref.read(missingStorageWarningProvider.notifier).state = path;
      },
    );
    final dir = Directory(_cachedBasePath!);
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
  Future<String?> cacheSong(
    Song song, {
    bool isPinned = true,
    TaskHandle? parentHandle,
    CancelToken? cancelToken,
    void Function(int bytesDownloaded)? onProgressDelta,
  }) async {
    final client = _ref.read(subsonicClientProvider);
    final dao = _ref.read(libraryDaoProvider);
    final repo = _ref.read(libraryRepositoryProvider);
    if (client == null || repo == null) return null;

    final serverId = song.serverId;
    final ext = song.suffix?.isNotEmpty == true ? song.suffix! : 'mp3';
    final musicDir = await _getMusicDir(serverId, isPinned: isPinned);
    final destFile = File(p.join(musicDir.path, '${song.id}.$ext'));

    // Check disk safety headroom prior to download
    final base = await _getBaseDir();
    final estimatedBytes =
        song.size ?? (10 * 1024 * 1024); // 10 MB fallback estimate
    if (!StorageManager.isDiskSpaceSafe(
      base.path,
      additionalBytes: estimatedBytes,
    )) {
      // Free space is tight — aggressively evict oldest tracks to make room
      await _enforceUnifiedCacheLimit(
        serverId,
        targetBytesToFree: estimatedBytes,
      );
    }

    if (!StorageManager.isDiskSpaceSafe(
      base.path,
      additionalBytes: estimatedBytes,
    )) {
      developer.log(
        'Storage space is critically low. Aborting download for song ${song.id}',
        name: 'AudioCacheService',
      );
      return null;
    }

    final taskRegistry = _ref.read(taskRegistryProvider.notifier);
    final songCancelToken = cancelToken ?? CancelToken();
    final isStandAloneTask = isPinned && parentHandle == null;
    final handle = isStandAloneTask
        ? taskRegistry.start(
            kind: TaskKind.audioDownload,
            label: 'Downloading "${song.title}"',
            serverId: serverId,
            onCancel: () => songCancelToken.cancel(),
          )
        : parentHandle;

    if (isStandAloneTask) {
      handle?.enumerated(items: 1);
    }

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
        var lastBytes = 0;

        await _dio.download(
          streamUri.toString(),
          tempFile.path,
          cancelToken: songCancelToken,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            final delta = received - lastBytes;
            lastBytes = received;
            if (delta > 0) {
              onProgressDelta?.call(delta);
            }
            if (isStandAloneTask) {
              if (total > 0) {
                handle?.enumerated(items: 1, bytes: total);
              }
              handle?.progress(bytes: received);
            }
          },
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
        ArtCache.instance.downloadFile(coverUri.toString()).ignore();
      }

      if (song.albumId != null) {
        repo.refreshAlbum(song.albumId!).ignore();
      }
      if (song.artistId != null) {
        _cacheArtistMetadata(
          client,
          dao,
          repo,
          serverId,
          song.artistId!,
        ).ignore();
      }

      // Enforce unified audio cache limit across all cached tracks (LRU)
      _enforceUnifiedCacheLimit(serverId).ignore();

      if (isStandAloneTask) {
        handle?.progress(items: 1);
        handle?.complete();
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
      if (isStandAloneTask) {
        if (songCancelToken.isCancelled) {
          // Handled by taskRegistry cancel
        } else {
          handle?.fail(e);
        }
      }
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

  Future<void> _cacheArtistMetadata(
    SubsonicClient client,
    LibraryDao dao,
    LibraryRepository repo,
    String serverId,
    String artistId,
  ) async {
    try {
      await repo.refreshArtist(artistId);
      final artist = await dao.watchArtist(serverId, artistId).first;
      if (artist != null && artist.coverArtId != null) {
        final artistArtUri = client.getCoverArtUri(artist.coverArtId!);
        ArtCache.instance.downloadFile(artistArtUri.toString()).ignore();
      }

      final info = await client.getArtistInfoParsed(artistId);
      if (info != null && artist != null) {
        final updated = artist.copyWith(
          biography: info.biography ?? artist.biography,
          musicBrainzId: info.musicBrainzId ?? artist.musicBrainzId,
          imageUrl: info.bestImageUrl ?? artist.imageUrl,
        );
        await dao.upsertArtists([updated], DateTime.now());
        if (info.bestImageUrl != null) {
          ArtCache.instance.downloadFile(info.bestImageUrl!).ignore();
        }
      }
    } catch (_) {}
  }

  /// Caches all songs in an album.
  Future<void> cacheAlbum(String albumId, {bool isPinned = true}) async {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    final dao = _ref.read(libraryDaoProvider);

    var songs = await repo.watchAlbumSongs(albumId).first;
    if (songs.isEmpty) {
      await repo.refreshAlbum(albumId);
      songs = await repo.watchAlbumSongs(albumId).first;
    }
    if (songs.isEmpty) return;

    final album = await repo.watchAlbum(albumId).first;
    if (album?.artistId != null) {
      final client = _ref.read(subsonicClientProvider);
      if (client != null) {
        _cacheArtistMetadata(
          client,
          dao,
          repo,
          songs.first.serverId,
          album!.artistId!,
        ).ignore();
      }
    }
    final taskRegistry = _ref.read(taskRegistryProvider.notifier);
    final cancelToken = CancelToken();
    final handle = isPinned
        ? taskRegistry.start(
            kind: TaskKind.audioDownload,
            label: 'Caching "${album?.name ?? 'Album'}"',
            serverId: songs.first.serverId,
            onCancel: () => cancelToken.cancel(),
          )
        : null;

    final totalBytesKnown = songs.fold<int>(0, (sum, s) => sum + (s.size ?? 0));
    final hasTotalBytes =
        totalBytesKnown > 0 &&
        songs.every((s) => s.size != null && s.size! > 0);

    handle?.enumerated(
      items: songs.length,
      bytes: hasTotalBytes ? totalBytesKnown : null,
    );

    final unpinnedSongs = songs
        .where((s) => s.downloadState != DownloadState.complete)
        .toList();
    if (isPinned && unpinnedSongs.isNotEmpty) {
      await dao.updateSongsDownloadState(
        songs.first.serverId,
        unpinnedSongs.map((s) => s.id).toList(),
        state: DownloadState.queued,
      );
    }

    final concurrency = _ref
        .read(audioCacheConfigProvider)
        .downloadConcurrency
        .clamp(1, 16);
    var currentIndex = 0;
    var doneCount = 0;
    var totalBytes = 0;

    Future<void> worker() async {
      while (!cancelToken.isCancelled && handle?.isCanceled != true) {
        final i = currentIndex++;
        if (i >= songs.length) break;
        final song = songs[i];
        handle?.note('Track ${doneCount + 1}/${songs.length}: "${song.title}"');
        final path = await cacheSong(
          song,
          isPinned: isPinned,
          parentHandle: handle,
          cancelToken: cancelToken,
          onProgressDelta: (bytesDelta) {
            totalBytes += bytesDelta;
            handle?.progress(items: doneCount, bytes: totalBytes);
          },
        );
        if (path != null) {
          doneCount++;
        }
        handle?.progress(items: doneCount, bytes: totalBytes);
      }
    }

    final workerCount = concurrency.clamp(1, songs.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (cancelToken.isCancelled || handle?.isCanceled == true) {
      final unfinished = songs
          .where((s) => s.downloadState != DownloadState.complete)
          .map((s) => s.id)
          .toList();
      await dao.updateSongsDownloadState(
        songs.first.serverId,
        unfinished,
        state: DownloadState.none,
      );
    } else {
      handle?.complete();
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
    if (albums.isEmpty) return;

    final allSongs = <Song>[];
    for (final album in albums) {
      var songs = await repo.watchAlbumSongs(album.id).first;
      if (songs.isEmpty) {
        await repo.refreshAlbum(album.id);
        songs = await repo.watchAlbumSongs(album.id).first;
      }
      allSongs.addAll(songs);
    }
    if (allSongs.isEmpty) return;

    final artist = await repo.watchArtist(artistId).first;
    final dao = _ref.read(libraryDaoProvider);
    final client = _ref.read(subsonicClientProvider);
    if (client != null) {
      _cacheArtistMetadata(
        client,
        dao,
        repo,
        allSongs.first.serverId,
        artistId,
      ).ignore();
    }
    final taskRegistry = _ref.read(taskRegistryProvider.notifier);
    final cancelToken = CancelToken();
    final handle = isPinned
        ? taskRegistry.start(
            kind: TaskKind.audioDownload,
            label: 'Caching "${artist?.name ?? 'Artist'}"',
            serverId: allSongs.first.serverId,
            onCancel: () => cancelToken.cancel(),
          )
        : null;

    final totalBytesKnown = allSongs.fold<int>(
      0,
      (sum, s) => sum + (s.size ?? 0),
    );
    final hasTotalBytes =
        totalBytesKnown > 0 &&
        allSongs.every((s) => s.size != null && s.size! > 0);

    handle?.enumerated(
      items: allSongs.length,
      bytes: hasTotalBytes ? totalBytesKnown : null,
    );

    final unpinnedSongs = allSongs
        .where((s) => s.downloadState != DownloadState.complete)
        .toList();
    if (isPinned && unpinnedSongs.isNotEmpty) {
      await dao.updateSongsDownloadState(
        allSongs.first.serverId,
        unpinnedSongs.map((s) => s.id).toList(),
        state: DownloadState.queued,
      );
    }

    final concurrency = _ref
        .read(audioCacheConfigProvider)
        .downloadConcurrency
        .clamp(1, 16);
    var currentIndex = 0;
    var doneCount = 0;
    var totalBytes = 0;

    Future<void> worker() async {
      while (!cancelToken.isCancelled && handle?.isCanceled != true) {
        final i = currentIndex++;
        if (i >= allSongs.length) break;
        final song = allSongs[i];
        handle?.note(
          'Track ${doneCount + 1}/${allSongs.length}: "${song.title}"',
        );
        final path = await cacheSong(
          song,
          isPinned: isPinned,
          parentHandle: handle,
          cancelToken: cancelToken,
          onProgressDelta: (bytesDelta) {
            totalBytes += bytesDelta;
            handle?.progress(items: doneCount, bytes: totalBytes);
          },
        );
        if (path != null) {
          doneCount++;
        }
        handle?.progress(items: doneCount, bytes: totalBytes);
      }
    }

    final workerCount = concurrency.clamp(1, allSongs.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (cancelToken.isCancelled || handle?.isCanceled == true) {
      final unfinished = allSongs
          .where((s) => s.downloadState != DownloadState.complete)
          .map((s) => s.id)
          .toList();
      await dao.updateSongsDownloadState(
        allSongs.first.serverId,
        unfinished,
        state: DownloadState.none,
      );
    } else {
      handle?.complete();
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

  /// Enforces unified LRU cache quota and low-disk safety across all cached tracks.
  Future<void> _enforceUnifiedCacheLimit(
    String serverId, {
    int targetBytesToFree = 0,
  }) async {
    final config = _ref.read(audioCacheConfigProvider);
    final maxBytes = config.rollingCacheLimitMb > 0
        ? config.rollingCacheLimitMb * 1024 * 1024
        : 0;

    final base = await _getBaseDir();
    final rollingDir = Directory(
      p.join(base.path, 'music', 'rolling', serverId),
    );
    final offlineDir = Directory(
      p.join(base.path, 'music', 'offline', serverId),
    );

    final rollingFiles = <File>[];
    if (rollingDir.existsSync()) {
      for (final entity in rollingDir.listSync()) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          rollingFiles.add(entity);
        }
      }
    }

    final offlineFiles = <File>[];
    if (offlineDir.existsSync()) {
      for (final entity in offlineDir.listSync()) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          offlineFiles.add(entity);
        }
      }
    }

    // Sort rolling first, then offline; each ordered oldest lastModified first (LRU)
    rollingFiles.sort(
      (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
    );
    offlineFiles.sort(
      (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
    );

    // Unified eviction queue: unpinned auto-cache first, then oldest pinned tracks
    final evictionQueue = [...rollingFiles, ...offlineFiles];

    var currentTotalBytes =
        _calculateDirSize(rollingDir) + _calculateDirSize(offlineDir);
    var freedBytes = 0;

    for (final file in evictionQueue) {
      final isOverQuota = maxBytes > 0 && currentTotalBytes > maxBytes;
      final needsMoreDiskSpace =
          targetBytesToFree > 0 && freedBytes < targetBytesToFree;
      final isDiskUnsafe = !StorageManager.isDiskSpaceSafe(base.path);

      if (!isOverQuota && !needsMoreDiskSpace && !isDiskUnsafe) {
        break;
      }

      final size = file.lengthSync();
      final songId = p.basenameWithoutExtension(file.path);
      try {
        file.deleteSync();
        currentTotalBytes -= size;
        freedBytes += size;

        // Clean up associated lyrics if present
        final lyricsDir = await _getLyricsDir(serverId);
        final lrcFile = File(p.join(lyricsDir.path, '$songId.lrc'));
        if (lrcFile.existsSync()) {
          try {
            lrcFile.deleteSync();
          } catch (_) {}
        }

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

  /// Switches the storage location for audio caching, with optional data migration.
  Future<bool> switchStorageLocation(
    StorageVolume targetVolume, {
    required bool migrateData,
    void Function(double fraction, String status)? onProgress,
  }) async {
    final oldBasePath =
        _cachedBasePath ?? (await StorageManager.resolveActiveCacheBasePath());
    final newBasePath = targetVolume.path;

    if (p.equals(oldBasePath, newBasePath)) return true;

    if (migrateData) {
      final success = await StorageManager.migrateCacheDirectory(
        sourcePath: oldBasePath,
        targetPath: newBasePath,
        onProgress: onProgress,
      );
      if (!success) return false;

      // Update SQLite local paths
      await _ref
          .read(libraryDaoProvider)
          .migrateLocalPaths(oldBasePath, newBasePath);
    } else {
      // Clear old directory if not migrating
      try {
        final oldDir = Directory(oldBasePath);
        if (oldDir.existsSync()) {
          oldDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }

    _cachedBasePath = newBasePath;
    await _ref
        .read(audioCacheConfigProvider.notifier)
        .setStorageLocation(targetVolume.id, newBasePath);

    return true;
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

class AudioCacheSummary {
  final int cachedSongCount;
  final int audioBytes;

  const AudioCacheSummary({this.cachedSongCount = 0, this.audioBytes = 0});
}

final audioCacheSummaryProvider =
    FutureProvider.family<AudioCacheSummary, String>((ref, serverId) async {
      final service = ref.watch(audioCacheServiceProvider);
      final dao = ref.watch(libraryDaoProvider);
      final songs = await dao.getDownloadedSongs(serverId);
      final bytes = await service.getAudioCacheBytes();
      return AudioCacheSummary(
        cachedSongCount: songs.length,
        audioBytes: bytes,
      );
    });
