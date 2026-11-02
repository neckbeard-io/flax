import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/services/platform/car_connection_service.dart';

/// Whether flax is on screen, as AppChrome last saw the app's lifecycle.
///
/// True until AppChrome says otherwise, so tests that never build it, and
/// the moments before it first runs, behave as they always have.
final appVisibleProvider = StateProvider<bool>((ref) => true);

/// Whether music is playing. PlayerNotifier keeps it current; it lives here
/// so background work can ask without creating the player.
final playbackActiveProvider = StateProvider<bool>((ref) => false);

/// Whether anyone is using flax: it is on screen, playing, or in a car.
///
/// Work that wakes the radio on a schedule, the library check and the
/// reachability retry, runs only while this is true. Left in front with the
/// screen locked, Android does not freeze flax, and both kept polling all day
/// (#192). Nothing is missed by stopping: coming back to the foreground
/// checks the server and syncs, and a request that fails while playing or in
/// the car starts the retry again.
final appInUseProvider = Provider<bool>(
  (ref) =>
      ref.watch(appVisibleProvider) ||
      ref.watch(playbackActiveProvider) ||
      ref.watch(isCarConnectedProvider),
);
