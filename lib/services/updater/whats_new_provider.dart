import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/updater/whats_new_dialog.dart';

final showWhatsNewPreferenceProvider =
    StateNotifierProvider<ShowWhatsNewNotifier, bool>((ref) {
      return ShowWhatsNewNotifier();
    });

class ShowWhatsNewNotifier extends StateNotifier<bool> {
  static const String _prefKey = 'whats_new_show_on_update';

  ShowWhatsNewNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}

/// Coordinates checking and presenting the What's New dialog on app startup.
class WhatsNewCoordinator {
  static const String _prefLastSeenVersionKey = 'whats_new_last_seen_version';
  static bool _hasCheckedThisSession = false;

  static Future<void> checkAndShowIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final showEnabled = prefs.getBool(ShowWhatsNewNotifier._prefKey) ?? true;
    if (!showEnabled) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final lastSeen = prefs.getString(_prefLastSeenVersionKey);

    // If this is an upgrade to a newer version
    if (lastSeen != null && lastSeen != currentVersion) {
      await prefs.setString(_prefLastSeenVersionKey, currentVersion);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => WhatsNewDialog(version: currentVersion),
        );
      }
    } else if (lastSeen == null) {
      // First installation - save version so subsequent updates trigger the dialog
      await prefs.setString(_prefLastSeenVersionKey, currentVersion);
    }
  }
}
