import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flax/core/logging/app_logger.dart';

import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/platform/native_downloader.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/art_cache.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
import 'package:flax/shared/widgets/cover_index.dart';

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
  final MetadataCacheConfig? config;

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
    this.config,
  });

  int get totalBytes => albumArtBytes + artistArtBytes + artistInfoBytes;

  bool get isFullyCached {
    final albumEnabled =
        config == null || config!.albumArtQuality != MetadataQuality.disabled;
    final artistArtEnabled =
        config == null || config!.artistArtQuality != MetadataQuality.disabled;
    final artistInfoEnabled = config == null || config!.cacheArtistInfo;

    final albumOk =
        !albumEnabled || albumArtTotal == 0 || albumArtCached >= albumArtTotal;
    final artistArtOk =
        !artistArtEnabled ||
        artistArtTotal == 0 ||
        artistArtCached >= artistArtTotal;
    final artistInfoOk =
        !artistInfoEnabled ||
        artistInfoTotal == 0 ||
        artistInfoCached >= artistInfoTotal;
    return albumOk && artistArtOk && artistInfoOk;
  }
}

class MetadataSyncService {
  final Ref _ref;
  final BaseCacheManager? _cacheManager;
  final Future<CoverIndex> Function() _readCoverIndex;
  bool _isCanceled = false;
  TaskHandle? _activeHandle;

  MetadataSyncService(
    this._ref, {
    this._cacheManager,
    this._readCoverIndex = CoverIndex.readArtCache,
  });

  BaseCacheManager get _artCache => _cacheManager ?? ArtCache.instance;

  bool get isRunning => _activeHandle != null;

