import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/updater/update_dialog.dart';
import '../../shared/widgets/layout_metrics.dart';
import 'update_provider.dart';

/// Coordinates presenting the update dialog automatically on mobile platforms
/// (Android/iOS) on launch and background resume without cluttering the screen.
class MobileUpdateCoordinator {
  static const String _prefLastPromptedVersionKey =
      'update_last_prompted_version';
  static const String _prefLastPromptedTimeKey = 'update_last_prompted_time';

  /// Whether a dialog is currently open to prevent stacking duplicate modals.
  static bool isShowingDialog = false;

  /// Checks if an update is available and prompts the user on mobile devices.
  ///
  /// On desktop, the update button lives in the top window bar, so a popup is
  /// not needed on launch. On mobile, we prompt the user directly with
  /// changelog highlights and one-click install.
  static Future<void> checkAndPrompt(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Only prompt on mobile / non-desktop platforms
    if (isDesktopPlatform) return;
    if (isShowingDialog) return;

    final updateState = ref.read(updateNotifierProvider);
    if (!updateState.isUpdateAvailable) return;

    final release = updateState.latestRelease;
    if (release == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPromptedVersion = prefs.getString(_prefLastPromptedVersionKey);
    final lastPromptedTimeMs = prefs.getInt(_prefLastPromptedTimeKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Prompt if new version OR if at least 24 hours have passed since last prompt
    final isNewVersion = lastPromptedVersion != release.version;
    final isOver24Hours =
        (nowMs - lastPromptedTimeMs) > const Duration(hours: 24).inMilliseconds;

    if (!isNewVersion && !isOver24Hours) {
      return;
    }

    if (!context.mounted) return;

    await prefs.setString(_prefLastPromptedVersionKey, release.version);
    await prefs.setInt(_prefLastPromptedTimeKey, nowMs);

    isShowingDialog = true;
    try {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => const UpdateDialog(),
        );
      }
    } finally {
      isShowingDialog = false;
    }
  }
}
