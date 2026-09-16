import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

import 'package:flax/shared/widgets/layout_metrics.dart';

/// Prominent top-of-screen banner displayed when an upstream Navidrome 0.64.0+
/// item ID migration is detected for the active server.
class ServerMigrationBanner extends ConsumerWidget {
  const ServerMigrationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    if (server == null) return const SizedBox.shrink();

    final hasAlert = ref.watch(
      serverMigrationAlertProvider.select((m) => m[server.id] == true),
    );
    if (!hasAlert) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final mediaQuery = MediaQuery.of(context);
    final topMargin = isDesktopPlatform
        ? (mediaQuery.padding.top + 44.0)
        : (mediaQuery.padding.top > 0 ? mediaQuery.padding.top + 4.0 : 8.0);

    return Container(
      margin: EdgeInsets.fromLTRB(16, topMargin, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: errorColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: errorColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Navidrome 0.64+ ID Migration Detected',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Navidrome server was upgraded to 0.64+. Upstream library item IDs have changed. '
                      'Existing cached tracks, lyrics, and local index entries use obsolete IDs and will not play or sync until re-indexed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => dismissMigrationAlert(ref, server.id),
                tooltip: 'Dismiss alert',
                color: theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: errorColor,
                  foregroundColor: theme.colorScheme.onError,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset & Re-sync Library'),
                onPressed: () =>
                    showResetAndResyncMigrationDialog(context, ref, server),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  side: BorderSide(color: errorColor.withValues(alpha: 0.6)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Clean Orphaned Files'),
                onPressed: () => cleanOrphanedFilesAction(context, ref, server),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Storage Settings'),
                onPressed: () => context.go('/settings/metadata-cache'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dismisses the migration alert for [serverId] in memory and in the persistent database.
Future<void> dismissMigrationAlert(WidgetRef ref, String serverId) async {
  ref.read(serverMigrationAlertProvider.notifier).clearAlert(serverId);
  try {
    await ref
        .read(libraryDaoProvider)
        .deleteSyncValue(serverId, SyncKeys.migrationDetected);
  } catch (_) {}
}

/// Displays the confirmation dialog to perform a full server data reset and immediate re-sync.
Future<void> showResetAndResyncMigrationDialog(
  BuildContext context,
  WidgetRef ref,
  Server server,
) async {
  final theme = Theme.of(context);
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset & Re-sync Library?'),
      content: const Text(
        'This will remove all downloaded audio, lyrics, cached artwork, and local library metadata for this server, and immediately perform a fresh synchronization.\n\nRecommended for servers updated to Navidrome 0.64.0 to adopt newly assigned upstream item IDs.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reset & Re-sync'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await ref.read(audioCacheServiceProvider).resetServerData(server.id);
    await ref
        .read(libraryDaoProvider)
        .deleteSyncValue(server.id, SyncKeys.migrationDetected);
    ref.read(serverMigrationAlertProvider.notifier).clearAlert(server.id);
    ref.invalidate(audioCacheSummaryProvider(server.id));
    ref.invalidate(metadataCacheSummaryProvider(server.id));
    ref.invalidate(albumsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Library reset. Starting fresh synchronization...'),
        ),
      );
      final syncService = ref.read(metadataSyncServiceProvider);
      final client =
          ref.read(subsonicClientProvider) ?? SubsonicClient(server: server);
      final dao = ref.read(libraryDaoProvider);
      await syncService.startSync(server: server, client: client, dao: dao);
    }
  }
}

/// Runs the orphaned cache file sweeper and shows feedback.
Future<void> cleanOrphanedFilesAction(
  BuildContext context,
  WidgetRef ref,
  Server server,
) async {
  final result = await ref
      .read(audioCacheServiceProvider)
      .cleanupOrphanedFiles(server.id);
  ref.invalidate(audioCacheSummaryProvider(server.id));
  if (context.mounted) {
    final mb = (result.bytesFreed / (1024 * 1024)).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cleaned ${result.filesDeleted} orphaned files ($mb MB freed)',
        ),
      ),
    );
  }
}
