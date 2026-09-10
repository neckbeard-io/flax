import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/features/settings/audio_output_settings.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/diagnostics/diagnostics_sanitizer.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/services/platform/background_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/services/updater/update_provider.dart';

/// Aggregated system environment, hardware, audio, and server diagnostic report.
class DiagnosticsReport {
  final String appVersion;
  final String buildNumber;
  final String updateChannel;
  final String buildMode;

  final String osName;
  final String osVersion;
  final String architecture;
  final String dartVersion;

  final String outputDevice;
  final String outputDescription;
  final String outputEngine;
  final bool exclusiveMode;
  final String sampleRate;
  final String bitDepth;
  final bool eqEnabled;
  final String eqPreset;
  final double eqPreamp;
  final String? autoEqProfile;

  final String? serverType;
  final String? serverVersion;
  final String? subsonicApiVersion;
  final bool openSubsonicSupported;
  final List<String> openSubsonicExtensions;
  final String? serverUrlSanitized;

  final String cacheLimit;
  final int audioCachedBytes;
  final int audioCachedTracks;
  final int metadataCoversCached;
  final int metadataCoversTotal;
  final int metadataArtistsCached;
  final int metadataArtistsTotal;
  final int metadataBiosCached;
  final int metadataBiosTotal;
  final List<String> activeTasks;
  final String backgroundSyncStatus;

  final List<String> recentLogs;
  final String? activeServerUrl;
  final String? activeServerUsername;

  const DiagnosticsReport({
    required this.appVersion,
    required this.buildNumber,
    required this.updateChannel,
    required this.buildMode,
    required this.osName,
    required this.osVersion,
    required this.architecture,
    required this.dartVersion,
    required this.outputDevice,
    required this.outputDescription,
    required this.outputEngine,
    required this.exclusiveMode,
    required this.sampleRate,
    required this.bitDepth,
    required this.eqEnabled,
    required this.eqPreset,
    required this.eqPreamp,
    this.autoEqProfile,
    this.serverType,
    this.serverVersion,
    this.subsonicApiVersion,
    this.openSubsonicSupported = false,
    this.openSubsonicExtensions = const [],
    this.serverUrlSanitized,
    required this.cacheLimit,
    this.audioCachedBytes = 0,
    this.audioCachedTracks = 0,
    this.metadataCoversCached = 0,
    this.metadataCoversTotal = 0,
    this.metadataArtistsCached = 0,
    this.metadataArtistsTotal = 0,
    this.metadataBiosCached = 0,
    this.metadataBiosTotal = 0,
    this.activeTasks = const [],
    required this.backgroundSyncStatus,
    this.recentLogs = const [],
    this.activeServerUrl,
    this.activeServerUsername,
  });

  /// Formats all diagnostics and logs into GitHub Flavored Markdown.
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('### Environment & Client');
    buffer.writeln('- **Flax Version**: $appVersion (build $buildNumber)');
    buffer.writeln('- **Channel**: $updateChannel');
    buffer.writeln('- **Build Mode**: $buildMode');
    buffer.writeln('- **Operating System**: $osName ($osVersion)');
    buffer.writeln('- **Architecture**: $architecture');
    buffer.writeln('- **Dart SDK**: $dartVersion');
    buffer.writeln();

    buffer.writeln('### Audio Pipeline');
    buffer.writeln(
      '- **Active DAC / Output**: $outputDescription ($outputDevice)',
    );
    buffer.writeln('- **Engine**: $outputEngine');
    buffer.writeln(
      '- **Exclusive Mode**: ${exclusiveMode ? "Enabled" : "Disabled"}',
    );
    buffer.writeln('- **Sample Rate**: $sampleRate');
    buffer.writeln('- **Bit Depth**: $bitDepth');
    buffer.writeln(
      '- **Equalizer**: ${eqEnabled ? "Enabled (Preset: $eqPreset, Preamp: ${eqPreamp.toStringAsFixed(1)} dB)" : "Disabled"}',
    );
    buffer.writeln('- **AutoEQ Profile**: ${autoEqProfile ?? "None"}');
    buffer.writeln();

