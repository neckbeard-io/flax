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
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/network/certificate_trust.dart';
import 'package:flax/services/platform/car_connection_service.dart';

enum EndpointTargetType { external, local }

/// What the last local probe decided, for the connection screen to describe in
/// the user's language.
enum NetworkTargetStatus {
  /// Requests go straight to the local target.
  connectedLocal,

  /// The local target did not answer, so requests use the remote URL.
  localUnreachableFallback,

  /// The local target did not answer, and failover is off.
  localUnreachable,
}

class NetworkTargetState {
  /// The server this decision is for; null when there is none. A client only
  /// takes [effectiveBaseUrl] from a state for its own server.
  final String? serverId;
  final EndpointTargetType activeTarget;
  final String effectiveBaseUrl;
  final String? currentSsid;
  final bool isLocalConfigured;
  final bool isProbing;
  final bool? isLocalReachable;
  final int? lastProbeLatencyMs;
  final NetworkTargetStatus? status;

  const NetworkTargetState({
    this.serverId,
    required this.activeTarget,
    required this.effectiveBaseUrl,
    this.currentSsid,
    this.isLocalConfigured = false,
    this.isProbing = false,
    this.isLocalReachable,
    this.lastProbeLatencyMs,
    this.status,
  });

  bool get isUsingLocal => activeTarget == EndpointTargetType.local;

