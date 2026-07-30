import 'package:dio/dio.dart';
import 'package:flax/domain/models/models.dart';

class MusicBrainzService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://musicbrainz.org/ws/2',
    headers: {
      'User-Agent': 'Flax/1.0.0 (https://github.com/flax-music/flax)',
      'Accept': 'application/json',
    },
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static final _cache = <String, MusicBrainzArtistInfo>{};

  /// Fetch artist info by MusicBrainz ID. No API key required.
  static Future<MusicBrainzArtistInfo?> getArtistInfo(String mbid) async {
    if (_cache.containsKey(mbid)) return _cache[mbid];

    try {
      final response = await _dio.get(
        '/artist/$mbid',
        queryParameters: {'fmt': 'json', 'inc': 'tags'},
      );

      final data = response.data as Map<String, dynamic>;

      final tags = <String>[];
      final tagList = data['tags'] as List<dynamic>? ?? [];
      // Sort tags by count descending, take top ones
      final sortedTags = List<Map<String, dynamic>>.from(tagList);
      sortedTags.sort((a, b) =>
          (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
      for (final tag in sortedTags.take(8)) {
        tags.add(tag['name'] as String);
      }

      final area = data['area'] as Map<String, dynamic>?;
      final lifeSpan = data['life-span'] as Map<String, dynamic>?;

      final info = MusicBrainzArtistInfo(
        country: area?['name'] as String? ?? data['country'] as String?,
        type: data['type'] as String?,
        beginDate: lifeSpan?['begin'] as String?,
        endDate: lifeSpan?['end'] as String?,
        ended: lifeSpan?['ended'] as bool?,
        tags: tags,
      );

      _cache[mbid] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Search for an artist by name and return MusicBrainz info.
  static Future<MusicBrainzArtistInfo?> searchArtist(String name) async {
    try {
      final response = await _dio.get(
        '/artist',
        queryParameters: {
          'query': 'artist:"$name"',
          'fmt': 'json',
          'limit': 1,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final artists = data['artists'] as List<dynamic>? ?? [];
      if (artists.isEmpty) return null;

      final artist = artists.first as Map<String, dynamic>;
      final mbid = artist['id'] as String?;
      if (mbid == null) return null;

      // Fetch full info with tags
      return getArtistInfo(mbid);
    } catch (_) {
      return null;
    }
  }
}
