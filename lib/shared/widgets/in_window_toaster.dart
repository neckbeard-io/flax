import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';

/// In-window toaster notification.
///
/// Displays transient system notices (such as server reachability fallback)
/// smoothly inside the window overlay without blocking user interactions.
class InWindowToaster extends ConsumerWidget {
  const InWindowToaster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(offlineToastMessageProvider);
    final theme = Theme.of(context);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: message != null ? 36 : -80,
      left: 20,
      right: 20,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: message != null ? 1.0 : 0.0,
          child: message != null
              ? Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(24),
                  color: theme.colorScheme.inverseSurface,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 18,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            ref
                                .read(offlineToastMessageProvider.notifier)
                                .dismiss();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.colorScheme.onInverseSurface
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
