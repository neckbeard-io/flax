import 'package:flax/domain/enums.dart';

class TranscodingConfig {
  final StreamQuality wifiQuality;
  final StreamQuality cellularQuality;
  final TranscodeFormat transcodeFormat;
  final StreamQuality offlineQuality;

  const TranscodingConfig({
    this.wifiQuality = StreamQuality.original,
    this.cellularQuality = StreamQuality.kbps256,
    this.transcodeFormat = TranscodeFormat.opus,
    this.offlineQuality = StreamQuality.original,
  });

  TranscodingConfig copyWith({
    StreamQuality? wifiQuality,
    StreamQuality? cellularQuality,
    TranscodeFormat? transcodeFormat,
    StreamQuality? offlineQuality,
  }) {
    return TranscodingConfig(
      wifiQuality: wifiQuality ?? this.wifiQuality,
      cellularQuality: cellularQuality ?? this.cellularQuality,
      transcodeFormat: transcodeFormat ?? this.transcodeFormat,
      offlineQuality: offlineQuality ?? this.offlineQuality,
    );
  }

  Map<String, dynamic> toJson() => {
    'wifiQuality': wifiQuality.name,
    'cellularQuality': cellularQuality.name,
    'transcodeFormat': transcodeFormat.name,
    'offlineQuality': offlineQuality.name,
  };

  factory TranscodingConfig.fromJson(Map<String, dynamic> json) {
    return TranscodingConfig(
      wifiQuality: StreamQuality.values.byName(json['wifiQuality'] as String),
      cellularQuality: StreamQuality.values.byName(
        json['cellularQuality'] as String,
      ),
      transcodeFormat: TranscodeFormat.values.byName(
        json['transcodeFormat'] as String,
      ),
      offlineQuality: StreamQuality.values.byName(
        json['offlineQuality'] as String,
      ),
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
    );
  }
}
