/// Row <-> domain conversion. Issue #8.
///
/// The companions built here follow one rule that the rest of the design leans
/// on: **a null domain value is written as [Value.absent], never as null.**
///
/// Entities arrive from several endpoints at different levels of detail. A song
/// inside a search result carries a title and an id but no ReplayGain, no bit
/// depth and no disc number; the same song from `getAlbum` carries all of it. If
/// the thinner record wrote nulls it would erase the fuller one, and which
/// version you got would depend on whether you had searched recently. Absent
/// columns are left alone by the upsert instead, so records merge rather than
/// overwrite.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/database.dart';

Artist artistFromRow(ArtistRow r) => Artist(
  id: r.id,
  serverId: r.serverId,
  name: r.name,
  sortName: r.sortName,
  coverArtId: r.coverArtId,
  albumCount: r.albumCount,
  starred: r.starred,
  starredAt: r.starredAt,
  userRating: r.userRating,
  musicBrainzId: r.musicBrainzId,
  biography: r.biography,
  imageUrl: r.imageUrl,
  genres: _decodeGenres(r.genresJson),
);

ArtistsCompanion artistToCompanion(Artist a, DateTime now) => ArtistsCompanion(
  serverId: Value(a.serverId),
  id: Value(a.id),
  name: Value(a.name),
  sortName: _absentIfNull(a.sortName),
  coverArtId: _absentIfNull(a.coverArtId),
  // A list response carries a real album count; a search hit does not and
  // reports zero. Zero is indistinguishable from "not told", so it is dropped
  // rather than allowed to wipe a known count.
  albumCount: a.albumCount > 0 ? Value(a.albumCount) : const Value.absent(),
  starred: Value(a.starred),
  starredAt: _absentIfNull(a.starredAt),
  userRating: _absentIfNull(a.userRating),
  musicBrainzId: _absentIfNull(a.musicBrainzId),
  biography: _absentIfNull(a.biography),
  imageUrl: _absentIfNull(a.imageUrl),
  genresJson: a.genres == null || a.genres!.isEmpty
      ? const Value.absent()
      : Value(jsonEncode(a.genres)),
  fetchedAt: Value(now),
  lastSeenAt: Value(now),
);

Album albumFromRow(AlbumRow r) => Album(
  id: r.id,
  serverId: r.serverId,
  artistId: r.artistId,
  name: r.name,
  artistName: r.artistName,
  coverArtId: r.coverArtId,
  songCount: r.songCount,
  duration: r.duration,
  year: r.year,
  genre: r.genre,
  starred: r.starred,
  starredAt: r.starredAt,
  userRating: r.userRating,
  created: r.created,
  musicBrainzId: r.musicBrainzId,
);

AlbumsCompanion albumToCompanion(Album a, DateTime now) => AlbumsCompanion(
  serverId: Value(a.serverId),
  id: Value(a.id),
  artistId: _absentIfNull(a.artistId),
  name: Value(a.name),
  artistName: _absentIfNull(a.artistName),
  coverArtId: _absentIfNull(a.coverArtId),
  songCount: a.songCount > 0 ? Value(a.songCount) : const Value.absent(),
  duration: a.duration > 0 ? Value(a.duration) : const Value.absent(),
  year: _absentIfNull(a.year),
  genre: _absentIfNull(a.genre),
  starred: Value(a.starred),
  starredAt: _absentIfNull(a.starredAt),
  userRating: _absentIfNull(a.userRating),
  created: _absentIfNull(a.created),
  musicBrainzId: _absentIfNull(a.musicBrainzId),
  fetchedAt: Value(now),
  lastSeenAt: Value(now),
);

