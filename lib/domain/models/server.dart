import 'package:flax/domain/enums.dart';

class TranscodingConfig {
  final StreamQuality wifiQuality;
  final StreamQuality cellularQuality;
  final TranscodeFormat transcodeFormat;
  final StreamQuality offlineQuality;
  final int offlineConcurrency;

  const TranscodingConfig({
    this.wifiQuality = StreamQuality.original,
    this.cellularQuality = StreamQuality.kbps256,
    this.transcodeFormat = TranscodeFormat.opus,
    this.offlineQuality = StreamQuality.original,
    this.offlineConcurrency = 2,
  });

  TranscodingConfig copyWith({
    StreamQuality? wifiQuality,
    StreamQuality? cellularQuality,
    TranscodeFormat? transcodeFormat,
    StreamQuality? offlineQuality,
    int? offlineConcurrency,
  }) {
    return TranscodingConfig(
      wifiQuality: wifiQuality ?? this.wifiQuality,
      cellularQuality: cellularQuality ?? this.cellularQuality,
      transcodeFormat: transcodeFormat ?? this.transcodeFormat,
      offlineQuality: offlineQuality ?? this.offlineQuality,
      offlineConcurrency: offlineConcurrency ?? this.offlineConcurrency,
    );
  }

  Map<String, dynamic> toJson() => {
    'wifiQuality': wifiQuality.name,
    'cellularQuality': cellularQuality.name,
    'transcodeFormat': transcodeFormat.name,
    'offlineQuality': offlineQuality.name,
    'offlineConcurrency': offlineConcurrency,
  };

  factory TranscodingConfig.fromJson(Map<String, dynamic> json) {
    return TranscodingConfig(
      wifiQuality: json['wifiQuality'] != null
          ? StreamQuality.values.byName(json['wifiQuality'] as String)
          : StreamQuality.original,
      cellularQuality: json['cellularQuality'] != null
          ? StreamQuality.values.byName(json['cellularQuality'] as String)
          : StreamQuality.kbps256,
      transcodeFormat: json['transcodeFormat'] != null
          ? TranscodeFormat.values.byName(json['transcodeFormat'] as String)
          : TranscodeFormat.opus,
      offlineQuality: json['offlineQuality'] != null
          ? StreamQuality.values.byName(json['offlineQuality'] as String)
          : StreamQuality.original,
      offlineConcurrency: (json['offlineConcurrency'] as num?)?.toInt() ?? 2,
    );
  }
}

class MetadataCacheConfig {
  final MetadataQuality albumArtQuality;
  final MetadataQuality artistArtQuality;
  final bool cacheArtistInfo;
  final int concurrency;
  final DateTime? lastSyncedAt;

  const MetadataCacheConfig({
    this.albumArtQuality = MetadataQuality.medium,
    this.artistArtQuality = MetadataQuality.medium,
    this.cacheArtistInfo = true,
    this.concurrency = 4,
    this.lastSyncedAt,
  });

  MetadataCacheConfig copyWith({
    MetadataQuality? albumArtQuality,
    MetadataQuality? artistArtQuality,
    bool? cacheArtistInfo,
    int? concurrency,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return MetadataCacheConfig(
      albumArtQuality: albumArtQuality ?? this.albumArtQuality,
      artistArtQuality: artistArtQuality ?? this.artistArtQuality,
      cacheArtistInfo: cacheArtistInfo ?? this.cacheArtistInfo,
      concurrency: concurrency ?? this.concurrency,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'albumArtQuality': albumArtQuality.name,
    'artistArtQuality': artistArtQuality.name,
    'cacheArtistInfo': cacheArtistInfo,
    'concurrency': concurrency,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory MetadataCacheConfig.fromJson(Map<String, dynamic> json) {
    return MetadataCacheConfig(
      albumArtQuality: json['albumArtQuality'] != null
          ? MetadataQuality.values.byName(json['albumArtQuality'] as String)
          : MetadataQuality.medium,
      artistArtQuality: json['artistArtQuality'] != null
          ? MetadataQuality.values.byName(json['artistArtQuality'] as String)
          : MetadataQuality.medium,
      cacheArtistInfo: json['cacheArtistInfo'] as bool? ?? true,
      concurrency: ((json['concurrency'] as num?)?.toInt() ?? 4).clamp(1, 8),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String)
          : null,
    );
  }
}

class Server {
  final String id;
  final String name;
  final String url;
  final String username;
  final String tokenHash;
  final String salt;
  final String backendType;
  final bool isActive;
  final DateTime? lastSync;
  final TranscodingConfig transcodingConfig;
  final MetadataCacheConfig metadataCacheConfig;

  const Server({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.tokenHash,
    required this.salt,
    this.backendType = 'navidrome',
    this.isActive = false,
    this.lastSync,
    this.transcodingConfig = const TranscodingConfig(),
    this.metadataCacheConfig = const MetadataCacheConfig(),
  });

  Server copyWith({
    String? id,
    String? name,
    String? url,
    String? username,
    String? tokenHash,
    String? salt,
    String? backendType,
    bool? isActive,
    DateTime? lastSync,
    TranscodingConfig? transcodingConfig,
    MetadataCacheConfig? metadataCacheConfig,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      tokenHash: tokenHash ?? this.tokenHash,
      salt: salt ?? this.salt,
      backendType: backendType ?? this.backendType,
      isActive: isActive ?? this.isActive,
      lastSync: lastSync ?? this.lastSync,
      transcodingConfig: transcodingConfig ?? this.transcodingConfig,
      metadataCacheConfig: metadataCacheConfig ?? this.metadataCacheConfig,
    );
  }

  String get baseUrl =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'tokenHash': tokenHash,
    'salt': salt,
    'backendType': backendType,
    'isActive': isActive,
    'lastSync': lastSync?.toIso8601String(),
    'transcodingConfig': transcodingConfig.toJson(),
    'metadataCacheConfig': metadataCacheConfig.toJson(),
  };

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
      tokenHash: json['tokenHash'] as String,
      salt: json['salt'] as String,
      backendType: json['backendType'] as String? ?? 'navidrome',
      isActive: json['isActive'] as bool? ?? false,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'] as String)
          : null,
      transcodingConfig: json['transcodingConfig'] != null
          ? TranscodingConfig.fromJson(
              json['transcodingConfig'] as Map<String, dynamic>,
            )
          : const TranscodingConfig(),
      metadataCacheConfig: json['metadataCacheConfig'] != null
          ? MetadataCacheConfig.fromJson(
              json['metadataCacheConfig'] as Map<String, dynamic>,
            )
          : const MetadataCacheConfig(),
    );
  }
}
