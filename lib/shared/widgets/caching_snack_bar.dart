import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows a non-persistent, queue-aware SnackBar informing the user that items
/// are being cached for offline playback, with a quick action to view downloads.
void showCachingSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // Clear any existing snackbar to prevent stacking or stale notices.
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      // In Flutter 3.22+, SnackBars with an action default to persist: true,
      // remaining visible indefinitely until manually dismissed or clicked.
      // Explicitly setting persist: false ensures it auto-dismisses gracefully.
      persist: false,
      action: SnackBarAction(
        label: 'View',
        onPressed: () => context.push('/downloads'),
      ),
    ),
  );
}

/// Shows a transient feedback SnackBar when items are removed from the offline cache.
void showCacheRemovedSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: duration, persist: false),
  );
}
