import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
      connectivity = await Connectivity().checkConnectivity();
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
    if (config.targetSsids.isEmpty) {
      // If no SSIDs configured, any Wi-Fi or Ethernet can trigger local endpoint probing
      ssidMatches = true;
    } else if (hasEthernet) {
      // Ethernet implies direct local LAN access
      ssidMatches = true;
    } else if (currentSsid != null) {
      final normalizedCurrent = currentSsid.trim().toLowerCase();
      ssidMatches = config.targetSsids.any(
        (s) => s.trim().toLowerCase() == normalizedCurrent,
      );
    }

    if (!ssidMatches) {
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
        statusMessage: 'Connected directly via local network',
      );
    } else {
      AppLogger.w(
        'NetworkTarget',
        'Local endpoint $localBaseUrl unreachable on matching Wi-Fi ($currentSsid).',
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
      final url = baseUrl.endsWith('/')
          ? '${baseUrl}rest/ping?v=1.16.1&c=flax&f=json'
          : '$baseUrl/rest/ping?v=1.16.1&c=flax&f=json';

      final res = await dio.get(url);
      return res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 400;
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
