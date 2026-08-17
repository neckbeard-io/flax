import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';

abstract class MusicBackend {
  // Connection
  Future<bool> ping();
  Future<Map<String, int>> getOpenSubsonicExtensions();

  /// The library's change beacon: `lastScan`, a song `count`, and whether a scan
  /// is running. 285 bytes against Navidrome, so it is cheap enough to poll.
  ///
  /// If `lastScan` and `count` are both unchanged, no library content changed —
  /// which is what lets the local cache skip refreshing entirely. Returns null
  /// when the server has no usable answer, and callers must treat that as
  /// "assume changed" rather than as "nothing changed".
  Future<Map<String, dynamic>?> getScanStatus();

  // Browsing
  Future<List<Artist>> getArtists();
  Future<Artist> getArtist(String id);
  Future<Album> getAlbum(String id);
  Future<List<Song>> getAlbumSongs(String albumId);
  Future<Song> getSong(String id);
  Future<List<String>> getGenres();

  // Album lists
  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int offset = 0,
    int count = 20,
    int? fromYear,
    int? toYear,
    String? genre,
  });

  // Search
  Future<SearchResult> search(
    String query, {
    int artistCount = 20,
    int albumCount = 20,
    int songCount = 20,
  });

  // Media
  Uri getStreamUri(String songId, {int? maxBitRate, String? format});

  Uri getCoverArtUri(String id, {int? size});

  Future<String?> getLyrics({String? artist, String? title});
  Future<Lyrics?> getSongLyrics(String songId);

  // Annotations
  Future<void> star({String? id, String? albumId, String? artistId});
  Future<void> unstar({String? id, String? albumId, String? artistId});
  Future<void> setRating(String id, int rating);
  Future<void> scrobble(String id, {bool submission = true});

  // Playlists
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> getPlaylist(String id);
  Future<List<Song>> getPlaylistSongs(String playlistId);
  Future<void> createPlaylist({required String name, List<String>? songIds});
  Future<void> updatePlaylist(
    String id, {
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  });
  Future<void> deletePlaylist(String id);

  // Play queue
  Future<void> savePlayQueue(
    List<String> songIds,
    String currentId,
    int positionMs,
  );
  Future<PlayQueue?> getPlayQueue();

  // Artist info
  Future<Map<String, dynamic>?> getArtistInfo(String id);

  // Similar songs
  Future<List<Song>> getSimilarSongs(String id, {int count = 50});
  Future<List<Song>> getTopSongs(String artistName, {int count = 50});

  // Random
  Future<List<Song>> getRandomSongs({int count = 20, String? genre});
}