Song songFromRow(SongRow r) => Song(
  id: r.id,
  serverId: r.serverId,
  albumId: r.albumId,
  artistId: r.artistId,
  title: r.title,
  artistName: r.artistName,
  albumName: r.albumName,
  coverArtId: r.coverArtId,
  duration: r.duration,
  track: r.track,
  discNumber: r.discNumber,
  year: r.year,
  genre: r.genre,
  bitRate: r.bitRate,
  bitDepth: r.bitDepth,
  sampleRate: r.sampleRate,
  channelCount: r.channelCount,
  suffix: r.suffix,
  contentType: r.contentType,
  size: r.size,
  starred: r.starred,
  starredAt: r.starredAt,
  userRating: r.userRating,
  playCount: r.playCount,
  replayGainTrackGain: r.replayGainTrackGain,
  replayGainTrackPeak: r.replayGainTrackPeak,
  replayGainAlbumGain: r.replayGainAlbumGain,
  replayGainAlbumPeak: r.replayGainAlbumPeak,
  localPath: r.localPath,
  downloadState: DownloadState
      .values[r.downloadState.clamp(0, DownloadState.values.length - 1)],
);

SongsCompanion songToCompanion(Song s, DateTime now) => SongsCompanion(
  serverId: Value(s.serverId),
  id: Value(s.id),
  albumId: _absentIfNull(s.albumId),
  artistId: _absentIfNull(s.artistId),
  title: Value(s.title),
  artistName: _absentIfNull(s.artistName),
  albumName: _absentIfNull(s.albumName),
  coverArtId: _absentIfNull(s.coverArtId),
  duration: s.duration > 0 ? Value(s.duration) : const Value.absent(),
  track: _absentIfNull(s.track),
  discNumber: _absentIfNull(s.discNumber),
  year: _absentIfNull(s.year),
  genre: _absentIfNull(s.genre),
  bitRate: _absentIfNull(s.bitRate),
  bitDepth: _absentIfNull(s.bitDepth),
  sampleRate: _absentIfNull(s.sampleRate),
  channelCount: _absentIfNull(s.channelCount),
  suffix: _absentIfNull(s.suffix),
  contentType: _absentIfNull(s.contentType),
  size: _absentIfNull(s.size),
  starred: Value(s.starred),
  starredAt: _absentIfNull(s.starredAt),
  userRating: _absentIfNull(s.userRating),
  playCount: s.playCount > 0 ? Value(s.playCount) : const Value.absent(),
  replayGainTrackGain: _absentIfNull(s.replayGainTrackGain),
  replayGainTrackPeak: _absentIfNull(s.replayGainTrackPeak),
  replayGainAlbumGain: _absentIfNull(s.replayGainAlbumGain),
  replayGainAlbumPeak: _absentIfNull(s.replayGainAlbumPeak),
  // Deliberately not written from server responses: these are local state, and
  // a refresh must not reset a downloaded track to "not downloaded".
  fetchedAt: Value(now),
  lastSeenAt: Value(now),
);

Playlist playlistFromRow(PlaylistRow r) => Playlist(
  id: r.id,
  serverId: r.serverId,
  name: r.name,
  comment: r.comment,
  songCount: r.songCount,
  duration: r.duration,
  public: r.public,
  ownerId: r.ownerId,
  created: r.created,
  changed: r.changed,
  coverArtId: r.coverArtId,
);

PlaylistsCompanion playlistToCompanion(Playlist p, DateTime now) =>
    PlaylistsCompanion(
      serverId: Value(p.serverId),
      id: Value(p.id),
      name: Value(p.name),
      comment: _absentIfNull(p.comment),
      songCount: p.songCount > 0 ? Value(p.songCount) : const Value.absent(),
      duration: p.duration > 0 ? Value(p.duration) : const Value.absent(),
      public: Value(p.public),
      ownerId: _absentIfNull(p.ownerId),
      created: _absentIfNull(p.created),
      changed: _absentIfNull(p.changed),
      coverArtId: _absentIfNull(p.coverArtId),
      fetchedAt: Value(now),
      lastSeenAt: Value(now),
    );

Value<T> _absentIfNull<T extends Object>(T? value) =>
    value == null ? const Value.absent() : Value(value);

List<String>? _decodeGenres(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return null;
    return decoded.map((e) => e.toString()).toList();
  } catch (_) {
    // A corrupt cache should degrade to "no genres", not throw on every render.
    return null;
  }
}
