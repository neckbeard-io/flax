import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/updater/whats_new_provider.dart';

class WhatsNewDialog extends ConsumerStatefulWidget {
  final String version;

  const WhatsNewDialog({super.key, required this.version});

  @override
  ConsumerState<WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends ConsumerState<WhatsNewDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "What's New in v${widget.version}",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flax has been updated to the latest version. Here are the latest improvements:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightItem(
                        icon: Icons.system_update_alt,
                        title: 'Self-Updating Framework',
                        description:
                            'In-app update checks and seamless platform installers.',
                      ),
                      const SizedBox(height: 10),
                      _HighlightItem(
                        icon: Icons.speed,
                        title: 'Performance & Parity',
                        description:
                            'Synchronized monotonic builds and optimized caching.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() {
                  _dontShowAgain = !_dontShowAgain;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dontShowAgain,
                      onChanged: (v) {
                        setState(() {
                          _dontShowAgain = v ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        "Don't show What's New after future updates",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            if (_dontShowAgain) {
              ref
                  .read(showWhatsNewPreferenceProvider.notifier)
                  .setEnabled(false);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _HighlightItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HighlightItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
