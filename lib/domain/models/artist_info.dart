import 'package:flax/shared/country.dart';

class ArtistInfo {
  final String? biography;
  final String? musicBrainzId;
  final String? lastFmUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final List<SimilarArtist> similarArtists;

  const ArtistInfo({
    this.biography,
    this.musicBrainzId,
    this.lastFmUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.similarArtists = const [],
  });

  String? get bestImageUrl => largeImageUrl ?? mediumImageUrl ?? smallImageUrl;
}

class SimilarArtist {
  final String id;
  final String name;
  final String? coverArtId;

  const SimilarArtist({
    required this.id,
    required this.name,
    this.coverArtId,
  });
}

class MusicBrainzArtistInfo {
  /// Free-text area name from MusicBrainz. Inconsistent by nature — a country
  /// for one artist, a city for the next — so prefer [countryLabel].
  final String? country;

  /// ISO 3166-1 alpha-2 code, which unlike [country] is uniform across artists.
  final String? countryCode;
  final String? type;
  final String? beginDate;
  final String? endDate;
  final bool? ended;
  final List<String> tags;

  const MusicBrainzArtistInfo({
    this.country,
    this.countryCode,
    this.type,
    this.beginDate,
    this.endDate,
    this.ended,
    this.tags = const [],
  });

  /// Country name for display, resolved from [countryCode] when possible.
  ///
  /// Falls back to the raw area name only when there is no usable code, so a
  /// city is shown rather than nothing at all.
  String? get countryLabel => countryName(countryCode) ?? country;

  String? get activeYears {
    if (beginDate == null) return null;
    final start = beginDate!.substring(0, 4);
    if (ended == true && endDate != null) {
      return '$start–${endDate!.substring(0, 4)}';
    }
    return '$start–present';
  }
}
