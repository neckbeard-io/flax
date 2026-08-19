import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// Background work, shown in the sidebar footer above Settings. Issue #43.
///
/// Split the way the rest of the repo splits things that need testing: the two
/// `*View` widgets below take plain data and no providers, so their geometry and
/// their wording can be tested without a registry, a server, or a router.
/// [ActivityIndicator] is the thin provider-wired wrapper.

/// The collapsed row. Occupies **zero height** when there is nothing running —
/// an always-present empty widget would push Settings off its resting position
/// every time a job started.
class ActivityIndicatorView extends StatelessWidget {
  const ActivityIndicatorView({
    super.key,
    required this.tasks,
    this.onTap,
    this.expanded = false,
  });

  /// Active tasks only. Finished ones belong in the panel, not out here.
  final List<Task> tasks;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final single = tasks.length == 1 ? tasks.first : null;

    final title = single?.label ?? '${tasks.length} background tasks';
    final detail = single == null
        ? _aggregateDetail(tasks)
        : formatCompactLine(single);

    final value = single?.fraction;
    final rate =
        single?.ratePerSecond != null && single?.state == TaskState.running
        ? formatRate(single!.ratePerSecond!, single.kind.unit)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: HoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: expanded
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (rate != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      rate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _aggregateDetail(List<Task> tasks) {
    final running = tasks.where((t) => t.state == TaskState.running).length;
    if (running == 0) return tasks.first.state.label;
    return '$running running';
  }
}

/// The expanded list: one row per task, with whatever controls it supports.
class ActivityPanelView extends StatelessWidget {
  const ActivityPanelView({
    super.key,
    required this.tasks,
    this.onCancel,
    this.onClearFinished,
    this.width = 300,
  });

  /// Active tasks first, then recently finished ones.
  final List<Task> tasks;
  final void Function(Task task)? onCancel;
  final VoidCallback? onClearFinished;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFinished = tasks.any((t) => t.state.isTerminal);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Text(
                'Background tasks',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                itemBuilder: (context, i) =>
                    _TaskRow(task: tasks[i], onCancel: onCancel),
              ),
            ),
            if (hasFinished && onClearFinished != null) ...[
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onClearFinished,
                    child: const Text('Clear finished'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, this.onCancel});

  final Task task;
  final void Function(Task task)? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terminal = task.state.isTerminal;
    final detail = task.error ?? formatProgressLine(task);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (task.ratePerSecond != null &&
                        task.state == TaskState.running) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatRate(task.ratePerSecond!, task.kind.unit),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (!terminal)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.fraction,
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                if (!terminal) const SizedBox(height: 6),
                Text(
                  terminal ? '${task.state.label} · $detail' : detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: task.state == TaskState.failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (task.cancelable && !terminal && onCancel != null)
            HoverIcon(
              icon: Icons.close,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: 'Cancel',
              onTap: () => onCancel!(task),
            ),
        ],
      ),
    );
  }
}

/// Shown only while the panel is open and everything has finished, so the
/// popup keeps an anchor.
class _IdleRow extends StatelessWidget {
  const _IdleRow({required this.expanded, this.onTap});

  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: HoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: expanded
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No background tasks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider-wired wrapper. Anchors the panel to the row, the same way the
/// sidebar's quick-search popup anchors to its field — except upwards, since
/// this sits at the bottom of the rail.
class ActivityIndicator extends ConsumerStatefulWidget {
  const ActivityIndicator({super.key});

  @override
  ConsumerState<ActivityIndicator> createState() => _ActivityIndicatorState();
}

class _ActivityIndicatorState extends ConsumerState<ActivityIndicator> {
  final _link = LayerLink();
  final _panel = OverlayPortalController();

  void _toggle() {
    setState(() {
      if (_panel.isShowing) {
        _panel.hide();
      } else {
        _panel.show();
      }
    });
  }

  Widget _buildPanel(BuildContext context) {
    final tasks = ref.watch(taskRegistryProvider);
    final registry = ref.read(taskRegistryProvider.notifier);
    final ordered = [
      ...tasks.where((t) => t.state.isActive),
      ...tasks.where((t) => t.state.isTerminal),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(_panel.hide),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(8, -6),
          // Aligned bottom-left to match `followerAnchor`, which the sidebar's
          // quick-search popup does not have to do — it opens downwards from
          // topLeft/topLeft, where the two happen to coincide. The follower
          // here is given the whole screen to lay out in, so aligning its child
          // top-left while anchoring its bottom edge to the row put the panel a
          // full screen height above the window. It rendered, invisibly.
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ActivityPanelView(
              tasks: ordered,
              onCancel: (task) => registry.cancel(task.id),
              onClearFinished: registry.clearFinished,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeTasksProvider);

    // Nothing running and no panel open: contribute no height at all.
    if (active.isEmpty && !_panel.isShowing) return const SizedBox.shrink();

    // The last job can finish while the panel is open. Keep a row here so the
    // panel still has something to anchor to — collapsing the target to zero
    // height would fling it across the window.
    final child = active.isEmpty
        ? _IdleRow(expanded: _panel.isShowing, onTap: _toggle)
        : ActivityIndicatorView(
            tasks: active,
            expanded: _panel.isShowing,
            onTap: _toggle,
          );

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _panel,
        overlayChildBuilder: _buildPanel,
        child: child,
      ),
    );
  }
}
