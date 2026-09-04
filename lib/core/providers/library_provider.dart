import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';

/// The local library database and the repository over it. Issue #8.

/// One database for the whole app, opened lazily on first use.
final flaxDatabaseProvider = Provider<FlaxDatabase>((ref) {
  final db = FlaxDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final libraryDaoProvider = Provider<LibraryDao>((ref) {
  return LibraryDao(ref.watch(flaxDatabaseProvider));
});

/// Null until a server is configured, matching [subsonicClientProvider].
///
/// Rebuilt when the active server changes, which swaps the `serverId` filter
/// rather than clearing anything — every table is keyed per server, so
/// switching back finds the previous server's cache intact.
final libraryRepositoryProvider = Provider<LibraryRepository?>((ref) {
  final server = ref.watch(activeServerProvider);
  final client = ref.watch(subsonicClientProvider);
  if (server == null || client == null) return null;

  return LibraryRepositoryImpl(
    ref.watch(libraryDaoProvider),
    client,
    server.id,
  );
});

/// The database's live view of one track.
///
/// The player's queue holds its own [Song] objects — it is a playback queue, not
/// a view of a table — so hearting a track in album detail would never reach the
/// mini player. Watching the row does, without turning the queue itself into a
/// query.
///
/// Callers fall back to their own copy while this is loading, so nothing flickers
/// on the first frame.
final songAnnotationProvider = StreamProvider.family<Song?, String>((
  ref,
  songId,
) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchSong(songId);
});

/// Live sets of IDs that are cached locally on disk.
final downloadedSongIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchDownloadedSongIds();
});

final downloadingSongIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchDownloadingSongIds();
});

final activeDownloadSongsProvider = StreamProvider<List<Song>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchActiveDownloadSongs();
});

final downloadedAlbumIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchDownloadedAlbumIds();
});

final anyDownloadedAlbumIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchAnyDownloadedAlbumIds();
});

final downloadedArtistIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchDownloadedArtistIds();
});

final anyDownloadedArtistIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const {});
  return repo.watchAnyDownloadedArtistIds();
});

final downloadedSongsProvider = StreamProvider<List<Song>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchDownloadedSongs();
});

final downloadedAlbumsProvider = StreamProvider<List<Album>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchDownloadedAlbums();
});
