import 'package:flax/domain/models/album.dart';
import 'package:flax/domain/models/artist.dart';
import 'package:flax/domain/models/song.dart';

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  const SearchResult({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;
}
