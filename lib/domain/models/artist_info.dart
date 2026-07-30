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
  final String? country;
  final String? type;
  final String? beginDate;
  final String? endDate;
  final bool? ended;
  final List<String> tags;

  const MusicBrainzArtistInfo({
    this.country,
    this.type,
    this.beginDate,
    this.endDate,
    this.ended,
    this.tags = const [],
  });

  String? get activeYears {
    if (beginDate == null) return null;
    final start = beginDate!.substring(0, 4);
    if (ended == true && endDate != null) {
      return '$start–${endDate!.substring(0, 4)}';
    }
    return '$start–present';
  }
}
