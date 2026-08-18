import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/art_cache.dart';

class MetadataSyncService {
  final Ref _ref;
  final BaseCacheManager? _cacheManager;
  bool _isCanceled = false;
  TaskHandle? _activeHandle;

  MetadataSyncService(this._ref, {this._cacheManager});

  BaseCacheManager get _artCache => _cacheManager ?? ArtCache.instance;

  bool get isRunning => _activeHandle != null;

  /// Checks if the device is connected to a cellular/mobile network without Wi-Fi or Ethernet.
  Future<bool> isCellularConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  /// Cancels an in-progress metadata sync.
  void cancel() {
    _isCanceled = true;
    final handle = _activeHandle;
    if (handle != null) {
      _ref.read(taskRegistryProvider.notifier).cancel(handle.id);
      _activeHandle = null;
    }
  }

  /// Starts a background metadata & art precache synchronization.
  Future<void> startSync({
    required Server server,
    required SubsonicClient client,
    required LibraryDao dao,
  }) async {
    if (isRunning) return;

    _isCanceled = false;
    final taskRegistry = _ref.read(taskRegistryProvider.notifier);
    final handle = taskRegistry.start(
      kind: TaskKind.metadataCrawl,
      label: 'Syncing metadata & cover art',
      serverId: server.id,
      onCancel: () => cancel(),
    );
    _activeHandle = handle;
    handle.enumerating();

    try {
      final config = server.metadataCacheConfig;

      // 1. Gather all entities from local database or fetch if empty
      var albums = await dao.watchAllAlbums(server.id).first;
      var artists = await dao.watchArtists(server.id).first;

      if (albums.isEmpty) {
        try {
          final fetchedAlbums = await client.getAlbumList(
            AlbumListType.alphabeticalByName,
            count: 2000,
          );
          if (fetchedAlbums.isNotEmpty) {
            await dao.upsertAlbums(fetchedAlbums, DateTime.now());
            albums = fetchedAlbums;
          }
        } catch (e) {
          developer.log(
            'Error fetching albums: $e',
            name: 'MetadataSyncService',
          );
        }
      }

      if (artists.isEmpty) {
        try {
          final fetchedArtists = await client.getArtists();
          if (fetchedArtists.isNotEmpty) {
            await dao.upsertArtists(fetchedArtists, DateTime.now());
            artists = fetchedArtists;
          }
        } catch (e) {
          developer.log(
            'Error fetching artists: $e',
            name: 'MetadataSyncService',
          );
        }
      }

      if (_isCanceled || handle.isCanceled) return;

      // 2. Build sync work items
      final workItems = <_SyncWorkItem>[];

      if (config.albumArtQuality != MetadataQuality.disabled) {
        for (final album in albums) {
          if (album.coverArtId != null && album.coverArtId!.isNotEmpty) {
            workItems.add(
              _AlbumArtWorkItem(album: album, quality: config.albumArtQuality),
            );
          }
        }
      }

      if (config.artistArtQuality != MetadataQuality.disabled) {
        for (final artist in artists) {
          if (artist.coverArtId != null && artist.coverArtId!.isNotEmpty) {
            workItems.add(
              _ArtistArtWorkItem(
                artist: artist,
                quality: config.artistArtQuality,
              ),
            );
          }
        }
      }

      if (config.cacheArtistInfo) {
        for (final artist in artists) {
          workItems.add(_ArtistInfoWorkItem(artist: artist));
        }
      }

      handle.enumerated(items: workItems.length);

      if (workItems.isEmpty) {
        handle.complete();
        _activeHandle = null;
        return;
      }

      // 3. Process work items with worker concurrency pool
      final concurrency = config.concurrency.clamp(1, 8);
      int currentIndex = 0;
      int itemsDone = 0;
      int bytesDone = 0;

      Future<void> worker() async {
        while (currentIndex < workItems.length &&
            !_isCanceled &&
            !handle.isCanceled) {
          final itemIndex = currentIndex++;
          if (itemIndex >= workItems.length) break;
          final item = workItems[itemIndex];

          try {
            final bytes = await item.execute(client, dao, server.id, _artCache);
            if (!_isCanceled && !handle.isCanceled) {
              itemsDone++;
              bytesDone += bytes;
              handle.progress(items: itemsDone, bytes: bytesDone);
            }
          } catch (e) {
            developer.log(
              'Error processing sync item: $e',
              name: 'MetadataSyncService',
            );
            if (!_isCanceled && !handle.isCanceled) {
              itemsDone++;
              handle.itemFailed(1);
              handle.progress(items: itemsDone, bytes: bytesDone);
            }
          }
        }
      }

      final workers = List.generate(concurrency, (_) => worker());
      await Future.wait(workers);

      if (!_isCanceled && !handle.isCanceled) {
        handle.complete();
      }
    } catch (e) {
      if (!_isCanceled && !handle.isCanceled) {
        handle.fail(e);
      }
    } finally {
      _activeHandle = null;
    }
  }
}

