import 'package:flax/domain/enums.dart';

class Song {
  final String id;
  final String serverId;
  final String? albumId;
  final String? artistId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? coverArtId;
  final int duration;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int? bitRate;
  final int? bitDepth;
  final int? sampleRate;
  final int? channelCount;
  final String? suffix;
  final String? contentType;
  final int? size;
  final bool starred;
  final DateTime? starredAt;
  final int? userRating;
  final int playCount;
  final double? replayGainTrackGain;
  final double? replayGainTrackPeak;
  final double? replayGainAlbumGain;
  final double? replayGainAlbumPeak;
  final String? localPath;
  final DownloadState downloadState;

  const Song({
    required this.id,
    required this.serverId,
    required this.title,
    this.albumId,
    this.artistId,
    this.artistName,
    this.albumName,
    this.coverArtId,
    this.duration = 0,
    this.track,
    this.discNumber,
    this.year,
    this.genre,
    this.bitRate,
    this.bitDepth,
    this.sampleRate,
    this.channelCount,
    this.suffix,
    this.contentType,
    this.size,
    this.starred = false,
    this.starredAt,
    this.userRating,
    this.playCount = 0,
    this.replayGainTrackGain,
    this.replayGainTrackPeak,
    this.replayGainAlbumGain,
    this.replayGainAlbumPeak,
    this.localPath,
    this.downloadState = DownloadState.none,
  });

  bool get isAvailableOffline =>
      downloadState == DownloadState.complete && localPath != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverId': serverId,
    'title': title,
    if (albumId != null) 'albumId': albumId,
    if (artistId != null) 'artistId': artistId,
    if (artistName != null) 'artistName': artistName,
    if (albumName != null) 'albumName': albumName,
    if (coverArtId != null) 'coverArtId': coverArtId,
    'duration': duration,
    if (track != null) 'track': track,
    if (discNumber != null) 'discNumber': discNumber,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
    if (bitRate != null) 'bitRate': bitRate,
    if (bitDepth != null) 'bitDepth': bitDepth,
    if (sampleRate != null) 'sampleRate': sampleRate,
    if (channelCount != null) 'channelCount': channelCount,
    if (suffix != null) 'suffix': suffix,
    if (contentType != null) 'contentType': contentType,
    if (size != null) 'size': size,
    'starred': starred,
    if (userRating != null) 'userRating': userRating,
    'playCount': playCount,
    if (localPath != null) 'localPath': localPath,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    serverId: json['serverId'] as String,
    title: json['title'] as String? ?? '',
    albumId: json['albumId'] as String?,
    artistId: json['artistId'] as String?,
    artistName: json['artistName'] as String?,
    albumName: json['albumName'] as String?,
    coverArtId: json['coverArtId'] as String?,
    duration: json['duration'] as int? ?? 0,
    track: json['track'] as int?,
    discNumber: json['discNumber'] as int?,
    year: json['year'] as int?,
    genre: json['genre'] as String?,
    bitRate: json['bitRate'] as int?,
    bitDepth: json['bitDepth'] as int?,
    sampleRate: json['sampleRate'] as int?,
    channelCount: json['channelCount'] as int?,
    suffix: json['suffix'] as String?,
    contentType: json['contentType'] as String?,
    size: json['size'] as int?,
    starred: json['starred'] as bool? ?? false,
    userRating: json['userRating'] as int?,
    playCount: json['playCount'] as int? ?? 0,
    localPath: json['localPath'] as String?,
  );

  Song copyWith({
    String? id,
    String? serverId,
    String? albumId,
    String? artistId,
    String? title,
    String? artistName,
    String? albumName,
    String? coverArtId,
    int? duration,
    int? track,
    int? discNumber,
    int? year,
    String? genre,
    int? bitRate,
    int? bitDepth,
    int? sampleRate,
    int? channelCount,
    String? suffix,
    String? contentType,
    int? size,
    bool? starred,
    DateTime? starredAt,
    int? userRating,
    int? playCount,
    double? replayGainTrackGain,
    double? replayGainTrackPeak,
    double? replayGainAlbumGain,
    double? replayGainAlbumPeak,
    String? localPath,
    DownloadState? downloadState,
  }) {
    return Song(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      coverArtId: coverArtId ?? this.coverArtId,
      duration: duration ?? this.duration,
      track: track ?? this.track,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      bitRate: bitRate ?? this.bitRate,
      bitDepth: bitDepth ?? this.bitDepth,
      sampleRate: sampleRate ?? this.sampleRate,
      channelCount: channelCount ?? this.channelCount,
      suffix: suffix ?? this.suffix,
      contentType: contentType ?? this.contentType,
      size: size ?? this.size,
      starred: starred ?? this.starred,
      starredAt: starredAt ?? this.starredAt,
      userRating: userRating ?? this.userRating,
      playCount: playCount ?? this.playCount,
      replayGainTrackGain: replayGainTrackGain ?? this.replayGainTrackGain,
      replayGainTrackPeak: replayGainTrackPeak ?? this.replayGainTrackPeak,
      replayGainAlbumGain: replayGainAlbumGain ?? this.replayGainAlbumGain,
      replayGainAlbumPeak: replayGainAlbumPeak ?? this.replayGainAlbumPeak,
      localPath: localPath ?? this.localPath,
      downloadState: downloadState ?? this.downloadState,
    );
  }
}
