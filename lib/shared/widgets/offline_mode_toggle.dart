import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/services/cache/storage_manager.dart';

/// Desktop toggle button for Offline Mode.
///
/// Sits in the top-right window chrome near the update button. A left-to-right
/// slider-style pill that indicates and controls whether the app is in Offline mode.
class OfflineModeToggle extends ConsumerWidget {
  const OfflineModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOffline = ref.watch(isOfflineModeProvider);
    final reason = ref.watch(offlineReasonProvider);
    final isProbing = ref.watch(
      serverReachabilityProvider.select((s) => s.isProbing),
    );

    final tooltip = switch (reason) {
      OfflineReason.manual => 'Offline mode active (manual override)',
      OfflineReason.cellular => 'Offline mode active (cellular network)',
      OfflineReason.androidAuto => 'Offline mode active (Android Auto)',
      OfflineReason.serverUnreachable =>
        'Offline mode active (server unreachable)',
      OfflineReason.none => 'Toggle Offline mode (only view cached music)',
    };

    final activeColor = switch (reason) {
      OfflineReason.serverUnreachable => theme.colorScheme.error,
      OfflineReason.cellular => Colors.orange[700] ?? theme.colorScheme.primary,
      _ => theme.colorScheme.primary,
    };

    final activeContainerColor = switch (reason) {
      OfflineReason.serverUnreachable =>
        theme.colorScheme.errorContainer.withValues(alpha: 0.8),
      OfflineReason.cellular => Colors.orange.withValues(alpha: 0.2),
      _ => theme.colorScheme.primaryContainer,
    };

    final onActiveContainerColor = switch (reason) {
      OfflineReason.serverUnreachable => theme.colorScheme.onErrorContainer,
      OfflineReason.cellular => Colors.orange[800] ?? theme.colorScheme.primary,
      _ => theme.colorScheme.onPrimaryContainer,
    };

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final manualNotifier = ref.read(
              offlineManualOverrideProvider.notifier,
            );
            if (isOffline) {
              // If offline, turn off manual override and probe server
              await manualNotifier.set(false);
              await ref.read(serverReachabilityProvider.notifier).probeServer();
            } else {
              // Turn on manual override
              await manualNotifier.set(true);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOffline
                  ? activeContainerColor
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOffline
                    ? activeColor.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOffline ? Icons.offline_pin : Icons.cloud_outlined,
                  size: 14,
                  color: isOffline
                      ? onActiveContainerColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Offline',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isOffline ? FontWeight.bold : FontWeight.w500,
                    color: isOffline
                        ? onActiveContainerColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                // Left-to-right slider switch thumb
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 14,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isOffline
                        ? activeColor
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                  ),
                  child: Align(
                    alignment: isOffline
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: isProbing
                          ? const Center(
                              child: SizedBox(
                                width: 6,
                                height: 6,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A warning banner displayed when a previously chosen storage volume is unavailable.
class MissingStorageBanner extends ConsumerWidget {
  const MissingStorageBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missingPath = ref.watch(missingStorageWarningProvider);
    if (missingPath == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sd_card_alert_outlined,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Storage location unavailable',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  'Selected external storage is missing or unmounted. Using internal storage as temporary fallback.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              ref.read(missingStorageWarningProvider.notifier).state = null;
            },
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

/// A prominent status banner shown at the top of library screens when Offline Mode is active
/// or when external storage has fallen back.
class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missingStorage = ref.watch(missingStorageWarningProvider);
    final isOffline = ref.watch(isOfflineModeProvider);

    if (missingStorage == null && !isOffline) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missingStorage != null) const MissingStorageBanner(),
        if (isOffline) const _OfflineStatusInnerBanner(),
      ],
    );
  }
}

class _OfflineStatusInnerBanner extends ConsumerWidget {
  const _OfflineStatusInnerBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(offlineReasonProvider);
    final theme = Theme.of(context);

    final text = switch (reason) {
      OfflineReason.cellular => 'Offline (Cellular streaming disabled)',
      OfflineReason.serverUnreachable => 'Offline (Server unreachable)',
      _ => 'Offline Mode active',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_pin, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$text · Showing downloaded music',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (reason == OfflineReason.manual)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () async {
                await ref
                    .read(offlineManualOverrideProvider.notifier)
                    .set(false);
                await ref
                    .read(serverReachabilityProvider.notifier)
                    .probeServer();
              },
              child: const Text('Go Online'),
            ),
        ],
      ),
    );
  }
}
