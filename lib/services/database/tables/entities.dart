/// Entity tables — the library as flax knows it. Issue #8.
///
/// Every table is keyed `(serverId, id)`. The domain models already carry
/// `serverId`, so this is multi-server from the start: switching servers changes
/// a filter rather than wiping anything, and two servers with colliding entity
/// ids cannot see each other's rows.
///
/// Three columns repeat on every entity and carry the sync machinery:
///
/// - `fetchedAt` — when this row was last written from a server response.
/// - `lastSeenAt` — when a server last mentioned it, which drives garbage
///   collection of things deleted upstream.
/// - `dirty` — a local write the server has not accepted yet.
///
/// The generated data classes are named `*Row` so they do not collide with the
/// domain models in `lib/domain/models/`, which remain what the UI reads.
library;

import 'package:drift/drift.dart';

@DataClassName('ArtistRow')
@TableIndex(name: 'artist_sort', columns: {#serverId, #sortName})
class Artists extends Table {
  TextColumn get serverId => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sortName => text().nullable()();
  TextColumn get coverArtId => text().nullable()();
  IntColumn get albumCount => integer().withDefault(const Constant(0))();

  /// Stars and hearts are two independent fields on the same row, never two
  /// views of one. `starred` is the favorite flag written by star/unstar;
  /// `userRating` is the 0-5 rating written by setRating. Nothing in the DAO
  /// layer may let a write to one touch the other.
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  DateTimeColumn get starredAt => dateTime().nullable()();
  IntColumn get userRating => integer().nullable()();

  TextColumn get musicBrainzId => text().nullable()();
  TextColumn get biography => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  /// JSON array. Genres are a short unordered list per artist and are never
  /// queried on their own, so a join table would cost more than it returns.
  TextColumn get genresJson => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serverId, id};
}

@DataClassName('AlbumRow')
@TableIndex(name: 'album_artist', columns: {#serverId, #artistId})
@TableIndex(name: 'album_name', columns: {#serverId, #name})
class Albums extends Table {
  TextColumn get serverId => text()();
  TextColumn get id => text()();
  TextColumn get artistId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get coverArtId => text().nullable()();
  IntColumn get songCount => integer().withDefault(const Constant(0))();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();

  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  DateTimeColumn get starredAt => dateTime().nullable()();
  IntColumn get userRating => integer().nullable()();

  DateTimeColumn get created => dateTime().nullable()();
  TextColumn get musicBrainzId => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serverId, id};
}

@DataClassName('SongRow')
@TableIndex(name: 'song_album', columns: {#serverId, #albumId})
@TableIndex(name: 'song_title', columns: {#serverId, #title})
class Songs extends Table {
  TextColumn get serverId => text()();
  TextColumn get id => text()();
  TextColumn get albumId => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get albumName => text().nullable()();
  TextColumn get coverArtId => text().nullable()();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  IntColumn get track => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();

  IntColumn get bitRate => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get channelCount => integer().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get contentType => text().nullable()();
  IntColumn get size => integer().nullable()();

  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  DateTimeColumn get starredAt => dateTime().nullable()();
  IntColumn get userRating => integer().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();

  RealColumn get replayGainTrackGain => real().nullable()();
  RealColumn get replayGainTrackPeak => real().nullable()();
  RealColumn get replayGainAlbumGain => real().nullable()();
  RealColumn get replayGainAlbumPeak => real().nullable()();

  /// Already modelled on the domain `Song`, and written by nothing yet. The
  /// offline-download work fills these in without a schema change.
  TextColumn get localPath => text().nullable()();
  IntColumn get downloadState => integer().withDefault(const Constant(0))();

  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serverId, id};
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get serverId => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get comment => text().nullable()();
  IntColumn get songCount => integer().withDefault(const Constant(0))();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  BoolColumn get public => boolean().withDefault(const Constant(false))();
  TextColumn get ownerId => text().nullable()();
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get changed => dateTime().nullable()();
  TextColumn get coverArtId => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serverId, id};
}
