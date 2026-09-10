import 'package:dio/dio.dart';
import 'package:flax/domain/models/models.dart';

class MusicBrainzService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://musicbrainz.org/ws/2',
      headers: {
        'User-Agent': 'Flax/1.0.0 (https://github.com/flax-music/flax)',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static final _cache = <String, MusicBrainzArtistInfo>{};
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _throttle() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequest);
    if (elapsed < const Duration(milliseconds: 1050)) {
      await Future<void>.delayed(const Duration(milliseconds: 1050) - elapsed);
    }
    _lastRequest = DateTime.now();
  }

  static Future<Response<dynamic>?> _getWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _throttle();
        return await _dio.get<dynamic>(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        if (e.response?.statusCode == 503 && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Fetch artist info by MusicBrainz ID. No API key required.
  static Future<MusicBrainzArtistInfo?> getArtistInfo(String mbid) async {
    if (_cache.containsKey(mbid)) return _cache[mbid];

    try {
      final response = await _getWithRetry(
        '/artist/$mbid',
        queryParameters: {'fmt': 'json', 'inc': 'tags'},
      );
      if (response == null) return null;

      final data = response.data as Map<String, dynamic>;

      final tags = <String>[];
      final tagList = data['tags'] as List<dynamic>? ?? [];
      // Sort tags by count descending, take top ones
      final sortedTags = List<Map<String, dynamic>>.from(tagList);
      sortedTags.sort(
        (a, b) => (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0),
      );
      for (final tag in sortedTags.take(8)) {
        tags.add(tag['name'] as String);
      }

      final area = data['area'] as Map<String, dynamic>?;
      final lifeSpan = data['life-span'] as Map<String, dynamic>?;

      // `country` is an alpha-2 code and is consistent; `area.name` is
      // whatever granularity MusicBrainz holds, which is why some artists
      // showed a country and others a city. A country-typed area also carries
      // its own iso-3166-1-codes, used when the top-level field is absent.
      final areaCodes = area?['iso-3166-1-codes'] as List<dynamic>?;
      final code =
          data['country'] as String? ??
          (areaCodes != null && areaCodes.isNotEmpty
              ? areaCodes.first as String?
              : null);

      final info = MusicBrainzArtistInfo(
        country: area?['name'] as String?,
        countryCode: code,
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
      final response = await _getWithRetry(
        '/artist',
        queryParameters: {'query': 'artist:"$name"', 'fmt': 'json', 'limit': 1},
      );
      if (response == null) return null;

      final data = response.data as Map<String, dynamic>;
      final artists = data['artists'] as List<dynamic>? ?? [];
      if (artists.isEmpty) return null;

      final artist = artists.first as Map<String, dynamic>;
      final mbid = artist['id'] as String?;
      if (mbid == null) return null;

      // Fetch full info with tags
      return await getArtistInfo(mbid);
    } catch (_) {
      return null;
    }
  }
}
