class Playlist {
  final String id;
  final String serverId;
  final String name;
  final String? comment;
  final int songCount;
  final int duration;
  final bool public;
  final String? ownerId;
  final DateTime? created;
  final DateTime? changed;
  final String? coverArtId;

  const Playlist({
    required this.id,
    required this.serverId,
    required this.name,
    this.comment,
    this.songCount = 0,
    this.duration = 0,
    this.public = false,
    this.ownerId,
    this.created,
    this.changed,
    this.coverArtId,
  });

  Playlist copyWith({
    String? id,
    String? serverId,
    String? name,
    String? comment,
    int? songCount,
    int? duration,
    bool? public,
    String? ownerId,
    DateTime? created,
    DateTime? changed,
    String? coverArtId,
  }) {
    return Playlist(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      public: public ?? this.public,
      ownerId: ownerId ?? this.ownerId,
      created: created ?? this.created,
      changed: changed ?? this.changed,
      coverArtId: coverArtId ?? this.coverArtId,
    );
  }
}