  NetworkTargetState copyWith({
    String? serverId,
    EndpointTargetType? activeTarget,
    String? effectiveBaseUrl,
    String? currentSsid,
    bool? isLocalConfigured,
    bool? isProbing,
    bool? isLocalReachable,
    int? lastProbeLatencyMs,
    NetworkTargetStatus? status,
    bool clearStatus = false,
  }) {
    return NetworkTargetState(
      serverId: serverId ?? this.serverId,
      activeTarget: activeTarget ?? this.activeTarget,
      effectiveBaseUrl: effectiveBaseUrl ?? this.effectiveBaseUrl,
      currentSsid: currentSsid ?? this.currentSsid,
      isLocalConfigured: isLocalConfigured ?? this.isLocalConfigured,
      isProbing: isProbing ?? this.isProbing,
      isLocalReachable: isLocalReachable ?? this.isLocalReachable,
      lastProbeLatencyMs: lastProbeLatencyMs ?? this.lastProbeLatencyMs,
      status: clearStatus ? null : (status ?? this.status),
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

  final _firstDecision = Completer<void>();
  final _sinceLaunch = Stopwatch()..start();
  Timer? _firstDecisionBound;

  /// The longest launch requests wait for the first decision. The probe
  /// timeout can be set as high as 5000ms; Android Auto's own 3s timeouts must
  /// not expire first.
  static const firstDecisionCap = Duration(milliseconds: 2500);

  /// Completes once the first evaluation has chosen an address, or once
  /// [firstDecisionCap] (or the probe timeout plus 500ms, if shorter) has
  /// passed, or on dispose.
  ///
  /// The resolver starts on the remote address, and requests sent before the
  /// local one was chosen stayed on the remote one: through hairpin NAT at
  /// best, failing outright at worst (#170). Every request waits for this.
  Future<void> get firstEvaluation => _firstDecision.future;

  /// The address chosen for [serverId], or null when the current decision is
  /// for another server or none has been made.
  String? chosenBaseUrlFor(String serverId) =>
      state.serverId == serverId && state.effectiveBaseUrl.isNotEmpty
      ? state.effectiveBaseUrl
      : null;

  void _completeFirstDecision({bool timedOut = false}) {
    if (_firstDecision.isCompleted) return;
    _firstDecisionBound?.cancel();
    final ms = _sinceLaunch.elapsedMilliseconds;
    if (timedOut) {
      AppLogger.w(
        'NetworkTarget',
        'First target decision took over ${ms}ms; starting on '
            '${state.effectiveBaseUrl}',
      );
    } else {
      AppLogger.i(
        'NetworkTarget',
        'Network target chosen in ${ms}ms: '
            '${state.isUsingLocal ? 'local' : 'remote'}',
      );
    }
    _firstDecision.complete();
  }

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
    if (initialServer == null) {
      _completeFirstDecision();
    } else {
      final probe = Duration(
        milliseconds: initialServer.localNetworkConfig.probeTimeoutMs + 500,
      );
      _firstDecisionBound = Timer(
        probe < firstDecisionCap ? probe : firstDecisionCap,
        () => _completeFirstDecision(timedOut: true),
      );
      state = state.copyWith(
        serverId: initialServer.id,
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

    // The first evaluation skips the debounce: launch requests wait for it.
    // A microtask, so state is never set while the provider is being built.
    scheduleMicrotask(() {
      if (mounted) evaluate();
    });
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
    try {
      await _evaluate();
    } finally {
      if (mounted) _completeFirstDecision();
    }
  }

  Future<void> _evaluate() async {
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
        serverId: server.id,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: false,
        clearStatus: true,
      );
      return;
    }

    // Determine current connectivity
    List<ConnectivityResult> connectivity;
    try {
      connectivity = await readCurrentConnectivity(_ref);
    } catch (_) {
      connectivity = [ConnectivityResult.none];
    }
    if (!mounted) return;

    final hasWifi = connectivity.contains(ConnectivityResult.wifi);
    final hasEthernet = connectivity.contains(ConnectivityResult.ethernet);

    if (!hasWifi && !hasEthernet) {
      // Cellular or offline -> use external
      state = state.copyWith(
        activeTarget: EndpointTargetType.external,
        serverId: server.id,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: true,
        currentSsid: null,
        clearStatus: true,
      );
      return;
    }

    // Read current SSID if on Wi-Fi
    String? currentSsid;
    if (hasWifi) {
      currentSsid = await getCurrentSsid();
      if (!mounted) return;
    }

    // Offline by choice: probing the LAN address is a server request too.
    final isCarConnected = _ref.read(isCarConnectedProvider);
    if (_ref.read(forcedOfflineProvider) || (isCarConnected && !hasEthernet)) {
      AppLogger.d(
        'NetworkTarget',
        () =>
            'Offline by choice or connected to a vehicle ($currentSsid). Skipping local endpoint probing.',
      );
      state = state.copyWith(
        activeTarget: EndpointTargetType.external,
        serverId: server.id,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: true,
        currentSsid: currentSsid,
        clearStatus: true,
      );
      return;
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
        serverId: server.id,
        effectiveBaseUrl: server.baseUrl,
        isLocalConfigured: true,
        currentSsid: currentSsid,
        clearStatus: true,
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
      timeout: Duration(milliseconds: config.probeTimeoutMs),
    );
    stopwatch.stop();
    if (!mounted) return;

    if (reachable) {
      AppLogger.i(
        'NetworkTarget',
        'Local endpoint $localBaseUrl is reachable in ${stopwatch.elapsedMilliseconds}ms. Switching to local target.',
      );
      state = state.copyWith(
        activeTarget: EndpointTargetType.local,
        serverId: server.id,
        effectiveBaseUrl: localBaseUrl,
        isProbing: false,
        isLocalReachable: true,
        lastProbeLatencyMs: stopwatch.elapsedMilliseconds,
        status: NetworkTargetStatus.connectedLocal,
      );
    } else {
      AppLogger.w(
        'NetworkTarget',
        'Local endpoint $localBaseUrl unreachable (Wi-Fi: ${currentSsid ?? "unknown"}).',
      );
      if (config.fallbackToExternal) {
        state = state.copyWith(
          activeTarget: EndpointTargetType.external,
          serverId: server.id,
          effectiveBaseUrl: server.baseUrl,
          isProbing: false,
          isLocalReachable: false,
          status: NetworkTargetStatus.localUnreachableFallback,
        );
      } else {
        state = state.copyWith(
          activeTarget: EndpointTargetType.local,
          serverId: server.id,
          effectiveBaseUrl: localBaseUrl,
          isProbing: false,
          isLocalReachable: false,
          status: NetworkTargetStatus.localUnreachable,
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

  /// Probes [server]'s local target at [baseUrl] to see whether it responds.
  static Future<bool> probeLocalEndpoint(
    String baseUrl, {
    required Server server,
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
        client.badCertificateCallback = (cert, host, port) =>
            acceptsAnyCertificate(server, host, port);
        return client;
      },
    );

    try {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final salt = List.generate(
        16,
        (_) => Random.secure().nextInt(36).toRadixString(36),
      ).join();
      final token = md5
          .convert(utf8.encode('${server.tokenHash}$salt'))
          .toString();
      final queryParams = <String, String>{
        'v': '1.16.1',
        'c': 'flax',
        'f': 'json',
        'u': server.username,
        't': token,
        's': salt,
      };

      final uri = Uri.parse(
        '$cleanBase/rest/ping',
      ).replace(queryParameters: queryParams);

      final res = await dio.getUri(uri).timeout(timeout);
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
    _completeFirstDecision();
    super.dispose();
  }
}
