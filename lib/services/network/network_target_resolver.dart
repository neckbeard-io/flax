import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';

enum EndpointTargetType { external, local }

class NetworkTargetState {
  final EndpointTargetType activeTarget;
  final String effectiveBaseUrl;
  final String? currentSsid;
  final bool isLocalConfigured;
  final bool isProbing;
  final bool? isLocalReachable;
  final int? lastProbeLatencyMs;
  final String? statusMessage;

  const NetworkTargetState({
    required this.activeTarget,
    required this.effectiveBaseUrl,
    this.currentSsid,
    this.isLocalConfigured = false,
    this.isProbing = false,
    this.isLocalReachable,
    this.lastProbeLatencyMs,
    this.statusMessage,
  });

  bool get isUsingLocal => activeTarget == EndpointTargetType.local;

  NetworkTargetState copyWith({
    EndpointTargetType? activeTarget,
    String? effectiveBaseUrl,
    String? currentSsid,
    bool? isLocalConfigured,
    bool? isProbing,
    bool? isLocalReachable,
    int? lastProbeLatencyMs,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return NetworkTargetState(
      activeTarget: activeTarget ?? this.activeTarget,
      effectiveBaseUrl: effectiveBaseUrl ?? this.effectiveBaseUrl,
      currentSsid: currentSsid ?? this.currentSsid,
      isLocalConfigured: isLocalConfigured ?? this.isLocalConfigured,
      isProbing: isProbing ?? this.isProbing,
      isLocalReachable: isLocalReachable ?? this.isLocalReachable,
      lastProbeLatencyMs: lastProbeLatencyMs ?? this.lastProbeLatencyMs,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
    );
  }
}

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo();
});

final networkTargetResolverProvider =
    StateNotifierProvider<NetworkTargetResolver, NetworkTargetState>((ref) {
      return NetworkTargetResolver(ref);
    });

final effectiveBaseUrlProvider = Provider<String?>((ref) {
  final targetState = ref.watch(networkTargetResolverProvider);
  return targetState.effectiveBaseUrl.isNotEmpty
      ? targetState.effectiveBaseUrl
      : null;
});

class NetworkTargetResolver extends StateNotifier<NetworkTargetState> {
  static const _downloaderChannel = MethodChannel('com.flax/native_downloader');
  final Ref _ref;
  final NetworkInfo _networkInfo;
  Timer? _debounceTimer;

  NetworkTargetResolver(this._ref, {NetworkInfo? networkInfo})
    : _networkInfo = networkInfo ?? _ref.read(networkInfoProvider),
      super(
        const NetworkTargetState(
          activeTarget: EndpointTargetType.external,
          effectiveBaseUrl: '',
        ),
      ) {
    _init();
  }

