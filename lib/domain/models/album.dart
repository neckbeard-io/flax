class Album {
  final String id;
  final String serverId;
  final String? artistId;
  final String name;
  final String? artistName;
  final String? coverArtId;
  final int songCount;
  final int duration;
  final int? year;
  final String? genre;
  final bool starred;
  final DateTime? starredAt;
  final int? userRating;
  final DateTime? created;
  final String? musicBrainzId;

  const Album({
    required this.id,
    required this.serverId,
    required this.name,
    this.artistId,
    this.artistName,
    this.coverArtId,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.genre,
    this.starred = false,
    this.starredAt,
    this.userRating,
    this.created,
    this.musicBrainzId,
  });

  Album copyWith({
    String? id,
    String? serverId,
    String? artistId,
    String? name,
    String? artistName,
    String? coverArtId,
    int? songCount,
    int? duration,
    int? year,
    String? genre,
    bool? starred,
    DateTime? starredAt,
    int? userRating,
    DateTime? created,
    String? musicBrainzId,
  }) {
    return Album(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      artistId: artistId ?? this.artistId,
      name: name ?? this.name,
      artistName: artistName ?? this.artistName,
      coverArtId: coverArtId ?? this.coverArtId,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      starred: starred ?? this.starred,
      starredAt: starredAt ?? this.starredAt,
      userRating: userRating ?? this.userRating,
      created: created ?? this.created,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
    );
  }
}
