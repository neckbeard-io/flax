import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the device's play queue is synchronized with the Subsonic server.
///
/// On by default (matching Subsonic getPlayQueue / savePlayQueue behavior).
/// When turned off, this device's play queue is kept strictly local, preventing
/// other devices from overwriting the queue on startup or queue changes.
final syncQueueWithServerProvider =
    StateNotifierProvider<SyncQueueWithServerNotifier, bool>(
      (ref) => SyncQueueWithServerNotifier(),
    );

class SyncQueueWithServerNotifier extends StateNotifier<bool> {
  static const storageKey = 'flax_sync_queue_with_server';
  static const bool defaultEnabled = true;

  SyncQueueWithServerNotifier() : super(defaultEnabled) {
    _load();
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