    buffer.writeln('### Subsonic Server Capabilities');
    if (serverUrlSanitized != null) {
      buffer.writeln('- **Server URL**: $serverUrlSanitized');
      buffer.writeln('- **Server Brand / Type**: ${serverType ?? "Unknown"}');
      buffer.writeln('- **Server Version**: ${serverVersion ?? "Unknown"}');
      buffer.writeln(
        '- **Subsonic API Version**: ${subsonicApiVersion ?? "Unknown"}',
      );
      buffer.writeln(
        '- **OpenSubsonic**: ${openSubsonicSupported ? "Supported" : "Not advertised"}',
      );
      if (openSubsonicExtensions.isNotEmpty) {
        buffer.writeln(
          '- **Extensions**: ${openSubsonicExtensions.join(", ")}',
        );
      }
    } else {
      buffer.writeln('- **Server**: No server configured');
    }
    buffer.writeln();

    buffer.writeln('### Storage & Caching');
    buffer.writeln('- **Audio Cache Quota**: $cacheLimit');
    buffer.writeln(
      '- **Audio Cached**: ${formatBytes(audioCachedBytes)} ($audioCachedTracks ${audioCachedTracks == 1 ? "track" : "tracks"})',
    );
    buffer.writeln(
      '- **Artwork & Metadata**: Covers: $metadataCoversCached/$metadataCoversTotal, Photos: $metadataArtistsCached/$metadataArtistsTotal, Bios: $metadataBiosCached/$metadataBiosTotal',
    );
    buffer.writeln(
      '- **Active Tasks**: ${activeTasks.isEmpty ? "None" : activeTasks.join(", ")}',
    );
    buffer.writeln('- **Background Sync**: $backgroundSyncStatus');
    buffer.writeln();

    buffer.writeln('### Recent Application Logs');
    buffer.writeln('```');
    if (recentLogs.isEmpty) {
      buffer.writeln('(No logs buffered)');
    } else {
      buffer.writeln(recentLogs.join('\n'));
    }
    buffer.writeln('```');

    return buffer.toString();
  }

  /// Returns the complete markdown report with all credentials, server addresses,
  /// and local user paths sanitized.
  String getSanitizedMarkdown() {
    return DiagnosticsSanitizer.sanitize(
      toMarkdown(),
      serverUrl: activeServerUrl,
      username: activeServerUsername,
    );
  }
}

/// Service responsible for collecting system, audio, server, and log diagnostics.
class DiagnosticsService {
  final Ref _ref;

  DiagnosticsService(this._ref);

