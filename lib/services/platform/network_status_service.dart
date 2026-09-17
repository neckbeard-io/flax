import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flax/core/logging/app_logger.dart';

/// Represents the high-fidelity state of network adapters on the device,
/// with explicit distinction between primary internet adapters and
/// secondary non-validated connections (such as wireless Android Auto Wi-Fi links).
class NetworkStatus {
  final ConnectivityResult primaryTransport;
  final bool isWifiPrimary;
  final bool isCellularPrimary;
  final bool isEthernetPrimary;
  final bool isWifiConnected;
  final bool isWifiValidated;

  const NetworkStatus({
    this.primaryTransport = ConnectivityResult.none,
    this.isWifiPrimary = false,
    this.isCellularPrimary = false,
    this.isEthernetPrimary = false,
    this.isWifiConnected = false,
    this.isWifiValidated = false,
  });

  factory NetworkStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawPrimary = map['primaryTransport'] as String? ?? 'none';
    final isWifiPrimary = map['isWifiPrimary'] as bool? ?? false;
    final isCellularPrimary = map['isCellularPrimary'] as bool? ?? false;
    final isEthernetPrimary = map['isEthernetPrimary'] as bool? ?? false;
    final isWifiConnected = map['isWifiConnected'] as bool? ?? false;
    final isWifiValidated = map['isWifiValidated'] as bool? ?? false;

    ConnectivityResult primary;
    switch (rawPrimary) {
      case 'wifi':
        primary = ConnectivityResult.wifi;
        break;
      case 'cellular':
        primary = ConnectivityResult.mobile;
        break;
      case 'ethernet':
        primary = ConnectivityResult.ethernet;
        break;
      case 'vpn':
        primary = ConnectivityResult.vpn;
        break;
      case 'bluetooth':
        primary = ConnectivityResult.bluetooth;
        break;
      case 'none':
      default:
        primary = isWifiPrimary
            ? ConnectivityResult.wifi
            : (isCellularPrimary
                ? ConnectivityResult.mobile
                : ConnectivityResult.none);
        break;
    }

    return NetworkStatus(
      primaryTransport: primary,
      isWifiPrimary: isWifiPrimary,
      isCellularPrimary: isCellularPrimary,
      isEthernetPrimary: isEthernetPrimary,
      isWifiConnected: isWifiConnected,
      isWifiValidated: isWifiValidated,
    );
  }

  factory NetworkStatus.fromConnectivityList(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.ethernet)) {
      return const NetworkStatus(
        primaryTransport: ConnectivityResult.ethernet,
        isEthernetPrimary: true,
      );
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return const NetworkStatus(
        primaryTransport: ConnectivityResult.wifi,
        isWifiPrimary: true,
        isWifiConnected: true,
        isWifiValidated: true,
      );
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return const NetworkStatus(
        primaryTransport: ConnectivityResult.mobile,
        isCellularPrimary: true,
      );
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return const NetworkStatus(
        primaryTransport: ConnectivityResult.vpn,
      );
    }
    return const NetworkStatus(
      primaryTransport: ConnectivityResult.none,
    );
  }

  /// Converts this status to a standard [List<ConnectivityResult>] where the
  /// PRIMARY adapter dictates the connection type. This ensures secondary
  /// non-internet adapters (such as wireless Android Auto Wi-Fi) do not fool
  /// the app into thinking it is on a Wi-Fi connection with LAN/internet access.
  List<ConnectivityResult> toConnectivityList() {
    if (primaryTransport == ConnectivityResult.none) {
      return const [ConnectivityResult.none];
    }
    if (isCellularPrimary) {
      return const [ConnectivityResult.mobile];
    }
    if (isWifiPrimary) {
      return const [ConnectivityResult.wifi];
    }
    if (isEthernetPrimary) {
      return const [ConnectivityResult.ethernet];
    }
    return [primaryTransport];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkStatus &&
          runtimeType == other.runtimeType &&
          primaryTransport == other.primaryTransport &&
          isWifiPrimary == other.isWifiPrimary &&
          isCellularPrimary == other.isCellularPrimary &&
          isEthernetPrimary == other.isEthernetPrimary &&
          isWifiConnected == other.isWifiConnected &&
          isWifiValidated == other.isWifiValidated;

  @override
  int get hashCode => Object.hash(
    primaryTransport,
    isWifiPrimary,
    isCellularPrimary,
    isEthernetPrimary,
    isWifiConnected,
    isWifiValidated,
  );

  @override
  String toString() =>
      'NetworkStatus(primary: $primaryTransport, wifiPrimary: $isWifiPrimary, cellularPrimary: $isCellularPrimary, wifiConnected: $isWifiConnected, wifiValidated: $isWifiValidated)';
}

/// Service that interfaces with Android's native ConnectivityManager to
/// accurately resolve the system's primary default internet adapter.
class NetworkStatusService {
  static const _channel = MethodChannel('com.flax/network_status');
  static const _eventChannel = EventChannel('com.flax/network_status_events');

  final Connectivity _connectivity;
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();
  StreamSubscription? _nativeSubscription;
  StreamSubscription? _fallbackSubscription;

  NetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  Stream<NetworkStatus> get statusStream => _controller.stream;

  void _init() {
    if (Platform.isAndroid) {
      try {
        _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
            if (event is Map) {
              final status = NetworkStatus.fromMap(event);
              _controller.add(status);
            }
          },
          onError: (err) {
            AppLogger.d(
              'NetworkStatus',
              () => 'Native network event stream error: $err',
            );
            _setupFallbackStream();
          },
        );
      } catch (e) {
        AppLogger.d(
          'NetworkStatus',
          () => 'Failed to initialize native network stream: $e',
        );
        _setupFallbackStream();
      }
    } else {
      _setupFallbackStream();
    }
  }

  void _setupFallbackStream() {
    _fallbackSubscription?.cancel();
    _fallbackSubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _controller.add(NetworkStatus.fromConnectivityList(results));
    });
  }

  /// Retrieves the current network status, prioritizing Android's native
  /// ConnectivityManager default network routing when available.
  Future<NetworkStatus> getNetworkStatus() async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getPrimaryNetworkInfo',
        );
        if (result != null) {
          return NetworkStatus.fromMap(result);
        }
      } catch (e) {
        AppLogger.d(
          'NetworkStatus',
          () => 'Native network status query failed: $e. Falling back.',
        );
      }
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return NetworkStatus.fromConnectivityList(results);
    } catch (_) {
      return const NetworkStatus(primaryTransport: ConnectivityResult.none);
    }
  }

  void dispose() {
    _nativeSubscription?.cancel();
    _fallbackSubscription?.cancel();
    _controller.close();
  }
}
