import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity changes (Wi-Fi, mobile/cellular, ethernet, none).
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

/// Current connectivity state.
final connectivityProvider = FutureProvider<List<ConnectivityResult>>((
  ref,
) async {
  try {
    return await Connectivity().checkConnectivity();
  } catch (_) {
    return [ConnectivityResult.wifi];
  }
});