sealed class _SyncWorkItem {
  Future<int> execute(
    SubsonicClient client,
    LibraryDao dao,
    String serverId,
    BaseCacheManager cacheManager,
  );
}

class _AlbumArtWorkItem extends _SyncWorkItem {
  final Album album;
  final MetadataQuality quality;

  _AlbumArtWorkItem({required this.album, required this.quality});

  @override
  Future<int> execute(
    SubsonicClient client,
    LibraryDao dao,
    String serverId,
    BaseCacheManager cacheManager,
  ) async {
    final coverId = album.coverArtId!;
    final reqSize = quality.requestSize;
    final cacheKey = 'cover-$coverId-${reqSize ?? "orig"}';

    // Check if already in cache
    final cached = await cacheManager.getFileFromCache(cacheKey);
    if (cached != null) return 0;

    final uri = client.getCoverArtUri(coverId, size: reqSize);
    final fileInfo = await cacheManager.downloadFile(
      uri.toString(),
      key: cacheKey,
    );
    return await fileInfo.file.length();
  }
}

class _ArtistArtWorkItem extends _SyncWorkItem {
  final Artist artist;
  final MetadataQuality quality;

  _ArtistArtWorkItem({required this.artist, required this.quality});

  @override
  Future<int> execute(
    SubsonicClient client,
    LibraryDao dao,
    String serverId,
    BaseCacheManager cacheManager,
  ) async {
    final coverId = artist.coverArtId!;
    final reqSize = quality.requestSize;
    final cacheKey = 'cover-$coverId-${reqSize ?? "orig"}';

    // Check if already in cache
    final cached = await cacheManager.getFileFromCache(cacheKey);
    if (cached != null) return 0;

    final uri = client.getCoverArtUri(coverId, size: reqSize);
    final fileInfo = await cacheManager.downloadFile(
      uri.toString(),
      key: cacheKey,
    );
    return await fileInfo.file.length();
  }
}

class _ArtistInfoWorkItem extends _SyncWorkItem {
  final Artist artist;

  _ArtistInfoWorkItem({required this.artist});

  @override
  Future<int> execute(
    SubsonicClient client,
    LibraryDao dao,
    String serverId,
    BaseCacheManager cacheManager,
  ) async {
    final info = await client.getArtistInfoParsed(artist.id);
    if (info != null) {
      final updated = artist.copyWith(
        biography: info.biography,
        musicBrainzId: info.musicBrainzId,
        imageUrl:
            info.largeImageUrl ?? info.mediumImageUrl ?? info.smallImageUrl,
      );
      await dao.upsertArtists([updated], DateTime.now());
      return 512;
    }
    return 0;
  }
}

final metadataSyncServiceProvider = Provider<MetadataSyncService>((ref) {
  return MetadataSyncService(ref);
});