  /// Checks if the device is connected to a cellular/mobile network without Wi-Fi or Ethernet.
  Future<bool> isCellularConnection() async {
    try {
      final results = await readCurrentConnectivity(_ref);
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
      var artists = await dao.getAllArtists(server.id);
      final config = server.metadataCacheConfig;

      // Reconcile artists referenced by albums if artists list has not been fully fetched
      final knownArtistIds = {for (final a in artists) a.id};
      final missingArtists = <Artist>[];
      final seenMissingIds = <String>{};
      for (final alb in albums) {
        final aId = alb.artistId;
        if (aId != null &&
            aId.isNotEmpty &&
            !knownArtistIds.contains(aId) &&
            seenMissingIds.add(aId)) {
          missingArtists.add(
            Artist(
              id: aId,
              serverId: server.id,
              name: alb.artistName ?? 'Unknown Artist',
            ),
          );
        }
      }
      if (missingArtists.isNotEmpty) {
        artists = [...artists, ...missingArtists];
      }

      // Read once, and only when some art is wanted.
      late final coverIndex = _readCoverIndex();

      int albumArtCached = 0;
      int albumArtBytes = 0;
      final albumArtTotal = albums
          .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
          .length;

      if (config.albumArtQuality != MetadataQuality.disabled) {
        final reqSize = config.albumArtQuality.requestSize;
        final stored = await (await coverIndex).measure([
          for (final a in albums)
            if (a.coverArtId != null && a.coverArtId!.isNotEmpty)
              coverCacheKey(a.coverArtId!, reqSize),
        ]);
        albumArtCached = stored.count;
        albumArtBytes = stored.bytes;
      }

      int artistArtCached = 0;
      int artistArtBytes = 0;
      final isFullListFetched = await dao.artistsFetchedAt(server.id) != null;
      final artistsWithCover = artists
          .where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty)
          .length;
      final artistArtTotal = isFullListFetched
          ? artistsWithCover
          : (artists.length > artistsWithCover
                ? artists.length
                : artistsWithCover);

      if (config.artistArtQuality != MetadataQuality.disabled) {
        final reqSize = config.artistArtQuality.requestSize;
        final stored = await (await coverIndex).measure([
          for (final a in artists)
            if (a.coverArtId != null && a.coverArtId!.isNotEmpty)
              coverCacheKey(a.coverArtId!, reqSize),
        ]);
        artistArtCached = stored.count;
        artistArtBytes = stored.bytes;
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
        config: config,
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
  /// Genres for downloaded albums cached before genres were stored.
  ///
  /// Downloaded means available offline, and an album opened offline cannot
  /// fetch what it is missing. Downloaded albums only: the rest of the library
  /// fills in as albums are opened. Each album leaves
  /// [LibraryDao.downloadedAlbumIdsMissingGenres] once its rows hold a list, so
  /// later syncs find nothing to do.
  Future<void> _backfillDownloadedGenres({
    required SubsonicClient client,
    required LibraryDao dao,
    required String serverId,
    required int concurrency,
    required TaskHandle handle,
  }) async {
    final ids = await dao.downloadedAlbumIdsMissingGenres(serverId);
    if (ids.isEmpty) return;
    handle.note('Adding genres to ${ids.length} downloaded albums');

    var next = 0;
    Future<void> worker() async {
      while (!_isCanceled && !handle.isCanceled && next < ids.length) {
        final id = ids[next++];
        try {
          final now = DateTime.now();
          await dao.upsertSongs(await client.getAlbumSongs(id), now);
          // The album row was filled by the crawl above, unless the server
          // listed it without any genre at all. Only then is it fetched.
          final album = await dao.watchAlbum(serverId, id).first;
          if (album != null && album.genres == null) {
            await dao.upsertAlbums([await client.getAlbum(id)], now);
          }
          await dao.settleAlbumGenres(serverId, id);
        } catch (e) {
          AppLogger.w('Sync', 'Genre backfill failed for album $id: $e');
        }
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, ids.length), (_) => worker()),
    );
    handle.note(null);
  }

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
        // Already canceled when the downloader reported it: stopping it again
        // would only start the service to stop it.
        if (_isCanceled) return;
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

      // Check server version for Navidrome 0.64.0+ migration
      try {
        final serverInfo = await client.getServerInfo(
          timeout: const Duration(seconds: 5),
        );
        if (serverInfo.serverType?.toLowerCase().contains('navidrome') ==
                true &&
            serverInfo.serverVersion != null) {
          final prevVer = await dao.syncValue(
            server.id,
            SyncKeys.serverVersion,
          );
          bool migrationDetected = false;
          if (prevVer != null &&
              isNavidrome064Migration(prevVer, serverInfo.serverVersion!)) {
            migrationDetected = true;
          } else if (isNavidrome064OrNewer(serverInfo.serverVersion!)) {
            final sample = await dao.getSampleSongIds(server.id, limit: 5);
            if (sample.isNotEmpty) {
              int missingCount = 0;
              for (final sid in sample) {
                try {
                  await client.getSong(sid);
                } on SubsonicException catch (se) {
                  if (se.code == 70) missingCount++;
                } catch (_) {}
              }
              if (missingCount >= 2 ||
                  (sample.length == 1 && missingCount == 1)) {
                migrationDetected = true;
              }
            }
          }

          await dao.putSyncValue(
            server.id,
            SyncKeys.serverVersion,
            serverInfo.serverVersion!,
            DateTime.now(),
          );

          if (migrationDetected) {
            AppLogger.w(
              'Sync',
              'Detected Navidrome 0.64.0+ migration for ${server.id}',
            );
            await dao.putSyncValue(
              server.id,
              SyncKeys.migrationDetected,
              'true',
              DateTime.now(),
            );
            _ref
                .read(serverMigrationAlertProvider.notifier)
                .setAlert(server.id, true);
          }
        }
      } catch (e) {
        AppLogger.w('Sync', 'Could not probe server version: $e');
      }

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
          // If local database has albums but none match newly fetched IDs, migration occurred
          if (albums.length >= 10) {
            final localIds = albums.map((a) => a.id).toSet();
            final hasMatch = allFetched.any((a) => localIds.contains(a.id));
            if (!hasMatch) {
              AppLogger.w(
                'Sync',
                'Detected ID migration for server ${server.id} (0% album ID match)',
              );
              await dao.putSyncValue(
                server.id,
                SyncKeys.migrationDetected,
                'true',
                DateTime.now(),
              );
              _ref
                  .read(serverMigrationAlertProvider.notifier)
                  .setAlert(server.id, true);
            }
          }
          await dao.upsertAlbums(allFetched, DateTime.now());
          albums = allFetched;
        }
      } catch (e) {
        AppLogger.w('Sync', 'Error fetching full album list: $e');
      }

      try {
        handle.note('Indexing library: fetching artists...');
        final fetchedArtists = await client.getArtists();
        if (!_isCanceled && !handle.isCanceled) {
          if (fetchedArtists.isNotEmpty) {
            await dao.upsertArtists(
              fetchedArtists,
              DateTime.now(),
              isFullList: true,
            );
          } else {
            await dao.setArtistsListFetchedAt(server.id, DateTime.now());
          }
          artists = await dao.getAllArtists(server.id);
        }
      } catch (e) {
        AppLogger.w('Sync', 'Error fetching artists: $e');
      }

      if (_isCanceled || handle.isCanceled) return;

      // Reconcile any artists referenced by albums that were not in the artist index
      final knownArtistIds = {for (final a in artists) a.id};
      final missingArtists = <Artist>[];
      final seenMissing = <String>{};
      for (final alb in albums) {
        final aId = alb.artistId;
        if (aId != null &&
            aId.isNotEmpty &&
            !knownArtistIds.contains(aId) &&
            seenMissing.add(aId)) {
          missingArtists.add(
            Artist(
              id: aId,
              serverId: server.id,
              name: alb.artistName ?? 'Unknown Artist',
            ),
          );
        }
      }
      if (missingArtists.isNotEmpty) {
        await dao.upsertArtists(missingArtists, DateTime.now());
        artists = await dao.getAllArtists(server.id);
      }

      if (_isCanceled || handle.isCanceled) return;

      await _backfillDownloadedGenres(
        client: client,
        dao: dao,
        serverId: server.id,
        concurrency: config.concurrency.clamp(1, 24),
        handle: handle,
      );

      if (_isCanceled || handle.isCanceled) return;

      // 2. Build sync work items for MISSING metadata & artwork only (parallel checks)
      handle.note('Checking for missing artwork and metadata...');
      if (NativeDownloader.isSupported) {
        try {
          await CoverArtCache.importNightlyCovers(
            _artCache,
            inbox: await CoverArtCache.nightlyInbox(),
          );
        } catch (e) {
          AppLogger.w('Sync', 'Could not file nightly covers: $e');
        }
      }
      final artWorkItems = <_SyncWorkItem>[];
      final infoWorkItems = <_SyncWorkItem>[];

      // Read once, and only when some art is wanted.
      late final coverIndex = _readCoverIndex();

      if (config.albumArtQuality != MetadataQuality.disabled) {
        final reqSize = config.albumArtQuality.requestSize;
        final missing = (await coverIndex).missing(
          albums.where((a) => a.coverArtId != null && a.coverArtId!.isNotEmpty),
          (a) => coverCacheKey(a.coverArtId!, reqSize),
        );
        for (final album in missing) {
          artWorkItems.add(
            _AlbumArtWorkItem(album: album, quality: config.albumArtQuality),
          );
        }
      }

      if (config.artistArtQuality != MetadataQuality.disabled) {
        final reqSize = config.artistArtQuality.requestSize;
        final missing = (await coverIndex).missing(
          artists.where(
            (a) => a.coverArtId != null && a.coverArtId!.isNotEmpty,
          ),
          (a) => coverCacheKey(a.coverArtId!, reqSize),
        );
        for (final artist in missing) {
          artWorkItems.add(
            _ArtistArtWorkItem(
              artist: artist,
              quality: config.artistArtQuality,
            ),
          );
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

      // The Dart worker pool: desktop, and Android when the downloader cannot
      // start.
      Future<void> fetchArtInProcess() async {
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

          final cacheKey = coverCacheKey(coverId, reqSize);
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
              // Canceled outside this screen: the notification's Cancel, or
              // cancelling every download. The whole sync stops; it used to
              // carry on to the biographies and record itself as finished.
              if (!_isCanceled) {
                _isCanceled = true;
                _ref.read(taskRegistryProvider.notifier).cancel(handle.id);
              }
              if (!batchDone.isCompleted) {
                batchDone.complete();
              }
            default:
              break;
          }
        });

        try {
          final started = await NativeDownloader.startDownload(
            tasks: nativeTasks,
            concurrency: concurrency,
            notificationTitle: 'Syncing metadata & cover art',
          );
          if (started) {
            await batchDone.future;
          } else {
            // Android refuses to start a foreground service once flax is in
            // the background, which listing a large library can outlast.
            // Waiting on a batch that never began left the sync running
            // forever, and every later tap of Sync did nothing.
            AppLogger.w('Sync', 'Downloader did not start; fetching in-app');
            await fetchArtInProcess();
          }
        } finally {
          sub.cancel().ignore();
        }
      } else if (artWorkItems.isNotEmpty) {
        await fetchArtInProcess();
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
    final cacheKey = coverCacheKey(coverId, reqSize);

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
    final cacheKey = coverCacheKey(coverId, reqSize);

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

      final client = ref.watch(subsonicClientProvider);
      if (client != null && server.id == client.server.id) {
        final fetchedAt = await dao.artistsFetchedAt(serverId);
        if (fetchedAt == null) {
          try {
            final fetched = await client.getArtists();
            if (fetched.isNotEmpty) {
              await dao.upsertArtists(
                fetched,
                DateTime.now(),
                isFullList: true,
              );
            } else {
              await dao.setArtistsListFetchedAt(serverId, DateTime.now());
            }
          } catch (e) {
            AppLogger.w('Sync', 'Failed to prefetch artists for summary: $e');
          }
        }
      }

      final migrationDetected = await dao.syncValue(
        serverId,
        SyncKeys.migrationDetected,
      );
      if (migrationDetected == 'true') {
        ref
            .read(serverMigrationAlertProvider.notifier)
            .setAlert(serverId, true);
      }

      return service.getSummary(server, dao);
    });
