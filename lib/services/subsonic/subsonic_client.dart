import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:dio/dio.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/music_backend.dart';

class SubsonicClient implements MusicBackend {
  final Server server;
  final Dio _dio;

  static const String _apiVersion = '1.16.1';
  static const String _clientName = 'flax';

  SubsonicClient({required this.server, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  // ── Auth helpers ──────────────────────────────────────────────────────

  Map<String, String> _authParams() {
    final salt = _generateSalt();
    // Subsonic token auth: t = md5(password + salt), s = salt
    // server.tokenHash stores the raw password for token generation
    final token = md5
        .convert(utf8.encode('${server.tokenHash}$salt'))
        .toString();
    return {
      'u': server.username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
  }

  String _generateSalt() {
    final rand = Random.secure();
    return List.generate(16, (_) => rand.nextInt(36).toRadixString(36)).join();
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, [
    Map<String, dynamic>? extra,
  ]) async {
    final params = <String, dynamic>{..._authParams()};
    if (extra != null) params.addAll(extra);

    final response = await _dio.get<Map<String, dynamic>>(
      '${server.baseUrl}/rest/$endpoint',
      queryParameters: params,
    );

    final body = response.data!;
    final subResponse = body['subsonic-response'] as Map<String, dynamic>;

    if (subResponse['status'] != 'ok') {
      final error = subResponse['error'] as Map<String, dynamic>?;
      throw SubsonicException(
        code: error?['code'] as int? ?? 0,
        message: error?['message'] as String? ?? 'Unknown error',
      );
    }

    return subResponse;
  }

  // ── Connection ────────────────────────────────────────────────────────

  @override
  Future<bool> ping() async {
    await _get('ping');
    return true;
  }

  Future<String?> tryPing() async {
    try {
      await _get('ping');
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return 'Connection timed out. Check the server URL and your network.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not reach server. Check the URL (${server.baseUrl}).';
      }
      if (e.response?.statusCode == 404) {
        return 'Server returned 404. Is this a Navidrome/Subsonic server?';
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Authentication failed (HTTP ${e.response?.statusCode}).';
      }
      if (e.response != null) {
        return 'Server returned HTTP ${e.response?.statusCode}.';
      }
      return 'Network error: ${e.message ?? e.type.name}';
    } on SubsonicException catch (e) {
      if (e.code == 40) {
        return 'Wrong username or password.';
      }
      if (e.code == 41) {
        return 'Token authentication not supported. Check server version.';
      }
      if (e.code == 50) {
        return 'User is not authorized. Check permissions in Navidrome.';
      }
      return 'Server error: ${e.message} (code ${e.code})';
    } on FormatException catch (_) {
      return 'Unexpected response format. Is this a Subsonic-compatible server?';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  @override
  Future<Map<String, int>> getOpenSubsonicExtensions() async {
    try {
      final data = await _get('getOpenSubsonicExtensions');
      final extensions =
          data['openSubsonicExtensions'] as List<dynamic>? ?? [];
      return {
        for (final ext in extensions)
          (ext as Map<String, dynamic>)['name'] as String:
              ext['versions'] is List
                  ? ((ext['versions'] as List).last as int)
                  : 1,
      };
    } catch (_) {
      return {};
    }
  }

  // ── Browsing ──────────────────────────────────────────────────────────

  @override
  Future<List<Artist>> getArtists() async {
    final data = await _get('getArtists');
    final artists = <Artist>[];
    final indexes =
        (data['artists'] as Map<String, dynamic>)['index'] as List<dynamic>? ??
            [];
    for (final index in indexes) {
      final artistList =
          (index as Map<String, dynamic>)['artist'] as List<dynamic>? ?? [];
      for (final a in artistList) {
        artists.add(_parseArtist(a as Map<String, dynamic>));
      }
    }
    return artists;
  }

  @override
  Future<Artist> getArtist(String id) async {
    final data = await _get('getArtist', {'id': id});
    return _parseArtist(data['artist'] as Map<String, dynamic>);
  }

  @override
  Future<Album> getAlbum(String id) async {
    final data = await _get('getAlbum', {'id': id});
    return _parseAlbum(data['album'] as Map<String, dynamic>);
  }

  @override
  Future<List<Song>> getAlbumSongs(String albumId) async {
    final data = await _get('getAlbum', {'id': albumId});
    final album = data['album'] as Map<String, dynamic>;
    final songs = album['song'] as List<dynamic>? ?? [];
    return songs
        .map((s) => _parseSong(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Song> getSong(String id) async {
    final data = await _get('getSong', {'id': id});
    return _parseSong(data['song'] as Map<String, dynamic>);
  }

  @override
  Future<List<String>> getGenres() async {
    final data = await _get('getGenres');
    final genres = (data['genres'] as Map<String, dynamic>)['genre']
            as List<dynamic>? ??
        [];
    return genres
        .map((g) => (g as Map<String, dynamic>)['value'] as String)
        .toList();
  }

  // ── Album lists ───────────────────────────────────────────────────────

  @override
  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int offset = 0,
    int count = 20,
    int? fromYear,
    int? toYear,
    String? genre,
  }) async {
    final params = <String, dynamic>{
      'type': type.apiValue,
      'offset': offset,
      'size': count,
    };
    if (fromYear != null) params['fromYear'] = fromYear;
    if (toYear != null) params['toYear'] = toYear;
    if (genre != null) params['genre'] = genre;

    final data = await _get('getAlbumList2', params);
    final list = (data['albumList2'] as Map<String, dynamic>)['album']
            as List<dynamic>? ??
        [];
    return list.map((a) => _parseAlbum(a as Map<String, dynamic>)).toList();
  }

  // ── Search ────────────────────────────────────────────────────────────

  @override
  Future<SearchResult> search(
    String query, {
    int artistCount = 20,
    int albumCount = 20,
    int songCount = 20,
  }) async {
    final data = await _get('search3', {
      'query': query,
      'artistCount': artistCount,
      'albumCount': albumCount,
      'songCount': songCount,
    });

    final result = data['searchResult3'] as Map<String, dynamic>;

    return SearchResult(
      artists: (result['artist'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where(hasSearchableAlbums)
          .map(_parseArtist)
          .toList(),
      albums: (result['album'] as List<dynamic>? ?? [])
          .map((a) => _parseAlbum(a as Map<String, dynamic>))
          .toList(),
      songs: (result['song'] as List<dynamic>? ?? [])
          .map((s) => _parseSong(s as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Media URIs ────────────────────────────────────────────────────────

  @override
  Uri getStreamUri(String songId, {int? maxBitRate, String? format}) {
    final params = <String, String>{
      ..._authParams(),
      'id': songId,
    };
    if (maxBitRate != null) params['maxBitRate'] = maxBitRate.toString();
    if (format != null) params['format'] = format;

    return Uri.parse('${server.baseUrl}/rest/stream').replace(
      queryParameters: params,
    );
  }

  @override
  Uri getCoverArtUri(String id, {int? size}) {
    final params = <String, String>{
      ..._authParams(),
      'id': id,
    };
    if (size != null) params['size'] = size.toString();

    return Uri.parse('${server.baseUrl}/rest/getCoverArt').replace(
      queryParameters: params,
    );
  }

  // ── Lyrics ────────────────────────────────────────────────────────────

  @override
  Future<String?> getLyrics({String? artist, String? title}) async {
    final params = <String, dynamic>{};
    if (artist != null) params['artist'] = artist;
    if (title != null) params['title'] = title;

    final data = await _get('getLyrics', params);
    final lyrics = data['lyrics'] as Map<String, dynamic>?;
    return lyrics?['value'] as String?;
  }

  /// Time-synced lyrics via the OpenSubsonic `songLyrics` extension.
  ///
  /// Servers without the extension answer with an error rather than an empty
  /// list, so a failure here means "no lyrics", not "broken" — the caller can
  /// still fall back to [getLyrics].
  @override
  Future<Lyrics?> getSongLyrics(String songId) async {
    try {
      final data = await _get('getLyricsBySongId', {'id': songId});
      return Lyrics.fromLyricsList(data['lyricsList'] as Map<String, dynamic>?);
    } catch (_) {
      return null;
    }
  }

  // ── Annotations ───────────────────────────────────────────────────────

  @override
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    final params = <String, dynamic>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    await _get('star', params);
  }

  @override
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    final params = <String, dynamic>{};
    if (id != null) params['id'] = id;
    if (albumId != null) params['albumId'] = albumId;
    if (artistId != null) params['artistId'] = artistId;
    await _get('unstar', params);
  }

  @override
  Future<void> setRating(String id, int rating) async {
    await _get('setRating', {'id': id, 'rating': rating});
  }

  @override
  Future<void> scrobble(String id, {bool submission = true}) async {
    await _get('scrobble', {'id': id, 'submission': submission});
  }

  // ── Playlists ─────────────────────────────────────────────────────────

  @override
  Future<List<Playlist>> getPlaylists() async {
    final data = await _get('getPlaylists');
    final list = (data['playlists'] as Map<String, dynamic>)['playlist']
            as List<dynamic>? ??
        [];
    return list.map((p) => _parsePlaylist(p as Map<String, dynamic>)).toList();
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    final data = await _get('getPlaylist', {'id': id});
    return _parsePlaylist(data['playlist'] as Map<String, dynamic>);
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final data = await _get('getPlaylist', {'id': playlistId});
    final playlist = data['playlist'] as Map<String, dynamic>;
    final entries = playlist['entry'] as List<dynamic>? ?? [];
    return entries
        .map((s) => _parseSong(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> createPlaylist({
    required String name,
    List<String>? songIds,
  }) async {
    final params = <String, dynamic>{'name': name};
    if (songIds != null && songIds.isNotEmpty) {
      params['songId'] = songIds;
    }
    await _get('createPlaylist', params);
  }

  @override
  Future<void> updatePlaylist(
    String id, {
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final params = <String, dynamic>{'playlistId': id};
    if (name != null) params['name'] = name;
    if (comment != null) params['comment'] = comment;
    if (public != null) params['public'] = public;
    if (songIdsToAdd != null) params['songIdToAdd'] = songIdsToAdd;
    if (songIndexesToRemove != null) {
      params['songIndexToRemove'] = songIndexesToRemove;
    }
    await _get('updatePlaylist', params);
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _get('deletePlaylist', {'id': id});
  }

  // ── Play queue ────────────────────────────────────────────────────────

  @override
  Future<void> savePlayQueue(
    List<String> songIds,
    String currentId,
    int positionMs,
  ) async {
    await _get('savePlayQueue', {
      'id': songIds,
      'current': currentId,
      'position': positionMs,
    });
  }

  @override
  Future<PlayQueue?> getPlayQueue() async {
    try {
      final data = await _get('getPlayQueue', {});
      final pq = data['playQueue'] as Map<String, dynamic>?;
      if (pq == null) return null;

      final entries = pq['entry'] as List<dynamic>? ?? [];
      final songs = entries
          .map((e) => _parseSong(e as Map<String, dynamic>))
          .toList();

      if (songs.isEmpty) return null;

      return PlayQueue(
        songs: songs,
        currentId: pq['current'] as String?,
        positionMs: pq['position'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Artist info ───────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getArtistInfo(String id) async {
    try {
      final data = await _get('getArtistInfo2', {'id': id, 'count': 10});
      return data['artistInfo2'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<ArtistInfo?> getArtistInfoParsed(String id) async {
    final raw = await getArtistInfo(id);
    if (raw == null) return null;

    final similar = <SimilarArtist>[];
    final similarList = raw['similarArtist'] as List<dynamic>? ?? [];
    for (final s in similarList) {
      final m = s as Map<String, dynamic>;
      similar.add(SimilarArtist(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        coverArtId: m['coverArt'] as String? ?? m['artistImageUrl'] as String?,
      ));
    }

    return ArtistInfo(
      biography: raw['biography'] as String?,
      musicBrainzId: raw['musicBrainzId'] as String?,
      lastFmUrl: raw['lastFmUrl'] as String?,
      smallImageUrl: raw['smallImageUrl'] as String?,
      mediumImageUrl: raw['mediumImageUrl'] as String?,
      largeImageUrl: raw['largeImageUrl'] as String?,
      similarArtists: similar,
    );
  }

  // ── Similar / Top songs ───────────────────────────────────────────────

  @override
  Future<List<Song>> getSimilarSongs(String id, {int count = 50}) async {
    final data = await _get('getSimilarSongs2', {'id': id, 'count': count});
    final songs = (data['similarSongs2'] as Map<String, dynamic>)['song']
            as List<dynamic>? ??
        [];
    return songs.map((s) => _parseSong(s as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Song>> getTopSongs(String artistName, {int count = 50}) async {
    final data = await _get('getTopSongs', {'artist': artistName, 'count': count});
    final songs = (data['topSongs'] as Map<String, dynamic>)['song']
            as List<dynamic>? ??
        [];
    return songs.map((s) => _parseSong(s as Map<String, dynamic>)).toList();
  }

  // ── Random songs ──────────────────────────────────────────────────────

  @override
  Future<List<Song>> getRandomSongs({int count = 20, String? genre}) async {
    final params = <String, dynamic>{'size': count};
    if (genre != null) params['genre'] = genre;
    final data = await _get('getRandomSongs', params);
    final songs = (data['randomSongs'] as Map<String, dynamic>)['song']
            as List<dynamic>? ??
        [];
    return songs.map((s) => _parseSong(s as Map<String, dynamic>)).toList();
  }

  // ── Parsers ───────────────────────────────────────────────────────────

  /// Whether a search hit is an artist worth listing.
  ///
  /// Navidrome's search3 matches credit participants as well as album artists —
  /// songwriters, session performers, alternate legal names — so searching "liz"
  /// returned Lizzo alongside ten people with no music in the library, including
  /// "Melissa \"Lizzo\" Jefferson", her songwriting credit. Its browse index has
  /// none of them: of 1286 artists there, zero have no albums. Filtering to match
  /// therefore hides nothing that browsing could otherwise reach.
  ///
  /// A missing albumCount is kept rather than dropped. Navidrome always sends it,
  /// but a Subsonic server that omits the field would otherwise have every artist
  /// filtered out of its search results.
  @visibleForTesting
  static bool hasSearchableAlbums(Map<String, dynamic> json) {
    final count = json['albumCount'] as int?;
    return count == null || count > 0;
  }

  Artist _parseArtist(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      serverId: server.id,
      name: json['name'] as String? ?? '',
      sortName: json['sortName'] as String?,
      coverArtId: json['coverArt'] as String? ?? json['artistImageUrl'] as String?,
      albumCount: json['albumCount'] as int? ?? 0,
      starred: json['starred'] != null,
      starredAt: json['starred'] != null
          ? DateTime.tryParse(json['starred'] as String)
          : null,
      userRating: json['userRating'] as int?,
      musicBrainzId: json['musicBrainzId'] as String?,
    );
  }

  Album _parseAlbum(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      serverId: server.id,
      artistId: json['artistId'] as String?,
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      artistName: json['artist'] as String?,
      coverArtId: json['coverArt'] as String?,
      songCount: json['songCount'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      year: json['year'] as int?,
      genre: json['genre'] as String?,
      starred: json['starred'] != null,
      starredAt: json['starred'] != null
          ? DateTime.tryParse(json['starred'] as String)
          : null,
      userRating: json['userRating'] as int?,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String)
          : null,
      musicBrainzId: json['musicBrainzId'] as String?,
    );
  }

  Song _parseSong(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      serverId: server.id,
      albumId: json['albumId'] as String?,
      artistId: json['artistId'] as String?,
      title: json['title'] as String? ?? '',
      artistName: json['artist'] as String?,
      albumName: json['album'] as String?,
      coverArtId: json['coverArt'] as String?,
      duration: json['duration'] as int? ?? 0,
      track: json['track'] as int?,
      discNumber: json['discNumber'] as int?,
      year: json['year'] as int?,
      genre: json['genre'] as String?,
      bitRate: json['bitRate'] as int?,
      bitDepth: json['bitDepth'] as int?,
      sampleRate: json['samplingRate'] as int?,
      channelCount: json['channelCount'] as int?,
      suffix: json['suffix'] as String?,
      contentType: json['contentType'] as String?,
      size: json['size'] as int?,
      starred: json['starred'] != null,
      starredAt: json['starred'] != null
          ? DateTime.tryParse(json['starred'] as String)
          : null,
      userRating: json['userRating'] as int?,
      playCount: json['playCount'] as int? ?? 0,
      replayGainTrackGain: _toDouble((json['replayGain'] as Map<String, dynamic>?)?['trackGain']),
      replayGainTrackPeak: _toDouble((json['replayGain'] as Map<String, dynamic>?)?['trackPeak']),
      replayGainAlbumGain: _toDouble((json['replayGain'] as Map<String, dynamic>?)?['albumGain']),
      replayGainAlbumPeak: _toDouble((json['replayGain'] as Map<String, dynamic>?)?['albumPeak']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Playlist _parsePlaylist(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      serverId: server.id,
      name: json['name'] as String? ?? '',
      comment: json['comment'] as String?,
      songCount: json['songCount'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      public: json['public'] as bool? ?? false,
      ownerId: json['owner'] as String?,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String)
          : null,
      changed: json['changed'] != null
          ? DateTime.tryParse(json['changed'] as String)
          : null,
      coverArtId: json['coverArt'] as String?,
    );
  }
}

class SubsonicException implements Exception {
  final int code;
  final String message;

  const SubsonicException({required this.code, required this.message});

  @override
  String toString() => 'SubsonicException($code): $message';
}