  Future<DiagnosticsReport> collectReport({
    PackageInfo? packageInfoOverride,
  }) async {
    // 1. App Info
    PackageInfo? info = packageInfoOverride;
    if (info == null) {
      try {
        info = await PackageInfo.fromPlatform();
      } catch (_) {
        info = null;
      }
    }
    final appVersion = info != null ? 'v${info.version}' : 'vUnknown';
    final buildNumber = info?.buildNumber ?? '?';
    final updateChannel = _ref.read(updateNotifierProvider).channel.label;
    final buildMode = kDebugMode
        ? 'Debug'
        : (kProfileMode ? 'Profile' : 'Release');

    // 2. OS & Hardware
    final osName = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;
    final dartVersion = Platform.version.split(' ').first;
    final archMatch = RegExp(
      r'on\s+"?([a-zA-Z0-9_-]+)"?',
    ).firstMatch(Platform.version);
    final architecture = archMatch?.group(1) ?? 'Unknown';

    // 3. Audio Pipeline
    final audioSettings = _ref.read(audioOutputSettingsProvider);
    final eqState = _ref.read(eqProvider);
    final autoEqState = _ref.read(autoEqProvider);

    // 4. Server Info
    final server = _ref.read(activeServerProvider);
    String? serverType;
    String? serverVersion;
    String? subsonicApiVersion;
    bool openSubsonicSupported = false;
    List<String> openSubsonicExtensions = [];
    String? serverUrlSanitized;

    if (server != null) {
      serverUrlSanitized = DiagnosticsSanitizer.sanitize(server.url);
      final client =
          _ref.read(subsonicClientProvider) ?? SubsonicClient(server: server);
      try {
        final serverInfo = await client.getServerInfo(
          timeout: const Duration(seconds: 3),
        );
        serverType = serverInfo.serverType;
        serverVersion = serverInfo.serverVersion;
        subsonicApiVersion = serverInfo.apiVersion;
        openSubsonicSupported = serverInfo.openSubsonic;
        openSubsonicExtensions = serverInfo.extensions.entries
            .map((e) => '${e.key} (v${e.value})')
            .toList();
      } catch (_) {
        subsonicApiVersion = '1.16.1';
      }
    }

    // 5. Storage & Caching
    final audioConfig = _ref.read(audioCacheConfigProvider);
    final audioSummary = server != null
        ? _ref.read(audioCacheSummaryProvider(server.id)).valueOrNull
        : null;
    final metaSummary = server != null
        ? _ref.read(metadataCacheSummaryProvider(server.id)).valueOrNull
        : null;
    final tasks = _ref.read(taskRegistryProvider);
    final activeTasks = tasks.where((t) => t.state.isActive).toList();

    String backgroundSync = 'Unsupported';
    if (Platform.isAndroid) {
      final bgStatus = _ref.read(backgroundSyncStatusProvider).valueOrNull;
      backgroundSync = bgStatus?.isScheduled == true ? 'Scheduled' : 'Disabled';
    }

    // 6. Recent Logs
    final entries = AppLogger.getEntries();
    final recentEntries = entries.length > 200
        ? entries.sublist(entries.length - 200)
        : entries;
    final recentLogs = recentEntries.map((e) => e.format()).toList();

    return DiagnosticsReport(
      appVersion: appVersion,
      buildNumber: buildNumber,
      updateChannel: updateChannel,
      buildMode: buildMode,
      osName: osName,
      osVersion: osVersion,
      architecture: architecture,
      dartVersion: dartVersion,
      outputDevice: audioSettings.deviceName,
      outputDescription: audioSettings.deviceDescription,
      outputEngine: audioSettings.engine.label,
      exclusiveMode: audioSettings.exclusive,
      sampleRate: audioSettings.sampleRate,
      bitDepth: audioSettings.bitDepth,
      eqEnabled: eqState.enabled,
      eqPreset: eqState.presetName,
      eqPreamp: eqState.preamp,
      autoEqProfile: autoEqState.activeProfile?.name,
      serverType: serverType,
      serverVersion: serverVersion,
      subsonicApiVersion: subsonicApiVersion,
      openSubsonicSupported: openSubsonicSupported,
      openSubsonicExtensions: openSubsonicExtensions,
      serverUrlSanitized: serverUrlSanitized,
      cacheLimit: audioConfig.limitDisplayString,
      audioCachedBytes: audioSummary?.audioBytes ?? 0,
      audioCachedTracks: audioSummary?.cachedSongCount ?? 0,
      metadataCoversCached: metaSummary?.albumArtCached ?? 0,
      metadataCoversTotal: metaSummary?.albumArtTotal ?? 0,
      metadataArtistsCached: metaSummary?.artistArtCached ?? 0,
      metadataArtistsTotal: metaSummary?.artistArtTotal ?? 0,
      metadataBiosCached: metaSummary?.artistInfoCached ?? 0,
      metadataBiosTotal: metaSummary?.artistInfoTotal ?? 0,
      activeTasks: activeTasks
          .map((t) => '${t.kind.name}: ${t.label}')
          .toList(),
      backgroundSyncStatus: backgroundSync,
      recentLogs: recentLogs,
      activeServerUrl: server?.url,
      activeServerUsername: server?.username,
    );
  }
}

final diagnosticsServiceProvider = Provider<DiagnosticsService>((ref) {
  return DiagnosticsService(ref);
});

final diagnosticsReportProvider = FutureProvider.autoDispose<DiagnosticsReport>(
  (ref) async {
    final service = ref.watch(diagnosticsServiceProvider);
    return service.collectReport();
  },
);
