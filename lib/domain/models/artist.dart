class Artist {
  final String id;
  final String serverId;
  final String name;
  final String? sortName;
  final String? coverArtId;
  final int albumCount;
  final bool starred;
  final DateTime? starredAt;

  /// 0-5 star rating, independent of [starred]. Navidrome exposes both for
  /// artists, and Subsonic's setRating accepts an artist id like any other.
  final int? userRating;
  final String? musicBrainzId;
  final String? biography;
  final String? imageUrl;
  final List<String>? genres;

  const Artist({
    required this.id,
    required this.serverId,
    required this.name,
    this.sortName,
    this.coverArtId,
    this.albumCount = 0,
    this.starred = false,
    this.starredAt,
    this.userRating,
    this.musicBrainzId,
    this.biography,
    this.imageUrl,
    this.genres,
  });

  Artist copyWith({
    String? id,
    String? serverId,
    String? name,
    String? sortName,
    String? coverArtId,
    int? albumCount,
    bool? starred,
    DateTime? starredAt,
    int? userRating,
    String? musicBrainzId,
    String? biography,
    String? imageUrl,
    List<String>? genres,
  }) {
    return Artist(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      sortName: sortName ?? this.sortName,
      coverArtId: coverArtId ?? this.coverArtId,
      albumCount: albumCount ?? this.albumCount,
      starred: starred ?? this.starred,
      starredAt: starredAt ?? this.starredAt,
      userRating: userRating ?? this.userRating,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      biography: biography ?? this.biography,
      imageUrl: imageUrl ?? this.imageUrl,
      genres: genres ?? this.genres,
    );
  }
}
