import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

/// A compact, animated mobile status pill shown in top app bars when background
/// download or cache tasks are actively running.
class MobileActiveDownloadsPill extends ConsumerWidget {
  const MobileActiveDownloadsPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only displayed on mobile viewports (desktop has sidebar ActivityIndicator)
    if (isDesktopPlatform) return const SizedBox.shrink();

    final activeTasks = ref.watch(activeTasksProvider);
    if (activeTasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final downloadTasks = activeTasks
        .where((t) => t.kind == TaskKind.audioDownload)
        .toList();
    final primaryTask = downloadTasks.isNotEmpty
        ? downloadTasks.first
        : activeTasks.first;

    final doneCount = activeTasks.fold<int>(0, (sum, t) => sum + t.itemsDone);
    final totalCount = activeTasks.fold<int?>(
      0,
      (sum, t) =>
          sum != null && t.itemsTotal != null ? sum + t.itemsTotal! : null,
    );

    final fraction = primaryTask.fraction;
    final rate = primaryTask.ratePerSecond;
    final rateStr = rate != null && rate > 0
        ? '${rate < 10 ? rate.toStringAsFixed(1) : rate.round()} items/s'
        : null;

    final label = totalCount != null && totalCount > 0
        ? '$doneCount/$totalCount'
        : (rateStr ?? 'Downloading');

    return Tooltip(
      message: 'Active background tasks · Tap to view downloads',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/downloads'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.downloading,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
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
