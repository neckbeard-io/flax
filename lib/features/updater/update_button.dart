import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/updater/update_provider.dart';
import 'update_dialog.dart';

class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(updateNotifierProvider);

    if (!state.isUpdateAvailable) {
      return const SizedBox.shrink();
    }

    final release = state.latestRelease;
    final versionLabel = release != null ? 'v${release.version}' : 'Update';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (_) => const UpdateDialog(),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isReadyToInstall
                      ? Icons.check_circle
                      : state.isDownloading
                      ? Icons.downloading
                      : Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  state.isReadyToInstall
                      ? 'Ready to install'
                      : state.isDownloading
                      ? '${(state.downloadProgress * 100).toInt()}%'
                      : versionLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
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
