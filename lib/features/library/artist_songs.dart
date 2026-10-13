import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/release_group.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_sort.dart';

/// An artist's releases in the order the artist page shows them: by
/// [ReleaseGroup], then by [mode] within each group.
List<Album> discographyOrder(List<Album> albums, AlbumSortMode mode) => [
  for (final (_, group) in groupReleases(sortAlbums(albums, mode))) ...group,
];

/// Every song on [albums], album by album in the order given.
///
/// The local database holds only the tracks of albums something has already
/// fetched, so reading it alone — which is all Play Artist used to do —
/// silently skipped every album never opened. Online, an album with fewer
/// tracks cached than it claims is refreshed first, [parallel] at a time.
/// Offline, only downloaded tracks are returned.
Future<List<Song>> loadArtistSongs(
  LibraryRepository repo,
  List<Album> albums, {
  required bool offline,
  int parallel = 4,
}) async {
  if (!offline) {
    final incomplete = <String>[];
    for (final album in albums) {
      final cached = await repo.watchAlbumSongs(album.id).first;
      if (cached.isEmpty || cached.length < album.songCount) {
        incomplete.add(album.id);
      }
    }
    for (var i = 0; i < incomplete.length; i += parallel) {
      await Future.wait(
        incomplete.skip(i).take(parallel).map(repo.refreshAlbum),
      );
    }
  }

  final downloaded = offline ? await repo.watchDownloadedSongIds().first : null;
  final songs = <Song>[];
  for (final album in albums) {
    final tracks = await repo.watchAlbumSongs(album.id).first;
    songs.addAll(
      downloaded == null
          ? tracks
          : tracks.where((song) => downloaded.contains(song.id)),
    );
  }
  return songs;
}
