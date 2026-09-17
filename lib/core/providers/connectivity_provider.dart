import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/services/platform/network_status_service.dart';

/// Service that monitors native primary network adapter status.
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService();
  ref.onDispose(service.dispose);
  return service;
});

/// High-fidelity NetworkStatus stream.
final networkStatusStreamProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkStatusServiceProvider);
  return service.statusStream;
});

/// Current high-fidelity NetworkStatus snapshot.
final networkStatusProvider = FutureProvider<NetworkStatus>((ref) async {
  final service = ref.watch(networkStatusServiceProvider);
  return await service.getNetworkStatus();
});

/// Stream of connectivity changes that honors the PRIMARY network adapter.
/// Secondary non-internet adapters (like wireless Android Auto Wi-Fi links)
/// are filtered so the app correctly reflects the active internet route (Cellular).
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  final service = ref.watch(networkStatusServiceProvider);
  return service.statusStream.map((status) => status.toConnectivityList());
});

/// Current connectivity state based on the primary network adapter.
final connectivityProvider = FutureProvider<List<ConnectivityResult>>((
  ref,
) async {
  final service = ref.watch(networkStatusServiceProvider);
  final status = await service.getNetworkStatus();
  return status.toConnectivityList();
});