  /// Explicitly requests Android location permission needed to read Wi-Fi SSIDs.
  Future<void> requestLocationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _downloaderChannel.invokeMethod('requestLocationPermission');
    } catch (_) {}
  }

  void _init() {
    // Initial evaluation
    final initialServer = _ref.read(activeServerProvider);
    if (initialServer != null) {
      state = state.copyWith(
        effectiveBaseUrl: initialServer.baseUrl,
        isLocalConfigured:
            initialServer.localNetworkConfig.enabled &&
            initialServer.localNetworkConfig.localBaseUrl != null,
      );
    }

    // React to server changes
    _ref.listen<Server?>(activeServerProvider, (prev, next) {
      if (next == null) {
        state = const NetworkTargetState(
          activeTarget: EndpointTargetType.external,
          effectiveBaseUrl: '',
        );
      } else {
        _scheduleEvaluation();
      }
    });

    // React to connectivity changes
    _ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityStreamProvider,
      (prev, next) {
        _scheduleEvaluation();
      },
    );

    // Initial evaluation
    _scheduleEvaluation();
  }

  void _scheduleEvaluation() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        evaluate();
      }
    });
  }

  /// Evaluates current network connectivity and SSID against the active server configuration.
  Future<void> evaluate({bool force = false}) async {
    final server = _ref.read(activeServerProvider);
    if (server == null) {
      state = const NetworkTargetState(
        activeTarget: EndpointTargetType.external,
        effectiveBaseUrl: '',
      );
      return;
    }

    final config = server.localNetworkConfig;
    final localBaseUrl = config.localBaseUrl;
    final isConfigured = config.enabled && localBaseUrl != null;

    if (!isConfigured) {
      state = state.copyWith(
        activeTarget: EndpointTargetType.external,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: false,
        clearStatusMessage: true,
      );
      return;
    }

    // Determine current connectivity
    List<ConnectivityResult> connectivity;
    try {
      connectivity = await _ref.read(connectivityProvider.future);
    } catch (_) {
      connectivity = [ConnectivityResult.none];
    }

    final hasWifi = connectivity.contains(ConnectivityResult.wifi);
    final hasEthernet = connectivity.contains(ConnectivityResult.ethernet);

    if (!hasWifi && !hasEthernet) {
      // Cellular or offline -> use external
      state = state.copyWith(
        activeTarget: EndpointTargetType.external,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: true,
        currentSsid: null,
        clearStatusMessage: true,
      );
      return;
    }

    // Read current SSID if on Wi-Fi
    String? currentSsid;
    if (hasWifi) {
      currentSsid = await getCurrentSsid();
    }

    // Check if current SSID matches configured target SSIDs
    bool ssidMatches = false;
    bool ssidUnknown = false;
    if (config.targetSsids.isEmpty || hasEthernet) {
      // If no SSIDs configured or on wired Ethernet, trigger local endpoint probing
      ssidMatches = true;
    } else if (currentSsid != null) {
      final normalizedCurrent = currentSsid.trim().toLowerCase();
      ssidMatches = config.targetSsids.any(
        (s) => s.trim().toLowerCase() == normalizedCurrent,
      );
    } else {
      // currentSsid is null/unknown (e.g. Android location permission not granted,
      // or device location services disabled). Rather than rejecting local routing,
      // probe localBaseUrl directly. If local LAN responds, we are on the local network.
      ssidUnknown = true;
    }

    if (!ssidMatches && !ssidUnknown) {
      AppLogger.d(
        'NetworkTarget',
        () =>
            'SSID "$currentSsid" does not match targets: ${config.targetSsids}. Using external endpoint.',
      );
      state = state.copyWith(
        activeTarget: EndpointTargetType.external,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: true,
        currentSsid: currentSsid,
        clearStatusMessage: true,
      );
      return;
    }

    // Probe the local endpoint for reachability
    state = state.copyWith(
      isProbing: true,
      currentSsid: currentSsid,
      isLocalConfigured: true,
    );

    final stopwatch = Stopwatch()..start();
    final reachable = await probeLocalEndpoint(
      localBaseUrl,
      server: server,
      trustSelfSigned: config.trustSelfSignedCerts,
      timeout: Duration(milliseconds: config.probeTimeoutMs),
    );
    stopwatch.stop();

    if (reachable) {
      AppLogger.i(
        'NetworkTarget',
        'Local endpoint $localBaseUrl is reachable in ${stopwatch.elapsedMilliseconds}ms. Switching to local target.',
      );
      state = state.copyWith(
        activeTarget: EndpointTargetType.local,
        effectiveBaseUrl: localBaseUrl,
        isProbing: false,
        isLocalReachable: true,
        lastProbeLatencyMs: stopwatch.elapsedMilliseconds,
        statusMessage: currentSsid != null
            ? 'Connected directly via local network ($currentSsid)'
            : 'Connected directly via local network',
      );
    } else {
      AppLogger.w(
        'NetworkTarget',
        'Local endpoint $localBaseUrl unreachable (Wi-Fi: ${currentSsid ?? "unknown"}).',
      );
      if (config.fallbackToExternal) {
        state = state.copyWith(
          activeTarget: EndpointTargetType.external,
          effectiveBaseUrl: server.baseUrl,
          isProbing: false,
          isLocalReachable: false,
          statusMessage: 'Local endpoint unreachable. Routed via external URL.',
        );
      } else {
        state = state.copyWith(
          activeTarget: EndpointTargetType.local,
          effectiveBaseUrl: localBaseUrl,
          isProbing: false,
          isLocalReachable: false,
          statusMessage: 'Local endpoint unreachable',
        );
      }
    }
  }

  /// Retrieves the current Wi-Fi SSID name, sanitized of quotes and placeholders.
  Future<String?> getCurrentSsid() async {
    try {
      final raw = await _networkInfo.getWifiName();
      if (raw == null) return null;
      final clean = raw.replaceAll('"', '').trim();
      if (clean.isEmpty ||
          clean == '<unknown ssid>' ||
          clean == '0x' ||
          clean == 'Wi-Fi') {
        return null;
      }
      return clean;
    } catch (e) {
      AppLogger.d('NetworkTarget', () => 'Could not read Wi-Fi SSID: $e');
      return null;
    }
  }

  /// Probes an endpoint to verify whether it is alive and responding.
  static Future<bool> probeLocalEndpoint(
    String baseUrl, {
    Server? server,
    bool trustSelfSigned = false,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = timeout;
        if (trustSelfSigned) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
        return client;
      },
    );

    try {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final queryParams = <String, String>{
        'v': '1.16.1',
        'c': 'flax',
        'f': 'json',
      };

      if (server != null) {
        final salt = List.generate(
          16,
          (_) => Random.secure().nextInt(36).toRadixString(36),
        ).join();
        final token = md5
            .convert(utf8.encode('${server.tokenHash}$salt'))
            .toString();
        queryParams['u'] = server.username;
        queryParams['t'] = token;
        queryParams['s'] = salt;
      }

      final uri = Uri.parse(
        '$cleanBase/rest/ping',
      ).replace(queryParameters: queryParams);

      final res = await dio.getUri(uri);
      return res.statusCode != null &&
          ((res.statusCode! >= 200 && res.statusCode! < 400) ||
              res.statusCode == 401);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
