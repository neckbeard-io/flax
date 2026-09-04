import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flax/core/logging/app_logger.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/platform/native_downloader.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/art_cache.dart';

class MetadataCacheSummary {
  final int albumArtCached;
  final int albumArtTotal;
  final int albumArtBytes;

  final int artistArtCached;
  final int artistArtTotal;
  final int artistArtBytes;

  final int artistInfoCached;
  final int artistInfoTotal;
  final int artistInfoBytes;

  final DateTime? lastSyncedAt;

  const MetadataCacheSummary({
    this.albumArtCached = 0,
    this.albumArtTotal = 0,
    this.albumArtBytes = 0,
    this.artistArtCached = 0,
    this.artistArtTotal = 0,
    this.artistArtBytes = 0,
    this.artistInfoCached = 0,
    this.artistInfoTotal = 0,
    this.artistInfoBytes = 0,
    this.lastSyncedAt,
  });

  int get totalBytes => albumArtBytes + artistArtBytes + artistInfoBytes;

  bool get isFullyCached {
    final albumOk = albumArtTotal == 0 || albumArtCached >= albumArtTotal;
    final artistArtOk =
        artistArtTotal == 0 || artistArtCached >= artistArtTotal;
    final artistInfoOk =
        artistInfoTotal == 0 || artistInfoCached >= artistInfoTotal;
    return albumOk && artistArtOk && artistInfoOk;
  }
}

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

  /// Computes cache status breakdown (counts and disk usage) for all metadata groups.
  Future<MetadataCacheSummary> getSummary(Server server, LibraryDao dao) async {
    try {
      final albums = await dao.getAllAlbums(server.id);
      final artists = await dao.getAllArtists(server.id);
      final config = server.metadataCacheConfig;

      int albumArtCached = 0;
      int albumArtBytes = 0;
      final albumArtTotal = albums
          .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
          .length;

      if (config.albumArtQuality != MetadataQuality.disabled) {
        final reqSize = config.albumArtQuality.requestSize;
        final validAlbums = albums
            .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
            .toList();
        const chunkSize = 200;
        for (var i = 0; i < validAlbums.length; i += chunkSize) {
          final chunk = validAlbums.sublist(
            i,
            (i + chunkSize).clamp(0, validAlbums.length),
          );
          final files = await Future.wait(
            chunk.map((a) {
              final key = 'cover-${a.coverArtId}-${reqSize ?? "orig"}';
              return _artCache.getFileFromCache(key);
            }),
          );
          for (final f in files) {
            if (f != null) {
              albumArtCached++;
              albumArtBytes += await f.file.length();
            }
          }
        }
      }

      int artistArtCached = 0;
      int artistArtBytes = 0;
      final artistArtTotal = artists
          .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
          .length;

      if (config.artistArtQuality != MetadataQuality.disabled) {
        final reqSize = config.artistArtQuality.requestSize;
        final validArtists = artists
            .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
            .toList();
        const chunkSize = 200;
        for (var i = 0; i < validArtists.length; i += chunkSize) {
          final chunk = validArtists.sublist(
            i,
            (i + chunkSize).clamp(0, validArtists.length),
          );
          final files = await Future.wait(
            chunk.map((a) {
              final key = 'cover-${a.coverArtId}-${reqSize ?? "orig"}';
              return _artCache.getFileFromCache(key);
            }),
          );
          for (final f in files) {
            if (f != null) {
              artistArtCached++;
              artistArtBytes += await f.file.length();
            }
          }
        }
      }

      int artistInfoCached = 0;
      int artistInfoBytes = 0;
      final artistInfoTotal = artists.length;

      for (final a in artists) {
        if (a.biography != null) {
          artistInfoCached++;
          if (a.biography!.isNotEmpty) {
            artistInfoBytes += utf8.encode(a.biography!).length;
          }
        }
      }

      return MetadataCacheSummary(
        albumArtCached: albumArtCached,
        albumArtTotal: albumArtTotal,
        albumArtBytes: albumArtBytes,
        artistArtCached: artistArtCached,
        artistArtTotal: artistArtTotal,
        artistArtBytes: artistArtBytes,
        artistInfoCached: artistInfoCached,
        artistInfoTotal: artistInfoTotal,
        artistInfoBytes: artistInfoBytes,
        lastSyncedAt: config.lastSyncedAt,
      );
    } catch (e) {
      AppLogger.w('Sync', 'Error calculating metadata cache summary: $e');
      return const MetadataCacheSummary();
    }
  }

  /// Cancels an in-progress metadata sync immediately.
  void cancel() {
    _isCanceled = true;
    if (NativeDownloader.isSupported) {
      NativeDownloader.cancelAll().ignore();
    }
    final handle = _activeHandle;
    if (handle != null) {
      _ref.read(taskRegistryProvider.notifier).cancel(handle.id);
    }
  }

  /// Starts a background metadata & art precache synchronization.
  Future<void> startSync({
    required Server server,
    required SubsonicClient client,
    required LibraryDao dao,
  }) async {
    if (isRunning) return;

    if (NativeDownloader.isSupported) {
      await NativeDownloader.requestNotificationPermission();
    }

    _isCanceled = false;
    final taskRegistry = _ref.read(taskRegistryProvider.notifier);
    final handle = taskRegistry.start(
      kind: TaskKind.metadataCrawl,
      label: 'Syncing metadata & cover art',
      serverId: server.id,
      onCancel: () {
        _isCanceled = true;
        if (NativeDownloader.isSupported) {
          NativeDownloader.cancelAll().ignore();
        }
      },
    );
    _activeHandle = handle;
    handle.enumerating();

    try {
      final config = server.metadataCacheConfig;

      // 1. Gather all entities from local database or fetch if missing/incomplete
      var albums = await dao.watchAllAlbums(server.id).first;
      var artists = await dao.watchArtists(server.id).first;

      try {
        var offset = 0;
        const pageSize = 500;
        final allFetched = <Album>[];
        while (!_isCanceled && !handle.isCanceled) {
          handle.note('Indexing library: ${allFetched.length} albums found');
          final page = await client.getAlbumList(
            AlbumListType.alphabeticalByName,
            count: pageSize,
            offset: offset,
          );
          allFetched.addAll(page);
          if (page.length < pageSize) break;
          offset += pageSize;
        }
        if (!_isCanceled && !handle.isCanceled && allFetched.isNotEmpty) {
          await dao.upsertAlbums(allFetched, DateTime.now());
          albums = allFetched;
        }
      } catch (e) {
        AppLogger.w('Sync', 'Error fetching full album list: $e');
      }

      if (artists.isEmpty) {
        try {
          final fetchedArtists = await client.getArtists();
          if (!_isCanceled && !handle.isCanceled && fetchedArtists.isNotEmpty) {
            await dao.upsertArtists(fetchedArtists, DateTime.now());
            artists = fetchedArtists;
          }
        } catch (e) {
          AppLogger.w('Sync', 'Error fetching artists: $e');
        }
      }

      if (_isCanceled || handle.isCanceled) return;

      // 2. Build sync work items for MISSING metadata & artwork only (parallel checks)
      handle.note('Checking for missing artwork and metadata...');
      final artWorkItems = <_SyncWorkItem>[];
      final infoWorkItems = <_SyncWorkItem>[];

      if (config.albumArtQuality != MetadataQuality.disabled) {
        final reqSize = config.albumArtQuality.requestSize;
        final validAlbums = albums
            .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
            .toList();
        const chunkSize = 50;
        for (var i = 0; i < validAlbums.length; i += chunkSize) {
          if (_isCanceled || handle.isCanceled) return;
          final chunk = validAlbums.sublist(
            i,
            (i + chunkSize).clamp(0, validAlbums.length),
          );
          final files = await Future.wait(
            chunk.map((a) {
              final key = 'cover-${a.coverArtId}-${reqSize ?? "orig"}';
              return _artCache.getFileFromCache(key);
            }),
          );
          for (var j = 0; j < chunk.length; j++) {
            if (files[j] == null) {
              artWorkItems.add(
                _AlbumArtWorkItem(
                  album: chunk[j],
                  quality: config.albumArtQuality,
                ),
              );
            }
          }
        }
      }

      if (config.artistArtQuality != MetadataQuality.disabled) {
        final reqSize = config.artistArtQuality.requestSize;
        final validArtists = artists
            .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
            .toList();
        const chunkSize = 50;
        for (var i = 0; i < validArtists.length; i += chunkSize) {
          if (_isCanceled || handle.isCanceled) return;
          final chunk = validArtists.sublist(
            i,
            (i + chunkSize).clamp(0, validArtists.length),
          );
          final files = await Future.wait(
            chunk.map((a) {
              final key = 'cover-${a.coverArtId}-${reqSize ?? "orig"}';
              return _artCache.getFileFromCache(key);
            }),
          );
          for (var j = 0; j < chunk.length; j++) {
            if (files[j] == null) {
              artWorkItems.add(
                _ArtistArtWorkItem(
                  artist: chunk[j],
                  quality: config.artistArtQuality,
                ),
              );
            }
          }
        }
      }

      if (config.cacheArtistInfo) {
        for (final artist in artists) {
          if (_isCanceled || handle.isCanceled) return;
          if (artist.biography == null) {
            infoWorkItems.add(_ArtistInfoWorkItem(artist: artist));
          }
        }
      }

      if (_isCanceled || handle.isCanceled) return;

      final totalItems = artWorkItems.length + infoWorkItems.length;
      handle.enumerated(items: totalItems);

      if (totalItems == 0) {
        // Record timestamp on completion
        _ref
            .read(serverListProvider.notifier)
            .updateServer(
              server.copyWith(
                metadataCacheConfig: config.copyWith(
                  lastSyncedAt: DateTime.now(),
                ),
              ),
            );
        handle.note(null);
        handle.complete();
        return;
      }

      // 3. Process work items with worker concurrency pool (up to 24 workers)
      final concurrency = config.concurrency.clamp(1, 24);
      int itemsDone = 0;
      int bytesDone = 0;

      if (NativeDownloader.isSupported && artWorkItems.isNotEmpty) {
        // 3a. Process artwork via Android Foreground Service OkHttp engine
        final tempDir = await getTemporaryDirectory();
        final tempArtDir = Directory(p.join(tempDir.path, 'flax_sync_art'));
        if (!tempArtDir.existsSync()) {
          tempArtDir.createSync(recursive: true);
        }

        final nativeTasks = <NativeDownloadTask>[];
        final taskMetaMap = <String, (String url, String desc)>{};

        for (final item in artWorkItems) {
          String coverId;
          int? reqSize;
          String desc;

          if (item is _AlbumArtWorkItem) {
            coverId = item.album.coverArtId!;
            reqSize = item.quality.requestSize;
            desc = 'Album art: ${item.album.name}';
          } else if (item is _ArtistArtWorkItem) {
            coverId = item.artist.coverArtId!;
            reqSize = item.quality.requestSize;
            desc = 'Artist photo: ${item.artist.name}';
          } else {
            continue;
          }

          final cacheKey = 'cover-$coverId-${reqSize ?? "orig"}';
          final uri = client.getCoverArtUri(coverId, size: reqSize);
          final destPath = p.join(tempArtDir.path, '$cacheKey.jpg');

          nativeTasks.add(
            NativeDownloadTask(
              songId: cacheKey,
              serverId: server.id,
              title: desc,
              downloadUrl: uri.toString(),
              destinationPath: destPath,
            ),
          );
          taskMetaMap[cacheKey] = (uri.toString(), desc);
        }

        final batchDone = Completer<void>();
        final sub = NativeDownloader.eventStream.listen((event) async {
          switch (event) {
            case NativeTaskStartedEvent():
              if (taskMetaMap.containsKey(event.songId)) {
                handle.note(event.title);
              }
            case NativeTaskCompletedEvent():
              final meta = taskMetaMap[event.songId];
              if (meta != null) {
                try {
                  final file = File(event.localPath);
                  if (file.existsSync()) {
                    final bytes = await file.readAsBytes();
                    await _artCache.putFile(
                      meta.$1,
                      bytes,
                      key: event.songId,
                      fileExtension: 'jpg',
                    );
                    file.delete().ignore();
                    bytesDone += bytes.length;
                  }
                } catch (e) {
                  AppLogger.w(
                    'Sync',
                    'Failed to store art cache for ${event.songId}: $e',
                  );
                }
                itemsDone++;
                handle.progress(items: itemsDone, bytes: bytesDone);
                if (itemsDone >= nativeTasks.length && !batchDone.isCompleted) {
                  batchDone.complete();
                }
              }
            case NativeTaskFailedEvent():
              if (taskMetaMap.containsKey(event.songId)) {
                itemsDone++;
                handle.itemFailed(1);
                handle.progress(items: itemsDone, bytes: bytesDone);
                if (itemsDone >= nativeTasks.length && !batchDone.isCompleted) {
                  batchDone.complete();
                }
              }
            case NativeQueueCompletedEvent():
              if (!batchDone.isCompleted) {
                batchDone.complete();
              }
            case NativeCanceledEvent():
              if (!batchDone.isCompleted) {
                batchDone.complete();
              }
            default:
              break;
          }
        });

        try {
          await NativeDownloader.startDownload(
            tasks: nativeTasks,
            concurrency: concurrency,
            notificationTitle: 'Syncing metadata & cover art',
          );
          await batchDone.future;
        } finally {
          sub.cancel().ignore();
        }
      } else if (artWorkItems.isNotEmpty) {
        // Desktop platforms: Dart worker pool
        int currentIndex = 0;
        Future<void> artWorker() async {
          while (!_isCanceled && !handle.isCanceled) {
            final itemIndex = currentIndex++;
            if (itemIndex >= artWorkItems.length) break;
            final item = artWorkItems[itemIndex];

            try {
              if (_isCanceled || handle.isCanceled) break;
              handle.note(item.description);
              final bytes = await item.execute(
                client,
                dao,
                server.id,
                _artCache,
              );
              if (!_isCanceled && !handle.isCanceled) {
                itemsDone++;
                bytesDone += bytes;
                handle.progress(items: itemsDone, bytes: bytesDone);
              }
            } catch (e) {
              AppLogger.w('Sync', 'Error processing sync item: $e');
              if (!_isCanceled && !handle.isCanceled) {
                itemsDone++;
                handle.itemFailed(1);
                handle.progress(items: itemsDone, bytes: bytesDone);
              }
            }
          }
        }

        final workers = List.generate(concurrency, (_) => artWorker());
        await Future.wait(workers);
      }

      // 3b. Process artist info items (biographies)
      if (!_isCanceled && !handle.isCanceled && infoWorkItems.isNotEmpty) {
        int infoIndex = 0;
        Future<void> infoWorker() async {
          while (!_isCanceled && !handle.isCanceled) {
            final itemIndex = infoIndex++;
            if (itemIndex >= infoWorkItems.length) break;
            final item = infoWorkItems[itemIndex];

            try {
              if (_isCanceled || handle.isCanceled) break;
              handle.note(item.description);
              final bytes = await item.execute(
                client,
                dao,
                server.id,
                _artCache,
              );
              if (!_isCanceled && !handle.isCanceled) {
                itemsDone++;
                bytesDone += bytes;
                handle.progress(items: itemsDone, bytes: bytesDone);
              }
            } catch (e) {
              AppLogger.w('Sync', 'Error processing artist info item: $e');
              if (!_isCanceled && !handle.isCanceled) {
                itemsDone++;
                handle.itemFailed(1);
                handle.progress(items: itemsDone, bytes: bytesDone);
              }
            }
          }
        }

        final workers = List.generate(concurrency, (_) => infoWorker());
        await Future.wait(workers);
      }

      if (!_isCanceled && !handle.isCanceled) {
        // Record timestamp on completion
        _ref
            .read(serverListProvider.notifier)
            .updateServer(
              server.copyWith(
                metadataCacheConfig: config.copyWith(
                  lastSyncedAt: DateTime.now(),
                ),
              ),
            );
        handle.note(null);
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
  String get description;
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
  String get description => 'Album art: ${album.name}';

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
  String get description => 'Artist photo: ${artist.name}';

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
  String get description => 'Artist bio: ${artist.name}';

  @override
  Future<int> execute(
    SubsonicClient client,
    LibraryDao dao,
    String serverId,
    BaseCacheManager cacheManager,
  ) async {
    final info = await client.getArtistInfoParsed(artist.id);
    final updated = artist.copyWith(
      biography: info?.biography ?? '',
      musicBrainzId: info?.musicBrainzId,
      imageUrl:
          info?.largeImageUrl ?? info?.mediumImageUrl ?? info?.smallImageUrl,
    );
    await dao.upsertArtists([updated], DateTime.now());
    return (info?.biography != null && info!.biography!.isNotEmpty)
        ? utf8.encode(info.biography!).length
        : 0;
  }
}

final metadataSyncServiceProvider = Provider<MetadataSyncService>((ref) {
  return MetadataSyncService(ref);
});

final metadataCacheSummaryProvider =
    FutureProvider.family<MetadataCacheSummary, String>((ref, serverId) async {
      final servers = ref.watch(serverListProvider);
      final server = servers.where((s) => s.id == serverId).firstOrNull;
      if (server == null) return const MetadataCacheSummary();

      final dao = ref.watch(libraryDaoProvider);
      final service = ref.watch(metadataSyncServiceProvider);

      return service.getSummary(server, dao);
    });
