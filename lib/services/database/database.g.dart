// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, ArtistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortNameMeta = const VerificationMeta(
    'sortName',
  );
  @override
  late final GeneratedColumn<String> sortName = GeneratedColumn<String>(
    'sort_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumCountMeta = const VerificationMeta(
    'albumCount',
  );
  @override
  late final GeneratedColumn<int> albumCount = GeneratedColumn<int>(
    'album_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starredAtMeta = const VerificationMeta(
    'starredAt',
  );
  @override
  late final GeneratedColumn<DateTime> starredAt = GeneratedColumn<DateTime>(
    'starred_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userRatingMeta = const VerificationMeta(
    'userRating',
  );
  @override
  late final GeneratedColumn<int> userRating = GeneratedColumn<int>(
    'user_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musicBrainzIdMeta = const VerificationMeta(
    'musicBrainzId',
  );
  @override
  late final GeneratedColumn<String> musicBrainzId = GeneratedColumn<String>(
    'music_brainz_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _biographyMeta = const VerificationMeta(
    'biography',
  );
  @override
  late final GeneratedColumn<String> biography = GeneratedColumn<String>(
    'biography',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresJsonMeta = const VerificationMeta(
    'genresJson',
  );
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
    'genres_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    id,
    name,
    sortName,
    coverArtId,
    albumCount,
    starred,
    starredAt,
    userRating,
    musicBrainzId,
    biography,
    imageUrl,
    genresJson,
    fetchedAt,
    lastSeenAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_name')) {
      context.handle(
        _sortNameMeta,
        sortName.isAcceptableOrUnknown(data['sort_name']!, _sortNameMeta),
      );
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('album_count')) {
      context.handle(
        _albumCountMeta,
        albumCount.isAcceptableOrUnknown(data['album_count']!, _albumCountMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('starred_at')) {
      context.handle(
        _starredAtMeta,
        starredAt.isAcceptableOrUnknown(data['starred_at']!, _starredAtMeta),
      );
    }
    if (data.containsKey('user_rating')) {
      context.handle(
        _userRatingMeta,
        userRating.isAcceptableOrUnknown(data['user_rating']!, _userRatingMeta),
      );
    }
    if (data.containsKey('music_brainz_id')) {
      context.handle(
        _musicBrainzIdMeta,
        musicBrainzId.isAcceptableOrUnknown(
          data['music_brainz_id']!,
          _musicBrainzIdMeta,
        ),
      );
    }
    if (data.containsKey('biography')) {
      context.handle(
        _biographyMeta,
        biography.isAcceptableOrUnknown(data['biography']!, _biographyMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('genres_json')) {
      context.handle(
        _genresJsonMeta,
        genresJson.isAcceptableOrUnknown(data['genres_json']!, _genresJsonMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, id};
  @override
  ArtistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_name'],
      ),
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      albumCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}album_count'],
      )!,
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      starredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starred_at'],
      ),
      userRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_rating'],
      ),
      musicBrainzId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}music_brainz_id'],
      ),
      biography: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}biography'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      genresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_json'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class ArtistRow extends DataClass implements Insertable<ArtistRow> {
  final String serverId;
  final String id;
  final String name;
  final String? sortName;
  final String? coverArtId;
  final int albumCount;

  /// Stars and hearts are two independent fields on the same row, never two
  /// views of one. `starred` is the favorite flag written by star/unstar;
  /// `userRating` is the 0-5 rating written by setRating. Nothing in the DAO
  /// layer may let a write to one touch the other.
  final bool starred;
  final DateTime? starredAt;
  final int? userRating;
  final String? musicBrainzId;
  final String? biography;
  final String? imageUrl;

  /// JSON array. Genres are a short unordered list per artist and are never
  /// queried on their own, so a join table would cost more than it returns.
  final String? genresJson;
  final DateTime fetchedAt;
  final DateTime lastSeenAt;
  final bool dirty;
  const ArtistRow({
    required this.serverId,
    required this.id,
    required this.name,
    this.sortName,
    this.coverArtId,
    required this.albumCount,
    required this.starred,
    this.starredAt,
    this.userRating,
    this.musicBrainzId,
    this.biography,
    this.imageUrl,
    this.genresJson,
    required this.fetchedAt,
    required this.lastSeenAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sortName != null) {
      map['sort_name'] = Variable<String>(sortName);
    }
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    map['album_count'] = Variable<int>(albumCount);
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || starredAt != null) {
      map['starred_at'] = Variable<DateTime>(starredAt);
    }
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<int>(userRating);
    }
    if (!nullToAbsent || musicBrainzId != null) {
      map['music_brainz_id'] = Variable<String>(musicBrainzId);
    }
    if (!nullToAbsent || biography != null) {
      map['biography'] = Variable<String>(biography);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || genresJson != null) {
      map['genres_json'] = Variable<String>(genresJson);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      serverId: Value(serverId),
      id: Value(id),
      name: Value(name),
      sortName: sortName == null && nullToAbsent
          ? const Value.absent()
          : Value(sortName),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      albumCount: Value(albumCount),
      starred: Value(starred),
      starredAt: starredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(starredAt),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      musicBrainzId: musicBrainzId == null && nullToAbsent
          ? const Value.absent()
          : Value(musicBrainzId),
      biography: biography == null && nullToAbsent
          ? const Value.absent()
          : Value(biography),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      genresJson: genresJson == null && nullToAbsent
          ? const Value.absent()
          : Value(genresJson),
      fetchedAt: Value(fetchedAt),
      lastSeenAt: Value(lastSeenAt),
      dirty: Value(dirty),
    );
  }

  factory ArtistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortName: serializer.fromJson<String?>(json['sortName']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      albumCount: serializer.fromJson<int>(json['albumCount']),
      starred: serializer.fromJson<bool>(json['starred']),
      starredAt: serializer.fromJson<DateTime?>(json['starredAt']),
      userRating: serializer.fromJson<int?>(json['userRating']),
      musicBrainzId: serializer.fromJson<String?>(json['musicBrainzId']),
      biography: serializer.fromJson<String?>(json['biography']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      genresJson: serializer.fromJson<String?>(json['genresJson']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortName': serializer.toJson<String?>(sortName),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'albumCount': serializer.toJson<int>(albumCount),
      'starred': serializer.toJson<bool>(starred),
      'starredAt': serializer.toJson<DateTime?>(starredAt),
      'userRating': serializer.toJson<int?>(userRating),
      'musicBrainzId': serializer.toJson<String?>(musicBrainzId),
      'biography': serializer.toJson<String?>(biography),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'genresJson': serializer.toJson<String?>(genresJson),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  ArtistRow copyWith({
    String? serverId,
    String? id,
    String? name,
    Value<String?> sortName = const Value.absent(),
    Value<String?> coverArtId = const Value.absent(),
    int? albumCount,
    bool? starred,
    Value<DateTime?> starredAt = const Value.absent(),
    Value<int?> userRating = const Value.absent(),
    Value<String?> musicBrainzId = const Value.absent(),
    Value<String?> biography = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> genresJson = const Value.absent(),
    DateTime? fetchedAt,
    DateTime? lastSeenAt,
    bool? dirty,
  }) => ArtistRow(
    serverId: serverId ?? this.serverId,
    id: id ?? this.id,
    name: name ?? this.name,
    sortName: sortName.present ? sortName.value : this.sortName,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    albumCount: albumCount ?? this.albumCount,
    starred: starred ?? this.starred,
    starredAt: starredAt.present ? starredAt.value : this.starredAt,
    userRating: userRating.present ? userRating.value : this.userRating,
    musicBrainzId: musicBrainzId.present
        ? musicBrainzId.value
        : this.musicBrainzId,
    biography: biography.present ? biography.value : this.biography,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    genresJson: genresJson.present ? genresJson.value : this.genresJson,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    dirty: dirty ?? this.dirty,
  );
  ArtistRow copyWithCompanion(ArtistsCompanion data) {
    return ArtistRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortName: data.sortName.present ? data.sortName.value : this.sortName,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      albumCount: data.albumCount.present
          ? data.albumCount.value
          : this.albumCount,
      starred: data.starred.present ? data.starred.value : this.starred,
      starredAt: data.starredAt.present ? data.starredAt.value : this.starredAt,
      userRating: data.userRating.present
          ? data.userRating.value
          : this.userRating,
      musicBrainzId: data.musicBrainzId.present
          ? data.musicBrainzId.value
          : this.musicBrainzId,
      biography: data.biography.present ? data.biography.value : this.biography,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      genresJson: data.genresJson.present
          ? data.genresJson.value
          : this.genresJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistRow(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('albumCount: $albumCount, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('musicBrainzId: $musicBrainzId, ')
          ..write('biography: $biography, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('genresJson: $genresJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    id,
    name,
    sortName,
    coverArtId,
    albumCount,
    starred,
    starredAt,
    userRating,
    musicBrainzId,
    biography,
    imageUrl,
    genresJson,
    fetchedAt,
    lastSeenAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistRow &&
          other.serverId == this.serverId &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortName == this.sortName &&
          other.coverArtId == this.coverArtId &&
          other.albumCount == this.albumCount &&
          other.starred == this.starred &&
          other.starredAt == this.starredAt &&
          other.userRating == this.userRating &&
          other.musicBrainzId == this.musicBrainzId &&
          other.biography == this.biography &&
          other.imageUrl == this.imageUrl &&
          other.genresJson == this.genresJson &&
          other.fetchedAt == this.fetchedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.dirty == this.dirty);
}

class ArtistsCompanion extends UpdateCompanion<ArtistRow> {
  final Value<String> serverId;
  final Value<String> id;
  final Value<String> name;
  final Value<String?> sortName;
  final Value<String?> coverArtId;
  final Value<int> albumCount;
  final Value<bool> starred;
  final Value<DateTime?> starredAt;
  final Value<int?> userRating;
  final Value<String?> musicBrainzId;
  final Value<String?> biography;
  final Value<String?> imageUrl;
  final Value<String?> genresJson;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> lastSeenAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const ArtistsCompanion({
    this.serverId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.albumCount = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.musicBrainzId = const Value.absent(),
    this.biography = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistsCompanion.insert({
    required String serverId,
    required String id,
    required String name,
    this.sortName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.albumCount = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.musicBrainzId = const Value.absent(),
    this.biography = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.genresJson = const Value.absent(),
    required DateTime fetchedAt,
    required DateTime lastSeenAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       id = Value(id),
       name = Value(name),
       fetchedAt = Value(fetchedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<ArtistRow> custom({
    Expression<String>? serverId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sortName,
    Expression<String>? coverArtId,
    Expression<int>? albumCount,
    Expression<bool>? starred,
    Expression<DateTime>? starredAt,
    Expression<int>? userRating,
    Expression<String>? musicBrainzId,
    Expression<String>? biography,
    Expression<String>? imageUrl,
    Expression<String>? genresJson,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortName != null) 'sort_name': sortName,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (albumCount != null) 'album_count': albumCount,
      if (starred != null) 'starred': starred,
      if (starredAt != null) 'starred_at': starredAt,
      if (userRating != null) 'user_rating': userRating,
      if (musicBrainzId != null) 'music_brainz_id': musicBrainzId,
      if (biography != null) 'biography': biography,
      if (imageUrl != null) 'image_url': imageUrl,
      if (genresJson != null) 'genres_json': genresJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? id,
    Value<String>? name,
    Value<String?>? sortName,
    Value<String?>? coverArtId,
    Value<int>? albumCount,
    Value<bool>? starred,
    Value<DateTime?>? starredAt,
    Value<int?>? userRating,
    Value<String?>? musicBrainzId,
    Value<String?>? biography,
    Value<String?>? imageUrl,
    Value<String?>? genresJson,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? lastSeenAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return ArtistsCompanion(
      serverId: serverId ?? this.serverId,
      id: id ?? this.id,
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
      genresJson: genresJson ?? this.genresJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortName.present) {
      map['sort_name'] = Variable<String>(sortName.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (albumCount.present) {
      map['album_count'] = Variable<int>(albumCount.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (starredAt.present) {
      map['starred_at'] = Variable<DateTime>(starredAt.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<int>(userRating.value);
    }
    if (musicBrainzId.present) {
      map['music_brainz_id'] = Variable<String>(musicBrainzId.value);
    }
    if (biography.present) {
      map['biography'] = Variable<String>(biography.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('albumCount: $albumCount, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('musicBrainzId: $musicBrainzId, ')
          ..write('biography: $biography, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('genresJson: $genresJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, AlbumRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _songCountMeta = const VerificationMeta(
    'songCount',
  );
  @override
  late final GeneratedColumn<int> songCount = GeneratedColumn<int>(
    'song_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starredAtMeta = const VerificationMeta(
    'starredAt',
  );
  @override
  late final GeneratedColumn<DateTime> starredAt = GeneratedColumn<DateTime>(
    'starred_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userRatingMeta = const VerificationMeta(
    'userRating',
  );
  @override
  late final GeneratedColumn<int> userRating = GeneratedColumn<int>(
    'user_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musicBrainzIdMeta = const VerificationMeta(
    'musicBrainzId',
  );
  @override
  late final GeneratedColumn<String> musicBrainzId = GeneratedColumn<String>(
    'music_brainz_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    id,
    artistId,
    name,
    artistName,
    coverArtId,
    songCount,
    duration,
    year,
    genre,
    starred,
    starredAt,
    userRating,
    created,
    musicBrainzId,
    fetchedAt,
    lastSeenAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('song_count')) {
      context.handle(
        _songCountMeta,
        songCount.isAcceptableOrUnknown(data['song_count']!, _songCountMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('starred_at')) {
      context.handle(
        _starredAtMeta,
        starredAt.isAcceptableOrUnknown(data['starred_at']!, _starredAtMeta),
      );
    }
    if (data.containsKey('user_rating')) {
      context.handle(
        _userRatingMeta,
        userRating.isAcceptableOrUnknown(data['user_rating']!, _userRatingMeta),
      );
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    }
    if (data.containsKey('music_brainz_id')) {
      context.handle(
        _musicBrainzIdMeta,
        musicBrainzId.isAcceptableOrUnknown(
          data['music_brainz_id']!,
          _musicBrainzIdMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, id};
  @override
  AlbumRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      ),
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      songCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_count'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      starredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starred_at'],
      ),
      userRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_rating'],
      ),
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      ),
      musicBrainzId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}music_brainz_id'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class AlbumRow extends DataClass implements Insertable<AlbumRow> {
  final String serverId;
  final String id;
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
  final DateTime fetchedAt;
  final DateTime lastSeenAt;
  final bool dirty;
  const AlbumRow({
    required this.serverId,
    required this.id,
    this.artistId,
    required this.name,
    this.artistName,
    this.coverArtId,
    required this.songCount,
    required this.duration,
    this.year,
    this.genre,
    required this.starred,
    this.starredAt,
    this.userRating,
    this.created,
    this.musicBrainzId,
    required this.fetchedAt,
    required this.lastSeenAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || artistName != null) {
      map['artist_name'] = Variable<String>(artistName);
    }
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    map['song_count'] = Variable<int>(songCount);
    map['duration'] = Variable<int>(duration);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || starredAt != null) {
      map['starred_at'] = Variable<DateTime>(starredAt);
    }
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<int>(userRating);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<DateTime>(created);
    }
    if (!nullToAbsent || musicBrainzId != null) {
      map['music_brainz_id'] = Variable<String>(musicBrainzId);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      serverId: Value(serverId),
      id: Value(id),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      name: Value(name),
      artistName: artistName == null && nullToAbsent
          ? const Value.absent()
          : Value(artistName),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      songCount: Value(songCount),
      duration: Value(duration),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      starred: Value(starred),
      starredAt: starredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(starredAt),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      musicBrainzId: musicBrainzId == null && nullToAbsent
          ? const Value.absent()
          : Value(musicBrainzId),
      fetchedAt: Value(fetchedAt),
      lastSeenAt: Value(lastSeenAt),
      dirty: Value(dirty),
    );
  }

  factory AlbumRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      id: serializer.fromJson<String>(json['id']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      name: serializer.fromJson<String>(json['name']),
      artistName: serializer.fromJson<String?>(json['artistName']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      songCount: serializer.fromJson<int>(json['songCount']),
      duration: serializer.fromJson<int>(json['duration']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      starred: serializer.fromJson<bool>(json['starred']),
      starredAt: serializer.fromJson<DateTime?>(json['starredAt']),
      userRating: serializer.fromJson<int?>(json['userRating']),
      created: serializer.fromJson<DateTime?>(json['created']),
      musicBrainzId: serializer.fromJson<String?>(json['musicBrainzId']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'id': serializer.toJson<String>(id),
      'artistId': serializer.toJson<String?>(artistId),
      'name': serializer.toJson<String>(name),
      'artistName': serializer.toJson<String?>(artistName),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'songCount': serializer.toJson<int>(songCount),
      'duration': serializer.toJson<int>(duration),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'starred': serializer.toJson<bool>(starred),
      'starredAt': serializer.toJson<DateTime?>(starredAt),
      'userRating': serializer.toJson<int?>(userRating),
      'created': serializer.toJson<DateTime?>(created),
      'musicBrainzId': serializer.toJson<String?>(musicBrainzId),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  AlbumRow copyWith({
    String? serverId,
    String? id,
    Value<String?> artistId = const Value.absent(),
    String? name,
    Value<String?> artistName = const Value.absent(),
    Value<String?> coverArtId = const Value.absent(),
    int? songCount,
    int? duration,
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    bool? starred,
    Value<DateTime?> starredAt = const Value.absent(),
    Value<int?> userRating = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<String?> musicBrainzId = const Value.absent(),
    DateTime? fetchedAt,
    DateTime? lastSeenAt,
    bool? dirty,
  }) => AlbumRow(
    serverId: serverId ?? this.serverId,
    id: id ?? this.id,
    artistId: artistId.present ? artistId.value : this.artistId,
    name: name ?? this.name,
    artistName: artistName.present ? artistName.value : this.artistName,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    songCount: songCount ?? this.songCount,
    duration: duration ?? this.duration,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    starred: starred ?? this.starred,
    starredAt: starredAt.present ? starredAt.value : this.starredAt,
    userRating: userRating.present ? userRating.value : this.userRating,
    created: created.present ? created.value : this.created,
    musicBrainzId: musicBrainzId.present
        ? musicBrainzId.value
        : this.musicBrainzId,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    dirty: dirty ?? this.dirty,
  );
  AlbumRow copyWithCompanion(AlbumsCompanion data) {
    return AlbumRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      id: data.id.present ? data.id.value : this.id,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      name: data.name.present ? data.name.value : this.name,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      songCount: data.songCount.present ? data.songCount.value : this.songCount,
      duration: data.duration.present ? data.duration.value : this.duration,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      starred: data.starred.present ? data.starred.value : this.starred,
      starredAt: data.starredAt.present ? data.starredAt.value : this.starredAt,
      userRating: data.userRating.present
          ? data.userRating.value
          : this.userRating,
      created: data.created.present ? data.created.value : this.created,
      musicBrainzId: data.musicBrainzId.present
          ? data.musicBrainzId.value
          : this.musicBrainzId,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumRow(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('artistName: $artistName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('songCount: $songCount, ')
          ..write('duration: $duration, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('created: $created, ')
          ..write('musicBrainzId: $musicBrainzId, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    id,
    artistId,
    name,
    artistName,
    coverArtId,
    songCount,
    duration,
    year,
    genre,
    starred,
    starredAt,
    userRating,
    created,
    musicBrainzId,
    fetchedAt,
    lastSeenAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumRow &&
          other.serverId == this.serverId &&
          other.id == this.id &&
          other.artistId == this.artistId &&
          other.name == this.name &&
          other.artistName == this.artistName &&
          other.coverArtId == this.coverArtId &&
          other.songCount == this.songCount &&
          other.duration == this.duration &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.starred == this.starred &&
          other.starredAt == this.starredAt &&
          other.userRating == this.userRating &&
          other.created == this.created &&
          other.musicBrainzId == this.musicBrainzId &&
          other.fetchedAt == this.fetchedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.dirty == this.dirty);
}

class AlbumsCompanion extends UpdateCompanion<AlbumRow> {
  final Value<String> serverId;
  final Value<String> id;
  final Value<String?> artistId;
  final Value<String> name;
  final Value<String?> artistName;
  final Value<String?> coverArtId;
  final Value<int> songCount;
  final Value<int> duration;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<bool> starred;
  final Value<DateTime?> starredAt;
  final Value<int?> userRating;
  final Value<DateTime?> created;
  final Value<String?> musicBrainzId;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> lastSeenAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.serverId = const Value.absent(),
    this.id = const Value.absent(),
    this.artistId = const Value.absent(),
    this.name = const Value.absent(),
    this.artistName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.songCount = const Value.absent(),
    this.duration = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.created = const Value.absent(),
    this.musicBrainzId = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String serverId,
    required String id,
    this.artistId = const Value.absent(),
    required String name,
    this.artistName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.songCount = const Value.absent(),
    this.duration = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.created = const Value.absent(),
    this.musicBrainzId = const Value.absent(),
    required DateTime fetchedAt,
    required DateTime lastSeenAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       id = Value(id),
       name = Value(name),
       fetchedAt = Value(fetchedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<AlbumRow> custom({
    Expression<String>? serverId,
    Expression<String>? id,
    Expression<String>? artistId,
    Expression<String>? name,
    Expression<String>? artistName,
    Expression<String>? coverArtId,
    Expression<int>? songCount,
    Expression<int>? duration,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<bool>? starred,
    Expression<DateTime>? starredAt,
    Expression<int>? userRating,
    Expression<DateTime>? created,
    Expression<String>? musicBrainzId,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (id != null) 'id': id,
      if (artistId != null) 'artist_id': artistId,
      if (name != null) 'name': name,
      if (artistName != null) 'artist_name': artistName,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (songCount != null) 'song_count': songCount,
      if (duration != null) 'duration': duration,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (starred != null) 'starred': starred,
      if (starredAt != null) 'starred_at': starredAt,
      if (userRating != null) 'user_rating': userRating,
      if (created != null) 'created': created,
      if (musicBrainzId != null) 'music_brainz_id': musicBrainzId,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? id,
    Value<String?>? artistId,
    Value<String>? name,
    Value<String?>? artistName,
    Value<String?>? coverArtId,
    Value<int>? songCount,
    Value<int>? duration,
    Value<int?>? year,
    Value<String?>? genre,
    Value<bool>? starred,
    Value<DateTime?>? starredAt,
    Value<int?>? userRating,
    Value<DateTime?>? created,
    Value<String?>? musicBrainzId,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? lastSeenAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      serverId: serverId ?? this.serverId,
      id: id ?? this.id,
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
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (songCount.present) {
      map['song_count'] = Variable<int>(songCount.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (starredAt.present) {
      map['starred_at'] = Variable<DateTime>(starredAt.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<int>(userRating.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (musicBrainzId.present) {
      map['music_brainz_id'] = Variable<String>(musicBrainzId.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('artistId: $artistId, ')
          ..write('name: $name, ')
          ..write('artistName: $artistName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('songCount: $songCount, ')
          ..write('duration: $duration, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('created: $created, ')
          ..write('musicBrainzId: $musicBrainzId, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, SongRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<int> track = GeneratedColumn<int>(
    'track',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitRateMeta = const VerificationMeta(
    'bitRate',
  );
  @override
  late final GeneratedColumn<int> bitRate = GeneratedColumn<int>(
    'bit_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitDepthMeta = const VerificationMeta(
    'bitDepth',
  );
  @override
  late final GeneratedColumn<int> bitDepth = GeneratedColumn<int>(
    'bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelCountMeta = const VerificationMeta(
    'channelCount',
  );
  @override
  late final GeneratedColumn<int> channelCount = GeneratedColumn<int>(
    'channel_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
    'suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starredAtMeta = const VerificationMeta(
    'starredAt',
  );
  @override
  late final GeneratedColumn<DateTime> starredAt = GeneratedColumn<DateTime>(
    'starred_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userRatingMeta = const VerificationMeta(
    'userRating',
  );
  @override
  late final GeneratedColumn<int> userRating = GeneratedColumn<int>(
    'user_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _replayGainTrackGainMeta =
      const VerificationMeta('replayGainTrackGain');
  @override
  late final GeneratedColumn<double> replayGainTrackGain =
      GeneratedColumn<double>(
        'replay_gain_track_gain',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replayGainTrackPeakMeta =
      const VerificationMeta('replayGainTrackPeak');
  @override
  late final GeneratedColumn<double> replayGainTrackPeak =
      GeneratedColumn<double>(
        'replay_gain_track_peak',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replayGainAlbumGainMeta =
      const VerificationMeta('replayGainAlbumGain');
  @override
  late final GeneratedColumn<double> replayGainAlbumGain =
      GeneratedColumn<double>(
        'replay_gain_album_gain',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replayGainAlbumPeakMeta =
      const VerificationMeta('replayGainAlbumPeak');
  @override
  late final GeneratedColumn<double> replayGainAlbumPeak =
      GeneratedColumn<double>(
        'replay_gain_album_peak',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadStateMeta = const VerificationMeta(
    'downloadState',
  );
  @override
  late final GeneratedColumn<int> downloadState = GeneratedColumn<int>(
    'download_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    id,
    albumId,
    artistId,
    title,
    artistName,
    albumName,
    coverArtId,
    duration,
    track,
    discNumber,
    year,
    genre,
    bitRate,
    bitDepth,
    sampleRate,
    channelCount,
    suffix,
    contentType,
    size,
    starred,
    starredAt,
    userRating,
    playCount,
    replayGainTrackGain,
    replayGainTrackPeak,
    replayGainAlbumGain,
    replayGainAlbumPeak,
    localPath,
    downloadState,
    fetchedAt,
    lastSeenAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('track')) {
      context.handle(
        _trackMeta,
        track.isAcceptableOrUnknown(data['track']!, _trackMeta),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('bit_rate')) {
      context.handle(
        _bitRateMeta,
        bitRate.isAcceptableOrUnknown(data['bit_rate']!, _bitRateMeta),
      );
    }
    if (data.containsKey('bit_depth')) {
      context.handle(
        _bitDepthMeta,
        bitDepth.isAcceptableOrUnknown(data['bit_depth']!, _bitDepthMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('channel_count')) {
      context.handle(
        _channelCountMeta,
        channelCount.isAcceptableOrUnknown(
          data['channel_count']!,
          _channelCountMeta,
        ),
      );
    }
    if (data.containsKey('suffix')) {
      context.handle(
        _suffixMeta,
        suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('starred_at')) {
      context.handle(
        _starredAtMeta,
        starredAt.isAcceptableOrUnknown(data['starred_at']!, _starredAtMeta),
      );
    }
    if (data.containsKey('user_rating')) {
      context.handle(
        _userRatingMeta,
        userRating.isAcceptableOrUnknown(data['user_rating']!, _userRatingMeta),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('replay_gain_track_gain')) {
      context.handle(
        _replayGainTrackGainMeta,
        replayGainTrackGain.isAcceptableOrUnknown(
          data['replay_gain_track_gain']!,
          _replayGainTrackGainMeta,
        ),
      );
    }
    if (data.containsKey('replay_gain_track_peak')) {
      context.handle(
        _replayGainTrackPeakMeta,
        replayGainTrackPeak.isAcceptableOrUnknown(
          data['replay_gain_track_peak']!,
          _replayGainTrackPeakMeta,
        ),
      );
    }
    if (data.containsKey('replay_gain_album_gain')) {
      context.handle(
        _replayGainAlbumGainMeta,
        replayGainAlbumGain.isAcceptableOrUnknown(
          data['replay_gain_album_gain']!,
          _replayGainAlbumGainMeta,
        ),
      );
    }
    if (data.containsKey('replay_gain_album_peak')) {
      context.handle(
        _replayGainAlbumPeakMeta,
        replayGainAlbumPeak.isAcceptableOrUnknown(
          data['replay_gain_album_peak']!,
          _replayGainAlbumPeakMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('download_state')) {
      context.handle(
        _downloadStateMeta,
        downloadState.isAcceptableOrUnknown(
          data['download_state']!,
          _downloadStateMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, id};
  @override
  SongRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      ),
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      ),
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      track: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      bitRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_rate'],
      ),
      bitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_depth'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      channelCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_count'],
      ),
      suffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suffix'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      starredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starred_at'],
      ),
      userRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_rating'],
      ),
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      replayGainTrackGain: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_track_gain'],
      ),
      replayGainTrackPeak: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_track_peak'],
      ),
      replayGainAlbumGain: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_album_gain'],
      ),
      replayGainAlbumPeak: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_album_peak'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      downloadState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_state'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class SongRow extends DataClass implements Insertable<SongRow> {
  final String serverId;
  final String id;
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

  /// Already modelled on the domain `Song`, and written by nothing yet. The
  /// offline-download work fills these in without a schema change.
  final String? localPath;
  final int downloadState;
  final DateTime fetchedAt;
  final DateTime lastSeenAt;
  final bool dirty;
  const SongRow({
    required this.serverId,
    required this.id,
    this.albumId,
    this.artistId,
    required this.title,
    this.artistName,
    this.albumName,
    this.coverArtId,
    required this.duration,
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
    required this.starred,
    this.starredAt,
    this.userRating,
    required this.playCount,
    this.replayGainTrackGain,
    this.replayGainTrackPeak,
    this.replayGainAlbumGain,
    this.replayGainAlbumPeak,
    this.localPath,
    required this.downloadState,
    required this.fetchedAt,
    required this.lastSeenAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artistName != null) {
      map['artist_name'] = Variable<String>(artistName);
    }
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    map['duration'] = Variable<int>(duration);
    if (!nullToAbsent || track != null) {
      map['track'] = Variable<int>(track);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || bitRate != null) {
      map['bit_rate'] = Variable<int>(bitRate);
    }
    if (!nullToAbsent || bitDepth != null) {
      map['bit_depth'] = Variable<int>(bitDepth);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || channelCount != null) {
      map['channel_count'] = Variable<int>(channelCount);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || starredAt != null) {
      map['starred_at'] = Variable<DateTime>(starredAt);
    }
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<int>(userRating);
    }
    map['play_count'] = Variable<int>(playCount);
    if (!nullToAbsent || replayGainTrackGain != null) {
      map['replay_gain_track_gain'] = Variable<double>(replayGainTrackGain);
    }
    if (!nullToAbsent || replayGainTrackPeak != null) {
      map['replay_gain_track_peak'] = Variable<double>(replayGainTrackPeak);
    }
    if (!nullToAbsent || replayGainAlbumGain != null) {
      map['replay_gain_album_gain'] = Variable<double>(replayGainAlbumGain);
    }
    if (!nullToAbsent || replayGainAlbumPeak != null) {
      map['replay_gain_album_peak'] = Variable<double>(replayGainAlbumPeak);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['download_state'] = Variable<int>(downloadState);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      serverId: Value(serverId),
      id: Value(id),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      title: Value(title),
      artistName: artistName == null && nullToAbsent
          ? const Value.absent()
          : Value(artistName),
      albumName: albumName == null && nullToAbsent
          ? const Value.absent()
          : Value(albumName),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      duration: Value(duration),
      track: track == null && nullToAbsent
          ? const Value.absent()
          : Value(track),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      bitRate: bitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitRate),
      bitDepth: bitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(bitDepth),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      channelCount: channelCount == null && nullToAbsent
          ? const Value.absent()
          : Value(channelCount),
      suffix: suffix == null && nullToAbsent
          ? const Value.absent()
          : Value(suffix),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      starred: Value(starred),
      starredAt: starredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(starredAt),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      playCount: Value(playCount),
      replayGainTrackGain: replayGainTrackGain == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainTrackGain),
      replayGainTrackPeak: replayGainTrackPeak == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainTrackPeak),
      replayGainAlbumGain: replayGainAlbumGain == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainAlbumGain),
      replayGainAlbumPeak: replayGainAlbumPeak == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainAlbumPeak),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      downloadState: Value(downloadState),
      fetchedAt: Value(fetchedAt),
      lastSeenAt: Value(lastSeenAt),
      dirty: Value(dirty),
    );
  }

  factory SongRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      id: serializer.fromJson<String>(json['id']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      title: serializer.fromJson<String>(json['title']),
      artistName: serializer.fromJson<String?>(json['artistName']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      duration: serializer.fromJson<int>(json['duration']),
      track: serializer.fromJson<int?>(json['track']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      bitRate: serializer.fromJson<int?>(json['bitRate']),
      bitDepth: serializer.fromJson<int?>(json['bitDepth']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      channelCount: serializer.fromJson<int?>(json['channelCount']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      size: serializer.fromJson<int?>(json['size']),
      starred: serializer.fromJson<bool>(json['starred']),
      starredAt: serializer.fromJson<DateTime?>(json['starredAt']),
      userRating: serializer.fromJson<int?>(json['userRating']),
      playCount: serializer.fromJson<int>(json['playCount']),
      replayGainTrackGain: serializer.fromJson<double?>(
        json['replayGainTrackGain'],
      ),
      replayGainTrackPeak: serializer.fromJson<double?>(
        json['replayGainTrackPeak'],
      ),
      replayGainAlbumGain: serializer.fromJson<double?>(
        json['replayGainAlbumGain'],
      ),
      replayGainAlbumPeak: serializer.fromJson<double?>(
        json['replayGainAlbumPeak'],
      ),
      localPath: serializer.fromJson<String?>(json['localPath']),
      downloadState: serializer.fromJson<int>(json['downloadState']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'id': serializer.toJson<String>(id),
      'albumId': serializer.toJson<String?>(albumId),
      'artistId': serializer.toJson<String?>(artistId),
      'title': serializer.toJson<String>(title),
      'artistName': serializer.toJson<String?>(artistName),
      'albumName': serializer.toJson<String?>(albumName),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'duration': serializer.toJson<int>(duration),
      'track': serializer.toJson<int?>(track),
      'discNumber': serializer.toJson<int?>(discNumber),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'bitRate': serializer.toJson<int?>(bitRate),
      'bitDepth': serializer.toJson<int?>(bitDepth),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'channelCount': serializer.toJson<int?>(channelCount),
      'suffix': serializer.toJson<String?>(suffix),
      'contentType': serializer.toJson<String?>(contentType),
      'size': serializer.toJson<int?>(size),
      'starred': serializer.toJson<bool>(starred),
      'starredAt': serializer.toJson<DateTime?>(starredAt),
      'userRating': serializer.toJson<int?>(userRating),
      'playCount': serializer.toJson<int>(playCount),
      'replayGainTrackGain': serializer.toJson<double?>(replayGainTrackGain),
      'replayGainTrackPeak': serializer.toJson<double?>(replayGainTrackPeak),
      'replayGainAlbumGain': serializer.toJson<double?>(replayGainAlbumGain),
      'replayGainAlbumPeak': serializer.toJson<double?>(replayGainAlbumPeak),
      'localPath': serializer.toJson<String?>(localPath),
      'downloadState': serializer.toJson<int>(downloadState),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  SongRow copyWith({
    String? serverId,
    String? id,
    Value<String?> albumId = const Value.absent(),
    Value<String?> artistId = const Value.absent(),
    String? title,
    Value<String?> artistName = const Value.absent(),
    Value<String?> albumName = const Value.absent(),
    Value<String?> coverArtId = const Value.absent(),
    int? duration,
    Value<int?> track = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> bitRate = const Value.absent(),
    Value<int?> bitDepth = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> channelCount = const Value.absent(),
    Value<String?> suffix = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    Value<int?> size = const Value.absent(),
    bool? starred,
    Value<DateTime?> starredAt = const Value.absent(),
    Value<int?> userRating = const Value.absent(),
    int? playCount,
    Value<double?> replayGainTrackGain = const Value.absent(),
    Value<double?> replayGainTrackPeak = const Value.absent(),
    Value<double?> replayGainAlbumGain = const Value.absent(),
    Value<double?> replayGainAlbumPeak = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    int? downloadState,
    DateTime? fetchedAt,
    DateTime? lastSeenAt,
    bool? dirty,
  }) => SongRow(
    serverId: serverId ?? this.serverId,
    id: id ?? this.id,
    albumId: albumId.present ? albumId.value : this.albumId,
    artistId: artistId.present ? artistId.value : this.artistId,
    title: title ?? this.title,
    artistName: artistName.present ? artistName.value : this.artistName,
    albumName: albumName.present ? albumName.value : this.albumName,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    duration: duration ?? this.duration,
    track: track.present ? track.value : this.track,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    bitRate: bitRate.present ? bitRate.value : this.bitRate,
    bitDepth: bitDepth.present ? bitDepth.value : this.bitDepth,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    channelCount: channelCount.present ? channelCount.value : this.channelCount,
    suffix: suffix.present ? suffix.value : this.suffix,
    contentType: contentType.present ? contentType.value : this.contentType,
    size: size.present ? size.value : this.size,
    starred: starred ?? this.starred,
    starredAt: starredAt.present ? starredAt.value : this.starredAt,
    userRating: userRating.present ? userRating.value : this.userRating,
    playCount: playCount ?? this.playCount,
    replayGainTrackGain: replayGainTrackGain.present
        ? replayGainTrackGain.value
        : this.replayGainTrackGain,
    replayGainTrackPeak: replayGainTrackPeak.present
        ? replayGainTrackPeak.value
        : this.replayGainTrackPeak,
    replayGainAlbumGain: replayGainAlbumGain.present
        ? replayGainAlbumGain.value
        : this.replayGainAlbumGain,
    replayGainAlbumPeak: replayGainAlbumPeak.present
        ? replayGainAlbumPeak.value
        : this.replayGainAlbumPeak,
    localPath: localPath.present ? localPath.value : this.localPath,
    downloadState: downloadState ?? this.downloadState,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    dirty: dirty ?? this.dirty,
  );
  SongRow copyWithCompanion(SongsCompanion data) {
    return SongRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      id: data.id.present ? data.id.value : this.id,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      title: data.title.present ? data.title.value : this.title,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      duration: data.duration.present ? data.duration.value : this.duration,
      track: data.track.present ? data.track.value : this.track,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      bitRate: data.bitRate.present ? data.bitRate.value : this.bitRate,
      bitDepth: data.bitDepth.present ? data.bitDepth.value : this.bitDepth,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      channelCount: data.channelCount.present
          ? data.channelCount.value
          : this.channelCount,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      size: data.size.present ? data.size.value : this.size,
      starred: data.starred.present ? data.starred.value : this.starred,
      starredAt: data.starredAt.present ? data.starredAt.value : this.starredAt,
      userRating: data.userRating.present
          ? data.userRating.value
          : this.userRating,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      replayGainTrackGain: data.replayGainTrackGain.present
          ? data.replayGainTrackGain.value
          : this.replayGainTrackGain,
      replayGainTrackPeak: data.replayGainTrackPeak.present
          ? data.replayGainTrackPeak.value
          : this.replayGainTrackPeak,
      replayGainAlbumGain: data.replayGainAlbumGain.present
          ? data.replayGainAlbumGain.value
          : this.replayGainAlbumGain,
      replayGainAlbumPeak: data.replayGainAlbumPeak.present
          ? data.replayGainAlbumPeak.value
          : this.replayGainAlbumPeak,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      downloadState: data.downloadState.present
          ? data.downloadState.value
          : this.downloadState,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongRow(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('duration: $duration, ')
          ..write('track: $track, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('bitRate: $bitRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channelCount: $channelCount, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('size: $size, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('playCount: $playCount, ')
          ..write('replayGainTrackGain: $replayGainTrackGain, ')
          ..write('replayGainTrackPeak: $replayGainTrackPeak, ')
          ..write('replayGainAlbumGain: $replayGainAlbumGain, ')
          ..write('replayGainAlbumPeak: $replayGainAlbumPeak, ')
          ..write('localPath: $localPath, ')
          ..write('downloadState: $downloadState, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    serverId,
    id,
    albumId,
    artistId,
    title,
    artistName,
    albumName,
    coverArtId,
    duration,
    track,
    discNumber,
    year,
    genre,
    bitRate,
    bitDepth,
    sampleRate,
    channelCount,
    suffix,
    contentType,
    size,
    starred,
    starredAt,
    userRating,
    playCount,
    replayGainTrackGain,
    replayGainTrackPeak,
    replayGainAlbumGain,
    replayGainAlbumPeak,
    localPath,
    downloadState,
    fetchedAt,
    lastSeenAt,
    dirty,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongRow &&
          other.serverId == this.serverId &&
          other.id == this.id &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.title == this.title &&
          other.artistName == this.artistName &&
          other.albumName == this.albumName &&
          other.coverArtId == this.coverArtId &&
          other.duration == this.duration &&
          other.track == this.track &&
          other.discNumber == this.discNumber &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.bitRate == this.bitRate &&
          other.bitDepth == this.bitDepth &&
          other.sampleRate == this.sampleRate &&
          other.channelCount == this.channelCount &&
          other.suffix == this.suffix &&
          other.contentType == this.contentType &&
          other.size == this.size &&
          other.starred == this.starred &&
          other.starredAt == this.starredAt &&
          other.userRating == this.userRating &&
          other.playCount == this.playCount &&
          other.replayGainTrackGain == this.replayGainTrackGain &&
          other.replayGainTrackPeak == this.replayGainTrackPeak &&
          other.replayGainAlbumGain == this.replayGainAlbumGain &&
          other.replayGainAlbumPeak == this.replayGainAlbumPeak &&
          other.localPath == this.localPath &&
          other.downloadState == this.downloadState &&
          other.fetchedAt == this.fetchedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.dirty == this.dirty);
}

class SongsCompanion extends UpdateCompanion<SongRow> {
  final Value<String> serverId;
  final Value<String> id;
  final Value<String?> albumId;
  final Value<String?> artistId;
  final Value<String> title;
  final Value<String?> artistName;
  final Value<String?> albumName;
  final Value<String?> coverArtId;
  final Value<int> duration;
  final Value<int?> track;
  final Value<int?> discNumber;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<int?> bitRate;
  final Value<int?> bitDepth;
  final Value<int?> sampleRate;
  final Value<int?> channelCount;
  final Value<String?> suffix;
  final Value<String?> contentType;
  final Value<int?> size;
  final Value<bool> starred;
  final Value<DateTime?> starredAt;
  final Value<int?> userRating;
  final Value<int> playCount;
  final Value<double?> replayGainTrackGain;
  final Value<double?> replayGainTrackPeak;
  final Value<double?> replayGainAlbumGain;
  final Value<double?> replayGainAlbumPeak;
  final Value<String?> localPath;
  final Value<int> downloadState;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> lastSeenAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const SongsCompanion({
    this.serverId = const Value.absent(),
    this.id = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.duration = const Value.absent(),
    this.track = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channelCount = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.size = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.playCount = const Value.absent(),
    this.replayGainTrackGain = const Value.absent(),
    this.replayGainTrackPeak = const Value.absent(),
    this.replayGainAlbumGain = const Value.absent(),
    this.replayGainAlbumPeak = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadState = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String serverId,
    required String id,
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    required String title,
    this.artistName = const Value.absent(),
    this.albumName = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.duration = const Value.absent(),
    this.track = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.channelCount = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.size = const Value.absent(),
    this.starred = const Value.absent(),
    this.starredAt = const Value.absent(),
    this.userRating = const Value.absent(),
    this.playCount = const Value.absent(),
    this.replayGainTrackGain = const Value.absent(),
    this.replayGainTrackPeak = const Value.absent(),
    this.replayGainAlbumGain = const Value.absent(),
    this.replayGainAlbumPeak = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadState = const Value.absent(),
    required DateTime fetchedAt,
    required DateTime lastSeenAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       id = Value(id),
       title = Value(title),
       fetchedAt = Value(fetchedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<SongRow> custom({
    Expression<String>? serverId,
    Expression<String>? id,
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<String>? title,
    Expression<String>? artistName,
    Expression<String>? albumName,
    Expression<String>? coverArtId,
    Expression<int>? duration,
    Expression<int>? track,
    Expression<int>? discNumber,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<int>? bitRate,
    Expression<int>? bitDepth,
    Expression<int>? sampleRate,
    Expression<int>? channelCount,
    Expression<String>? suffix,
    Expression<String>? contentType,
    Expression<int>? size,
    Expression<bool>? starred,
    Expression<DateTime>? starredAt,
    Expression<int>? userRating,
    Expression<int>? playCount,
    Expression<double>? replayGainTrackGain,
    Expression<double>? replayGainTrackPeak,
    Expression<double>? replayGainAlbumGain,
    Expression<double>? replayGainAlbumPeak,
    Expression<String>? localPath,
    Expression<int>? downloadState,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (id != null) 'id': id,
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (title != null) 'title': title,
      if (artistName != null) 'artist_name': artistName,
      if (albumName != null) 'album_name': albumName,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (duration != null) 'duration': duration,
      if (track != null) 'track': track,
      if (discNumber != null) 'disc_number': discNumber,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (bitRate != null) 'bit_rate': bitRate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (channelCount != null) 'channel_count': channelCount,
      if (suffix != null) 'suffix': suffix,
      if (contentType != null) 'content_type': contentType,
      if (size != null) 'size': size,
      if (starred != null) 'starred': starred,
      if (starredAt != null) 'starred_at': starredAt,
      if (userRating != null) 'user_rating': userRating,
      if (playCount != null) 'play_count': playCount,
      if (replayGainTrackGain != null)
        'replay_gain_track_gain': replayGainTrackGain,
      if (replayGainTrackPeak != null)
        'replay_gain_track_peak': replayGainTrackPeak,
      if (replayGainAlbumGain != null)
        'replay_gain_album_gain': replayGainAlbumGain,
      if (replayGainAlbumPeak != null)
        'replay_gain_album_peak': replayGainAlbumPeak,
      if (localPath != null) 'local_path': localPath,
      if (downloadState != null) 'download_state': downloadState,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? id,
    Value<String?>? albumId,
    Value<String?>? artistId,
    Value<String>? title,
    Value<String?>? artistName,
    Value<String?>? albumName,
    Value<String?>? coverArtId,
    Value<int>? duration,
    Value<int?>? track,
    Value<int?>? discNumber,
    Value<int?>? year,
    Value<String?>? genre,
    Value<int?>? bitRate,
    Value<int?>? bitDepth,
    Value<int?>? sampleRate,
    Value<int?>? channelCount,
    Value<String?>? suffix,
    Value<String?>? contentType,
    Value<int?>? size,
    Value<bool>? starred,
    Value<DateTime?>? starredAt,
    Value<int?>? userRating,
    Value<int>? playCount,
    Value<double?>? replayGainTrackGain,
    Value<double?>? replayGainTrackPeak,
    Value<double?>? replayGainAlbumGain,
    Value<double?>? replayGainAlbumPeak,
    Value<String?>? localPath,
    Value<int>? downloadState,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? lastSeenAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      serverId: serverId ?? this.serverId,
      id: id ?? this.id,
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
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (track.present) {
      map['track'] = Variable<int>(track.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (bitRate.present) {
      map['bit_rate'] = Variable<int>(bitRate.value);
    }
    if (bitDepth.present) {
      map['bit_depth'] = Variable<int>(bitDepth.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (channelCount.present) {
      map['channel_count'] = Variable<int>(channelCount.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (starredAt.present) {
      map['starred_at'] = Variable<DateTime>(starredAt.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<int>(userRating.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (replayGainTrackGain.present) {
      map['replay_gain_track_gain'] = Variable<double>(
        replayGainTrackGain.value,
      );
    }
    if (replayGainTrackPeak.present) {
      map['replay_gain_track_peak'] = Variable<double>(
        replayGainTrackPeak.value,
      );
    }
    if (replayGainAlbumGain.present) {
      map['replay_gain_album_gain'] = Variable<double>(
        replayGainAlbumGain.value,
      );
    }
    if (replayGainAlbumPeak.present) {
      map['replay_gain_album_peak'] = Variable<double>(
        replayGainAlbumPeak.value,
      );
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (downloadState.present) {
      map['download_state'] = Variable<int>(downloadState.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumName: $albumName, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('duration: $duration, ')
          ..write('track: $track, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('bitRate: $bitRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('channelCount: $channelCount, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('size: $size, ')
          ..write('starred: $starred, ')
          ..write('starredAt: $starredAt, ')
          ..write('userRating: $userRating, ')
          ..write('playCount: $playCount, ')
          ..write('replayGainTrackGain: $replayGainTrackGain, ')
          ..write('replayGainTrackPeak: $replayGainTrackPeak, ')
          ..write('replayGainAlbumGain: $replayGainAlbumGain, ')
          ..write('replayGainAlbumPeak: $replayGainAlbumPeak, ')
          ..write('localPath: $localPath, ')
          ..write('downloadState: $downloadState, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _songCountMeta = const VerificationMeta(
    'songCount',
  );
  @override
  late final GeneratedColumn<int> songCount = GeneratedColumn<int>(
    'song_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _publicMeta = const VerificationMeta('public');
  @override
  late final GeneratedColumn<bool> public = GeneratedColumn<bool>(
    'public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("public" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedMeta = const VerificationMeta(
    'changed',
  );
  @override
  late final GeneratedColumn<DateTime> changed = GeneratedColumn<DateTime>(
    'changed',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    id,
    name,
    comment,
    songCount,
    duration,
    public,
    ownerId,
    created,
    changed,
    coverArtId,
    fetchedAt,
    lastSeenAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('song_count')) {
      context.handle(
        _songCountMeta,
        songCount.isAcceptableOrUnknown(data['song_count']!, _songCountMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('public')) {
      context.handle(
        _publicMeta,
        public.isAcceptableOrUnknown(data['public']!, _publicMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    }
    if (data.containsKey('changed')) {
      context.handle(
        _changedMeta,
        changed.isAcceptableOrUnknown(data['changed']!, _changedMeta),
      );
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      songCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_count'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      public: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}public'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      ),
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      ),
      changed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed'],
      ),
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final String serverId;
  final String id;
  final String name;
  final String? comment;
  final int songCount;
  final int duration;
  final bool public;
  final String? ownerId;
  final DateTime? created;
  final DateTime? changed;
  final String? coverArtId;
  final DateTime fetchedAt;
  final DateTime lastSeenAt;
  final bool dirty;
  const PlaylistRow({
    required this.serverId,
    required this.id,
    required this.name,
    this.comment,
    required this.songCount,
    required this.duration,
    required this.public,
    this.ownerId,
    this.created,
    this.changed,
    this.coverArtId,
    required this.fetchedAt,
    required this.lastSeenAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['song_count'] = Variable<int>(songCount);
    map['duration'] = Variable<int>(duration);
    map['public'] = Variable<bool>(public);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<DateTime>(created);
    }
    if (!nullToAbsent || changed != null) {
      map['changed'] = Variable<DateTime>(changed);
    }
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      serverId: Value(serverId),
      id: Value(id),
      name: Value(name),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      songCount: Value(songCount),
      duration: Value(duration),
      public: Value(public),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      changed: changed == null && nullToAbsent
          ? const Value.absent()
          : Value(changed),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      fetchedAt: Value(fetchedAt),
      lastSeenAt: Value(lastSeenAt),
      dirty: Value(dirty),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      comment: serializer.fromJson<String?>(json['comment']),
      songCount: serializer.fromJson<int>(json['songCount']),
      duration: serializer.fromJson<int>(json['duration']),
      public: serializer.fromJson<bool>(json['public']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      created: serializer.fromJson<DateTime?>(json['created']),
      changed: serializer.fromJson<DateTime?>(json['changed']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'comment': serializer.toJson<String?>(comment),
      'songCount': serializer.toJson<int>(songCount),
      'duration': serializer.toJson<int>(duration),
      'public': serializer.toJson<bool>(public),
      'ownerId': serializer.toJson<String?>(ownerId),
      'created': serializer.toJson<DateTime?>(created),
      'changed': serializer.toJson<DateTime?>(changed),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  PlaylistRow copyWith({
    String? serverId,
    String? id,
    String? name,
    Value<String?> comment = const Value.absent(),
    int? songCount,
    int? duration,
    bool? public,
    Value<String?> ownerId = const Value.absent(),
    Value<DateTime?> created = const Value.absent(),
    Value<DateTime?> changed = const Value.absent(),
    Value<String?> coverArtId = const Value.absent(),
    DateTime? fetchedAt,
    DateTime? lastSeenAt,
    bool? dirty,
  }) => PlaylistRow(
    serverId: serverId ?? this.serverId,
    id: id ?? this.id,
    name: name ?? this.name,
    comment: comment.present ? comment.value : this.comment,
    songCount: songCount ?? this.songCount,
    duration: duration ?? this.duration,
    public: public ?? this.public,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    created: created.present ? created.value : this.created,
    changed: changed.present ? changed.value : this.changed,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    dirty: dirty ?? this.dirty,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      comment: data.comment.present ? data.comment.value : this.comment,
      songCount: data.songCount.present ? data.songCount.value : this.songCount,
      duration: data.duration.present ? data.duration.value : this.duration,
      public: data.public.present ? data.public.value : this.public,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      created: data.created.present ? data.created.value : this.created,
      changed: data.changed.present ? data.changed.value : this.changed,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('comment: $comment, ')
          ..write('songCount: $songCount, ')
          ..write('duration: $duration, ')
          ..write('public: $public, ')
          ..write('ownerId: $ownerId, ')
          ..write('created: $created, ')
          ..write('changed: $changed, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    id,
    name,
    comment,
    songCount,
    duration,
    public,
    ownerId,
    created,
    changed,
    coverArtId,
    fetchedAt,
    lastSeenAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.serverId == this.serverId &&
          other.id == this.id &&
          other.name == this.name &&
          other.comment == this.comment &&
          other.songCount == this.songCount &&
          other.duration == this.duration &&
          other.public == this.public &&
          other.ownerId == this.ownerId &&
          other.created == this.created &&
          other.changed == this.changed &&
          other.coverArtId == this.coverArtId &&
          other.fetchedAt == this.fetchedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.dirty == this.dirty);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<String> serverId;
  final Value<String> id;
  final Value<String> name;
  final Value<String?> comment;
  final Value<int> songCount;
  final Value<int> duration;
  final Value<bool> public;
  final Value<String?> ownerId;
  final Value<DateTime?> created;
  final Value<DateTime?> changed;
  final Value<String?> coverArtId;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> lastSeenAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.serverId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.comment = const Value.absent(),
    this.songCount = const Value.absent(),
    this.duration = const Value.absent(),
    this.public = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.created = const Value.absent(),
    this.changed = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String serverId,
    required String id,
    required String name,
    this.comment = const Value.absent(),
    this.songCount = const Value.absent(),
    this.duration = const Value.absent(),
    this.public = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.created = const Value.absent(),
    this.changed = const Value.absent(),
    this.coverArtId = const Value.absent(),
    required DateTime fetchedAt,
    required DateTime lastSeenAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       id = Value(id),
       name = Value(name),
       fetchedAt = Value(fetchedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<PlaylistRow> custom({
    Expression<String>? serverId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? comment,
    Expression<int>? songCount,
    Expression<int>? duration,
    Expression<bool>? public,
    Expression<String>? ownerId,
    Expression<DateTime>? created,
    Expression<DateTime>? changed,
    Expression<String>? coverArtId,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (comment != null) 'comment': comment,
      if (songCount != null) 'song_count': songCount,
      if (duration != null) 'duration': duration,
      if (public != null) 'public': public,
      if (ownerId != null) 'owner_id': ownerId,
      if (created != null) 'created': created,
      if (changed != null) 'changed': changed,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? id,
    Value<String>? name,
    Value<String?>? comment,
    Value<int>? songCount,
    Value<int>? duration,
    Value<bool>? public,
    Value<String?>? ownerId,
    Value<DateTime?>? created,
    Value<DateTime?>? changed,
    Value<String?>? coverArtId,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? lastSeenAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      serverId: serverId ?? this.serverId,
      id: id ?? this.id,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      public: public ?? this.public,
      ownerId: ownerId ?? this.ownerId,
      created: created ?? this.created,
      changed: changed ?? this.changed,
      coverArtId: coverArtId ?? this.coverArtId,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (songCount.present) {
      map['song_count'] = Variable<int>(songCount.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (public.present) {
      map['public'] = Variable<bool>(public.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (changed.present) {
      map['changed'] = Variable<DateTime>(changed.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('comment: $comment, ')
          ..write('songCount: $songCount, ')
          ..write('duration: $duration, ')
          ..write('public: $public, ')
          ..write('ownerId: $ownerId, ')
          ..write('created: $created, ')
          ..write('changed: $changed, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumListEntriesTable extends AlbumListEntries
    with TableInfo<$AlbumListEntriesTable, AlbumListEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumListEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listTypeMeta = const VerificationMeta(
    'listType',
  );
  @override
  late final GeneratedColumn<String> listType = GeneratedColumn<String>(
    'list_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filterKeyMeta = const VerificationMeta(
    'filterKey',
  );
  @override
  late final GeneratedColumn<String> filterKey = GeneratedColumn<String>(
    'filter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    listType,
    filterKey,
    position,
    albumId,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'album_list_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumListEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('list_type')) {
      context.handle(
        _listTypeMeta,
        listType.isAcceptableOrUnknown(data['list_type']!, _listTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_listTypeMeta);
    }
    if (data.containsKey('filter_key')) {
      context.handle(
        _filterKeyMeta,
        filterKey.isAcceptableOrUnknown(data['filter_key']!, _filterKeyMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    serverId,
    listType,
    filterKey,
    position,
  };
  @override
  AlbumListEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumListEntryRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      listType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_type'],
      )!,
      filterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $AlbumListEntriesTable createAlias(String alias) {
    return $AlbumListEntriesTable(attachedDatabase, alias);
  }
}

class AlbumListEntryRow extends DataClass
    implements Insertable<AlbumListEntryRow> {
  final String serverId;

  /// The `AlbumListType` name — `newest`, `recent`, `alphabetical`, and so on.
  ///
  /// `random` never appears here. Caching an ordering called "random" produces
  /// a shelf that never reshuffles, so that type bypasses this table entirely.
  final String listType;

  /// Distinguishes otherwise identical lists that differ by filter — genre,
  /// year range. Empty string when the list takes no filter.
  final String filterKey;
  final int position;
  final String albumId;
  final DateTime fetchedAt;
  const AlbumListEntryRow({
    required this.serverId,
    required this.listType,
    required this.filterKey,
    required this.position,
    required this.albumId,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['list_type'] = Variable<String>(listType);
    map['filter_key'] = Variable<String>(filterKey);
    map['position'] = Variable<int>(position);
    map['album_id'] = Variable<String>(albumId);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  AlbumListEntriesCompanion toCompanion(bool nullToAbsent) {
    return AlbumListEntriesCompanion(
      serverId: Value(serverId),
      listType: Value(listType),
      filterKey: Value(filterKey),
      position: Value(position),
      albumId: Value(albumId),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory AlbumListEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumListEntryRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      listType: serializer.fromJson<String>(json['listType']),
      filterKey: serializer.fromJson<String>(json['filterKey']),
      position: serializer.fromJson<int>(json['position']),
      albumId: serializer.fromJson<String>(json['albumId']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'listType': serializer.toJson<String>(listType),
      'filterKey': serializer.toJson<String>(filterKey),
      'position': serializer.toJson<int>(position),
      'albumId': serializer.toJson<String>(albumId),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  AlbumListEntryRow copyWith({
    String? serverId,
    String? listType,
    String? filterKey,
    int? position,
    String? albumId,
    DateTime? fetchedAt,
  }) => AlbumListEntryRow(
    serverId: serverId ?? this.serverId,
    listType: listType ?? this.listType,
    filterKey: filterKey ?? this.filterKey,
    position: position ?? this.position,
    albumId: albumId ?? this.albumId,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  AlbumListEntryRow copyWithCompanion(AlbumListEntriesCompanion data) {
    return AlbumListEntryRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      listType: data.listType.present ? data.listType.value : this.listType,
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      position: data.position.present ? data.position.value : this.position,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumListEntryRow(')
          ..write('serverId: $serverId, ')
          ..write('listType: $listType, ')
          ..write('filterKey: $filterKey, ')
          ..write('position: $position, ')
          ..write('albumId: $albumId, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serverId, listType, filterKey, position, albumId, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumListEntryRow &&
          other.serverId == this.serverId &&
          other.listType == this.listType &&
          other.filterKey == this.filterKey &&
          other.position == this.position &&
          other.albumId == this.albumId &&
          other.fetchedAt == this.fetchedAt);
}

class AlbumListEntriesCompanion extends UpdateCompanion<AlbumListEntryRow> {
  final Value<String> serverId;
  final Value<String> listType;
  final Value<String> filterKey;
  final Value<int> position;
  final Value<String> albumId;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const AlbumListEntriesCompanion({
    this.serverId = const Value.absent(),
    this.listType = const Value.absent(),
    this.filterKey = const Value.absent(),
    this.position = const Value.absent(),
    this.albumId = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumListEntriesCompanion.insert({
    required String serverId,
    required String listType,
    this.filterKey = const Value.absent(),
    required int position,
    required String albumId,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       listType = Value(listType),
       position = Value(position),
       albumId = Value(albumId),
       fetchedAt = Value(fetchedAt);
  static Insertable<AlbumListEntryRow> custom({
    Expression<String>? serverId,
    Expression<String>? listType,
    Expression<String>? filterKey,
    Expression<int>? position,
    Expression<String>? albumId,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (listType != null) 'list_type': listType,
      if (filterKey != null) 'filter_key': filterKey,
      if (position != null) 'position': position,
      if (albumId != null) 'album_id': albumId,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumListEntriesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? listType,
    Value<String>? filterKey,
    Value<int>? position,
    Value<String>? albumId,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return AlbumListEntriesCompanion(
      serverId: serverId ?? this.serverId,
      listType: listType ?? this.listType,
      filterKey: filterKey ?? this.filterKey,
      position: position ?? this.position,
      albumId: albumId ?? this.albumId,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (listType.present) {
      map['list_type'] = Variable<String>(listType.value);
    }
    if (filterKey.present) {
      map['filter_key'] = Variable<String>(filterKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumListEntriesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('listType: $listType, ')
          ..write('filterKey: $filterKey, ')
          ..write('position: $position, ')
          ..write('albumId: $albumId, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    playlistId,
    position,
    songId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, playlistId, position};
  @override
  PlaylistEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntryRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntryRow extends DataClass
    implements Insertable<PlaylistEntryRow> {
  final String serverId;
  final String playlistId;
  final int position;
  final String songId;
  const PlaylistEntryRow({
    required this.serverId,
    required this.playlistId,
    required this.position,
    required this.songId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['playlist_id'] = Variable<String>(playlistId);
    map['position'] = Variable<int>(position);
    map['song_id'] = Variable<String>(songId);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      serverId: Value(serverId),
      playlistId: Value(playlistId),
      position: Value(position),
      songId: Value(songId),
    );
  }

  factory PlaylistEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntryRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      position: serializer.fromJson<int>(json['position']),
      songId: serializer.fromJson<String>(json['songId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'playlistId': serializer.toJson<String>(playlistId),
      'position': serializer.toJson<int>(position),
      'songId': serializer.toJson<String>(songId),
    };
  }

  PlaylistEntryRow copyWith({
    String? serverId,
    String? playlistId,
    int? position,
    String? songId,
  }) => PlaylistEntryRow(
    serverId: serverId ?? this.serverId,
    playlistId: playlistId ?? this.playlistId,
    position: position ?? this.position,
    songId: songId ?? this.songId,
  );
  PlaylistEntryRow copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntryRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      position: data.position.present ? data.position.value : this.position,
      songId: data.songId.present ? data.songId.value : this.songId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntryRow(')
          ..write('serverId: $serverId, ')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('songId: $songId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, playlistId, position, songId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntryRow &&
          other.serverId == this.serverId &&
          other.playlistId == this.playlistId &&
          other.position == this.position &&
          other.songId == this.songId);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntryRow> {
  final Value<String> serverId;
  final Value<String> playlistId;
  final Value<int> position;
  final Value<String> songId;
  final Value<int> rowid;
  const PlaylistEntriesCompanion({
    this.serverId = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.position = const Value.absent(),
    this.songId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    required String serverId,
    required String playlistId,
    required int position,
    required String songId,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       playlistId = Value(playlistId),
       position = Value(position),
       songId = Value(songId);
  static Insertable<PlaylistEntryRow> custom({
    Expression<String>? serverId,
    Expression<String>? playlistId,
    Expression<int>? position,
    Expression<String>? songId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (playlistId != null) 'playlist_id': playlistId,
      if (position != null) 'position': position,
      if (songId != null) 'song_id': songId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistEntriesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? playlistId,
    Value<int>? position,
    Value<String>? songId,
    Value<int>? rowid,
  }) {
    return PlaylistEntriesCompanion(
      serverId: serverId ?? this.serverId,
      playlistId: playlistId ?? this.playlistId,
      position: position ?? this.position,
      songId: songId ?? this.songId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('songId: $songId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String serverId;
  final String key;
  final String? value;
  final DateTime updatedAt;
  const SyncStateRow({
    required this.serverId,
    required this.key,
    this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      serverId: Value(serverId),
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncStateRow copyWith({
    String? serverId,
    String? key,
    Value<String?> value = const Value.absent(),
    DateTime? updatedAt,
  }) => SyncStateRow(
    serverId: serverId ?? this.serverId,
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('serverId: $serverId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.serverId == this.serverId &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> serverId;
  final Value<String> key;
  final Value<String?> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.serverId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String serverId,
    required String key,
    this.value = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       key = Value(key),
       updatedAt = Value(updatedAt);
  static Insertable<SyncStateRow> custom({
    Expression<String>? serverId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? key,
    Value<String?>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      serverId: serverId ?? this.serverId,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FlaxDatabase extends GeneratedDatabase {
  _$FlaxDatabase(QueryExecutor e) : super(e);
  $FlaxDatabaseManager get managers => $FlaxDatabaseManager(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $AlbumListEntriesTable albumListEntries = $AlbumListEntriesTable(
    this,
  );
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(
    this,
  );
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final Index artistSort = Index(
    'artist_sort',
    'CREATE INDEX artist_sort ON artists (server_id, sort_name)',
  );
  late final Index albumArtist = Index(
    'album_artist',
    'CREATE INDEX album_artist ON albums (server_id, artist_id)',
  );
  late final Index albumName = Index(
    'album_name',
    'CREATE INDEX album_name ON albums (server_id, name)',
  );
  late final Index songAlbum = Index(
    'song_album',
    'CREATE INDEX song_album ON songs (server_id, album_id)',
  );
  late final Index songTitle = Index(
    'song_title',
    'CREATE INDEX song_title ON songs (server_id, title)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    artists,
    albums,
    songs,
    playlists,
    albumListEntries,
    playlistEntries,
    syncStates,
    artistSort,
    albumArtist,
    albumName,
    songAlbum,
    songTitle,
  ];
}

typedef $$ArtistsTableCreateCompanionBuilder =
    ArtistsCompanion Function({
      required String serverId,
      required String id,
      required String name,
      Value<String?> sortName,
      Value<String?> coverArtId,
      Value<int> albumCount,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<String?> musicBrainzId,
      Value<String?> biography,
      Value<String?> imageUrl,
      Value<String?> genresJson,
      required DateTime fetchedAt,
      required DateTime lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$ArtistsTableUpdateCompanionBuilder =
    ArtistsCompanion Function({
      Value<String> serverId,
      Value<String> id,
      Value<String> name,
      Value<String?> sortName,
      Value<String?> coverArtId,
      Value<int> albumCount,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<String?> musicBrainzId,
      Value<String?> biography,
      Value<String?> imageUrl,
      Value<String?> genresJson,
      Value<DateTime> fetchedAt,
      Value<DateTime> lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$ArtistsTableFilterComposer
    extends Composer<_$FlaxDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get albumCount => $composableBuilder(
    column: $table.albumCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get biography => $composableBuilder(
    column: $table.biography,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$FlaxDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get albumCount => $composableBuilder(
    column: $table.albumCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get biography => $composableBuilder(
    column: $table.biography,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sortName =>
      $composableBuilder(column: $table.sortName, builder: (column) => column);

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get albumCount => $composableBuilder(
    column: $table.albumCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<DateTime> get starredAt =>
      $composableBuilder(column: $table.starredAt, builder: (column) => column);

  GeneratedColumn<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get biography =>
      $composableBuilder(column: $table.biography, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $ArtistsTable,
          ArtistRow,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (ArtistRow, BaseReferences<_$FlaxDatabase, $ArtistsTable, ArtistRow>),
          ArtistRow,
          PrefetchHooks Function()
        > {
  $$ArtistsTableTableManager(_$FlaxDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sortName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> albumCount = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<String?> musicBrainzId = const Value.absent(),
                Value<String?> biography = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> genresJson = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion(
                serverId: serverId,
                id: id,
                name: name,
                sortName: sortName,
                coverArtId: coverArtId,
                albumCount: albumCount,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                musicBrainzId: musicBrainzId,
                biography: biography,
                imageUrl: imageUrl,
                genresJson: genresJson,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String id,
                required String name,
                Value<String?> sortName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> albumCount = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<String?> musicBrainzId = const Value.absent(),
                Value<String?> biography = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> genresJson = const Value.absent(),
                required DateTime fetchedAt,
                required DateTime lastSeenAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion.insert(
                serverId: serverId,
                id: id,
                name: name,
                sortName: sortName,
                coverArtId: coverArtId,
                albumCount: albumCount,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                musicBrainzId: musicBrainzId,
                biography: biography,
                imageUrl: imageUrl,
                genresJson: genresJson,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $ArtistsTable,
      ArtistRow,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (ArtistRow, BaseReferences<_$FlaxDatabase, $ArtistsTable, ArtistRow>),
      ArtistRow,
      PrefetchHooks Function()
    >;
typedef $$AlbumsTableCreateCompanionBuilder =
    AlbumsCompanion Function({
      required String serverId,
      required String id,
      Value<String?> artistId,
      required String name,
      Value<String?> artistName,
      Value<String?> coverArtId,
      Value<int> songCount,
      Value<int> duration,
      Value<int?> year,
      Value<String?> genre,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<DateTime?> created,
      Value<String?> musicBrainzId,
      required DateTime fetchedAt,
      required DateTime lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$AlbumsTableUpdateCompanionBuilder =
    AlbumsCompanion Function({
      Value<String> serverId,
      Value<String> id,
      Value<String?> artistId,
      Value<String> name,
      Value<String?> artistName,
      Value<String?> coverArtId,
      Value<int> songCount,
      Value<int> duration,
      Value<int?> year,
      Value<String?> genre,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<DateTime?> created,
      Value<String?> musicBrainzId,
      Value<DateTime> fetchedAt,
      Value<DateTime> lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$AlbumsTableFilterComposer
    extends Composer<_$FlaxDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get songCount => $composableBuilder(
    column: $table.songCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$FlaxDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get songCount => $composableBuilder(
    column: $table.songCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get songCount =>
      $composableBuilder(column: $table.songCount, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<DateTime> get starredAt =>
      $composableBuilder(column: $table.starredAt, builder: (column) => column);

  GeneratedColumn<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get musicBrainzId => $composableBuilder(
    column: $table.musicBrainzId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $AlbumsTable,
          AlbumRow,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (AlbumRow, BaseReferences<_$FlaxDatabase, $AlbumsTable, AlbumRow>),
          AlbumRow,
          PrefetchHooks Function()
        > {
  $$AlbumsTableTableManager(_$FlaxDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> artistName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> songCount = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<String?> musicBrainzId = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion(
                serverId: serverId,
                id: id,
                artistId: artistId,
                name: name,
                artistName: artistName,
                coverArtId: coverArtId,
                songCount: songCount,
                duration: duration,
                year: year,
                genre: genre,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                created: created,
                musicBrainzId: musicBrainzId,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String id,
                Value<String?> artistId = const Value.absent(),
                required String name,
                Value<String?> artistName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> songCount = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<String?> musicBrainzId = const Value.absent(),
                required DateTime fetchedAt,
                required DateTime lastSeenAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion.insert(
                serverId: serverId,
                id: id,
                artistId: artistId,
                name: name,
                artistName: artistName,
                coverArtId: coverArtId,
                songCount: songCount,
                duration: duration,
                year: year,
                genre: genre,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                created: created,
                musicBrainzId: musicBrainzId,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $AlbumsTable,
      AlbumRow,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (AlbumRow, BaseReferences<_$FlaxDatabase, $AlbumsTable, AlbumRow>),
      AlbumRow,
      PrefetchHooks Function()
    >;
typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      required String serverId,
      required String id,
      Value<String?> albumId,
      Value<String?> artistId,
      required String title,
      Value<String?> artistName,
      Value<String?> albumName,
      Value<String?> coverArtId,
      Value<int> duration,
      Value<int?> track,
      Value<int?> discNumber,
      Value<int?> year,
      Value<String?> genre,
      Value<int?> bitRate,
      Value<int?> bitDepth,
      Value<int?> sampleRate,
      Value<int?> channelCount,
      Value<String?> suffix,
      Value<String?> contentType,
      Value<int?> size,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<int> playCount,
      Value<double?> replayGainTrackGain,
      Value<double?> replayGainTrackPeak,
      Value<double?> replayGainAlbumGain,
      Value<double?> replayGainAlbumPeak,
      Value<String?> localPath,
      Value<int> downloadState,
      required DateTime fetchedAt,
      required DateTime lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<String> serverId,
      Value<String> id,
      Value<String?> albumId,
      Value<String?> artistId,
      Value<String> title,
      Value<String?> artistName,
      Value<String?> albumName,
      Value<String?> coverArtId,
      Value<int> duration,
      Value<int?> track,
      Value<int?> discNumber,
      Value<int?> year,
      Value<String?> genre,
      Value<int?> bitRate,
      Value<int?> bitDepth,
      Value<int?> sampleRate,
      Value<int?> channelCount,
      Value<String?> suffix,
      Value<String?> contentType,
      Value<int?> size,
      Value<bool> starred,
      Value<DateTime?> starredAt,
      Value<int?> userRating,
      Value<int> playCount,
      Value<double?> replayGainTrackGain,
      Value<double?> replayGainTrackPeak,
      Value<double?> replayGainAlbumGain,
      Value<double?> replayGainAlbumPeak,
      Value<String?> localPath,
      Value<int> downloadState,
      Value<DateTime> fetchedAt,
      Value<DateTime> lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$SongsTableFilterComposer extends Composer<_$FlaxDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitRate => $composableBuilder(
    column: $table.bitRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainTrackGain => $composableBuilder(
    column: $table.replayGainTrackGain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainTrackPeak => $composableBuilder(
    column: $table.replayGainTrackPeak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainAlbumGain => $composableBuilder(
    column: $table.replayGainAlbumGain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainAlbumPeak => $composableBuilder(
    column: $table.replayGainAlbumPeak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SongsTableOrderingComposer
    extends Composer<_$FlaxDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get track => $composableBuilder(
    column: $table.track,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitRate => $composableBuilder(
    column: $table.bitRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get starredAt => $composableBuilder(
    column: $table.starredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainTrackGain => $composableBuilder(
    column: $table.replayGainTrackGain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainTrackPeak => $composableBuilder(
    column: $table.replayGainTrackPeak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainAlbumGain => $composableBuilder(
    column: $table.replayGainAlbumGain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainAlbumPeak => $composableBuilder(
    column: $table.replayGainAlbumPeak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongsTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get bitRate =>
      $composableBuilder(column: $table.bitRate, builder: (column) => column);

  GeneratedColumn<int> get bitDepth =>
      $composableBuilder(column: $table.bitDepth, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<DateTime> get starredAt =>
      $composableBuilder(column: $table.starredAt, builder: (column) => column);

  GeneratedColumn<int> get userRating => $composableBuilder(
    column: $table.userRating,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<double> get replayGainTrackGain => $composableBuilder(
    column: $table.replayGainTrackGain,
    builder: (column) => column,
  );

  GeneratedColumn<double> get replayGainTrackPeak => $composableBuilder(
    column: $table.replayGainTrackPeak,
    builder: (column) => column,
  );

  GeneratedColumn<double> get replayGainAlbumGain => $composableBuilder(
    column: $table.replayGainAlbumGain,
    builder: (column) => column,
  );

  GeneratedColumn<double> get replayGainAlbumPeak => $composableBuilder(
    column: $table.replayGainAlbumPeak,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $SongsTable,
          SongRow,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (SongRow, BaseReferences<_$FlaxDatabase, $SongsTable, SongRow>),
          SongRow,
          PrefetchHooks Function()
        > {
  $$SongsTableTableManager(_$FlaxDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> albumId = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artistName = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int?> track = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> bitRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channelCount = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<double?> replayGainTrackGain = const Value.absent(),
                Value<double?> replayGainTrackPeak = const Value.absent(),
                Value<double?> replayGainAlbumGain = const Value.absent(),
                Value<double?> replayGainAlbumPeak = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> downloadState = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion(
                serverId: serverId,
                id: id,
                albumId: albumId,
                artistId: artistId,
                title: title,
                artistName: artistName,
                albumName: albumName,
                coverArtId: coverArtId,
                duration: duration,
                track: track,
                discNumber: discNumber,
                year: year,
                genre: genre,
                bitRate: bitRate,
                bitDepth: bitDepth,
                sampleRate: sampleRate,
                channelCount: channelCount,
                suffix: suffix,
                contentType: contentType,
                size: size,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                playCount: playCount,
                replayGainTrackGain: replayGainTrackGain,
                replayGainTrackPeak: replayGainTrackPeak,
                replayGainAlbumGain: replayGainAlbumGain,
                replayGainAlbumPeak: replayGainAlbumPeak,
                localPath: localPath,
                downloadState: downloadState,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String id,
                Value<String?> albumId = const Value.absent(),
                Value<String?> artistId = const Value.absent(),
                required String title,
                Value<String?> artistName = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int?> track = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> bitRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> channelCount = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> starredAt = const Value.absent(),
                Value<int?> userRating = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<double?> replayGainTrackGain = const Value.absent(),
                Value<double?> replayGainTrackPeak = const Value.absent(),
                Value<double?> replayGainAlbumGain = const Value.absent(),
                Value<double?> replayGainAlbumPeak = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> downloadState = const Value.absent(),
                required DateTime fetchedAt,
                required DateTime lastSeenAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion.insert(
                serverId: serverId,
                id: id,
                albumId: albumId,
                artistId: artistId,
                title: title,
                artistName: artistName,
                albumName: albumName,
                coverArtId: coverArtId,
                duration: duration,
                track: track,
                discNumber: discNumber,
                year: year,
                genre: genre,
                bitRate: bitRate,
                bitDepth: bitDepth,
                sampleRate: sampleRate,
                channelCount: channelCount,
                suffix: suffix,
                contentType: contentType,
                size: size,
                starred: starred,
                starredAt: starredAt,
                userRating: userRating,
                playCount: playCount,
                replayGainTrackGain: replayGainTrackGain,
                replayGainTrackPeak: replayGainTrackPeak,
                replayGainAlbumGain: replayGainAlbumGain,
                replayGainAlbumPeak: replayGainAlbumPeak,
                localPath: localPath,
                downloadState: downloadState,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $SongsTable,
      SongRow,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (SongRow, BaseReferences<_$FlaxDatabase, $SongsTable, SongRow>),
      SongRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String serverId,
      required String id,
      required String name,
      Value<String?> comment,
      Value<int> songCount,
      Value<int> duration,
      Value<bool> public,
      Value<String?> ownerId,
      Value<DateTime?> created,
      Value<DateTime?> changed,
      Value<String?> coverArtId,
      required DateTime fetchedAt,
      required DateTime lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> serverId,
      Value<String> id,
      Value<String> name,
      Value<String?> comment,
      Value<int> songCount,
      Value<int> duration,
      Value<bool> public,
      Value<String?> ownerId,
      Value<DateTime?> created,
      Value<DateTime?> changed,
      Value<String?> coverArtId,
      Value<DateTime> fetchedAt,
      Value<DateTime> lastSeenAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$PlaylistsTableFilterComposer
    extends Composer<_$FlaxDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get songCount => $composableBuilder(
    column: $table.songCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get public => $composableBuilder(
    column: $table.public,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changed => $composableBuilder(
    column: $table.changed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$FlaxDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get songCount => $composableBuilder(
    column: $table.songCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get public => $composableBuilder(
    column: $table.public,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changed => $composableBuilder(
    column: $table.changed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<int> get songCount =>
      $composableBuilder(column: $table.songCount, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<bool> get public =>
      $composableBuilder(column: $table.public, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<DateTime> get changed =>
      $composableBuilder(column: $table.changed, builder: (column) => column);

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (
            PlaylistRow,
            BaseReferences<_$FlaxDatabase, $PlaylistsTable, PlaylistRow>,
          ),
          PlaylistRow,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$FlaxDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> songCount = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<bool> public = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> changed = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                serverId: serverId,
                id: id,
                name: name,
                comment: comment,
                songCount: songCount,
                duration: duration,
                public: public,
                ownerId: ownerId,
                created: created,
                changed: changed,
                coverArtId: coverArtId,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String id,
                required String name,
                Value<String?> comment = const Value.absent(),
                Value<int> songCount = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<bool> public = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<DateTime?> created = const Value.absent(),
                Value<DateTime?> changed = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                required DateTime fetchedAt,
                required DateTime lastSeenAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                serverId: serverId,
                id: id,
                name: name,
                comment: comment,
                songCount: songCount,
                duration: duration,
                public: public,
                ownerId: ownerId,
                created: created,
                changed: changed,
                coverArtId: coverArtId,
                fetchedAt: fetchedAt,
                lastSeenAt: lastSeenAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (
        PlaylistRow,
        BaseReferences<_$FlaxDatabase, $PlaylistsTable, PlaylistRow>,
      ),
      PlaylistRow,
      PrefetchHooks Function()
    >;
typedef $$AlbumListEntriesTableCreateCompanionBuilder =
    AlbumListEntriesCompanion Function({
      required String serverId,
      required String listType,
      Value<String> filterKey,
      required int position,
      required String albumId,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$AlbumListEntriesTableUpdateCompanionBuilder =
    AlbumListEntriesCompanion Function({
      Value<String> serverId,
      Value<String> listType,
      Value<String> filterKey,
      Value<int> position,
      Value<String> albumId,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$AlbumListEntriesTableFilterComposer
    extends Composer<_$FlaxDatabase, $AlbumListEntriesTable> {
  $$AlbumListEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listType => $composableBuilder(
    column: $table.listType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlbumListEntriesTableOrderingComposer
    extends Composer<_$FlaxDatabase, $AlbumListEntriesTable> {
  $$AlbumListEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listType => $composableBuilder(
    column: $table.listType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumListEntriesTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $AlbumListEntriesTable> {
  $$AlbumListEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get listType =>
      $composableBuilder(column: $table.listType, builder: (column) => column);

  GeneratedColumn<String> get filterKey =>
      $composableBuilder(column: $table.filterKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$AlbumListEntriesTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $AlbumListEntriesTable,
          AlbumListEntryRow,
          $$AlbumListEntriesTableFilterComposer,
          $$AlbumListEntriesTableOrderingComposer,
          $$AlbumListEntriesTableAnnotationComposer,
          $$AlbumListEntriesTableCreateCompanionBuilder,
          $$AlbumListEntriesTableUpdateCompanionBuilder,
          (
            AlbumListEntryRow,
            BaseReferences<
              _$FlaxDatabase,
              $AlbumListEntriesTable,
              AlbumListEntryRow
            >,
          ),
          AlbumListEntryRow,
          PrefetchHooks Function()
        > {
  $$AlbumListEntriesTableTableManager(
    _$FlaxDatabase db,
    $AlbumListEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumListEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumListEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumListEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> listType = const Value.absent(),
                Value<String> filterKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumListEntriesCompanion(
                serverId: serverId,
                listType: listType,
                filterKey: filterKey,
                position: position,
                albumId: albumId,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String listType,
                Value<String> filterKey = const Value.absent(),
                required int position,
                required String albumId,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => AlbumListEntriesCompanion.insert(
                serverId: serverId,
                listType: listType,
                filterKey: filterKey,
                position: position,
                albumId: albumId,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlbumListEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $AlbumListEntriesTable,
      AlbumListEntryRow,
      $$AlbumListEntriesTableFilterComposer,
      $$AlbumListEntriesTableOrderingComposer,
      $$AlbumListEntriesTableAnnotationComposer,
      $$AlbumListEntriesTableCreateCompanionBuilder,
      $$AlbumListEntriesTableUpdateCompanionBuilder,
      (
        AlbumListEntryRow,
        BaseReferences<
          _$FlaxDatabase,
          $AlbumListEntriesTable,
          AlbumListEntryRow
        >,
      ),
      AlbumListEntryRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistEntriesTableCreateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      required String serverId,
      required String playlistId,
      required int position,
      required String songId,
      Value<int> rowid,
    });
typedef $$PlaylistEntriesTableUpdateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<String> serverId,
      Value<String> playlistId,
      Value<int> position,
      Value<String> songId,
      Value<int> rowid,
    });

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$FlaxDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$FlaxDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);
}

class $$PlaylistEntriesTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $PlaylistEntriesTable,
          PlaylistEntryRow,
          $$PlaylistEntriesTableFilterComposer,
          $$PlaylistEntriesTableOrderingComposer,
          $$PlaylistEntriesTableAnnotationComposer,
          $$PlaylistEntriesTableCreateCompanionBuilder,
          $$PlaylistEntriesTableUpdateCompanionBuilder,
          (
            PlaylistEntryRow,
            BaseReferences<
              _$FlaxDatabase,
              $PlaylistEntriesTable,
              PlaylistEntryRow
            >,
          ),
          PlaylistEntryRow,
          PrefetchHooks Function()
        > {
  $$PlaylistEntriesTableTableManager(
    _$FlaxDatabase db,
    $PlaylistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> playlistId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEntriesCompanion(
                serverId: serverId,
                playlistId: playlistId,
                position: position,
                songId: songId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String playlistId,
                required int position,
                required String songId,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEntriesCompanion.insert(
                serverId: serverId,
                playlistId: playlistId,
                position: position,
                songId: songId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $PlaylistEntriesTable,
      PlaylistEntryRow,
      $$PlaylistEntriesTableFilterComposer,
      $$PlaylistEntriesTableOrderingComposer,
      $$PlaylistEntriesTableAnnotationComposer,
      $$PlaylistEntriesTableCreateCompanionBuilder,
      $$PlaylistEntriesTableUpdateCompanionBuilder,
      (
        PlaylistEntryRow,
        BaseReferences<_$FlaxDatabase, $PlaylistEntriesTable, PlaylistEntryRow>,
      ),
      PlaylistEntryRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String serverId,
      required String key,
      Value<String?> value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> serverId,
      Value<String> key,
      Value<String?> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$FlaxDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$FlaxDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$FlaxDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$FlaxDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$FlaxDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$FlaxDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                serverId: serverId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String key,
                Value<String?> value = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                serverId: serverId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlaxDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$FlaxDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $FlaxDatabaseManager {
  final _$FlaxDatabase _db;
  $FlaxDatabaseManager(this._db);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$AlbumListEntriesTableTableManager get albumListEntries =>
      $$AlbumListEntriesTableTableManager(_db, _db.albumListEntries);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
