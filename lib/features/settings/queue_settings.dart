import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the play queue is shared with other devices through the server.
///
/// On by default (matching Subsonic getPlayQueue / savePlayQueue behavior):
/// the queue and position are saved to the server, and a launch picks up the
/// queue another device saved there. Off isolates the queue in both
/// directions — it is never saved to the server, and never replaced by the
/// server's. Plays are still reported either way; that is
/// `scrobbleEnabledProvider`'s choice, not this one.
final syncQueueWithServerProvider =
    StateNotifierProvider<SyncQueueWithServerNotifier, bool>(
      (ref) => SyncQueueWithServerNotifier(),
    );

class SyncQueueWithServerNotifier extends StateNotifier<bool> {
  static const storageKey = 'flax_sync_queue_with_server';
  static const bool defaultEnabled = true;

  SyncQueueWithServerNotifier() : super(defaultEnabled) {
    _loading = _load();
  }

  late final Future<void> _loading;

  /// The choice, once the saved one has been read.
  ///
  /// [state] starts at the default, and the saved choice replaces it a moment
  /// later. Anything that acts on the choice as soon as the app starts has to
  /// wait for it: the queue restore read the default instead, and fetched the
  /// server's queue on a device where sharing was off.
  Future<bool> get loaded async {
    await _loading;
    return state;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(storageKey);
      if (saved == null) return;
      state = saved;
    } catch (_) {
      // Keep default on error
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, enabled);
    } catch (_) {
      // Ignore write failures
    }
  }
}
