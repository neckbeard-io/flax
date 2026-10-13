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

  /// [similarArtists] without the ones with no albums here. Navidrome lists
  /// artists that only appear as track contributors, and their page is empty.
  List<SimilarArtist> get similarInLibrary =>
      similarArtists.where((a) => a.albumCount != 0).toList();
}

class SimilarArtist {
  final String id;
  final String name;
  final String? coverArtId;

  /// How many albums the server has for the artist, when it says. Navidrome
  /// lists artists that appear only as track contributors, with 0 here; their
  /// page has no albums on it.
  final int? albumCount;

  const SimilarArtist({
    required this.id,
    required this.name,
    this.coverArtId,
    this.albumCount,
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

  final String? explicitActiveYears;

  const MusicBrainzArtistInfo({
    this.country,
    this.countryCode,
    this.type,
    this.beginDate,
    this.endDate,
    this.ended,
    this.tags = const [],
    this.explicitActiveYears,
  });

  /// Country name for display, resolved from [countryCode] when possible.
  ///
  /// Falls back to the raw area name only when there is no usable code, so a
  /// city is shown rather than nothing at all.
  String? get countryLabel => countryName(countryCode) ?? country;

  String? get activeYears {
    if (explicitActiveYears != null) return explicitActiveYears;
    if (beginDate == null) return null;
    final start = beginDate!.length >= 4
        ? beginDate!.substring(0, 4)
        : beginDate!;
    if (ended == true && endDate != null) {
      final end = endDate!.length >= 4 ? endDate!.substring(0, 4) : endDate!;
      return '$start–$end';
    }
    return '$start–present';
  }
}
