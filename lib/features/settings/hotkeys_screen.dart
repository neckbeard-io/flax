import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/hotkeys/hotkey_service.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

class HotkeysScreen extends ConsumerWidget {
  const HotkeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hotKeyState = ref.watch(hotKeyServiceProvider);
    final hotKeyNotifier = ref.read(hotKeyServiceProvider.notifier);
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    final hasAssignedHotkeys = hotKeyState.bindings.values.any(
      (k) => k != null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard Shortcuts')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ── Global Hotkeys Section ──
          if (isDesktop) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GLOBAL HOTKEYS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (hasAssignedHotkeys)
                    TextButton.icon(
                      onPressed: () =>
                          _confirmClearAll(context, hotKeyNotifier),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Enable Global Hotkeys'),
              subtitle: const Text(
                'Allow controlling playback with shortcuts even when Flax is in the background or minimized',
              ),
              value: hotKeyState.enabled,
              onChanged: (v) => hotKeyNotifier.setEnabled(v),
            ),
            const Divider(),
            ...HotKeyAction.values.map((action) {
              final hotKey = hotKeyState.bindings[action];
              final error = hotKeyState.errors[action];

              return ListTile(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        action.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            'Shortcut conflict: could not register with OS ($error)',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  error != null
                      ? 'Shortcut unavailable (conflict with another app)'
                      : action.description,
                  style: error != null
                      ? theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        )
                      : theme.textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HotKeyPill(
                      hotKey: hotKey,
                      enabled: hotKeyState.enabled,
                      hasError: error != null,
                      onTap: hotKeyState.enabled
                          ? () =>
                                _showRecordDialog(context, ref, action, hotKey)
                          : null,
                    ),
                    if (hotKey != null && hotKeyState.enabled) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Clear shortcut',
                        onPressed: () =>
                            hotKeyNotifier.updateBinding(action, null),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const Divider(),
          ],

          // ── In-App Shortcuts Section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'IN-APP SHORTCUTS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const _InAppShortcutTile(
            label: 'Search',
            description: 'Focus quick search field in sidebar',
            shortcut: '/',
          ),
          const _InAppShortcutTile(
            label: 'Play / Pause',
            description: 'Toggle playback when window is focused',
            shortcut: 'Space',
          ),
          const _InAppShortcutTile(
            label: 'Back Navigation',
            description: 'Return to previous screen',
            shortcut: 'Mouse 4 / Swipe Right',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    HotKeyNotifier hotKeyNotifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all shortcuts?'),
        content: const Text('Remove all custom global hotkey combinations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await hotKeyNotifier.resetToDefaults();
    }
  }

  void _showRecordDialog(
    BuildContext context,
    WidgetRef ref,
    HotKeyAction action,
    HotKey? currentHotKey,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RecordHotKeyDialog(
        action: action,
        currentHotKey: currentHotKey,
        onSave: (newHotKey) {
          ref
              .read(hotKeyServiceProvider.notifier)
              .updateBinding(action, newHotKey);
        },
      ),
    );
  }
}

class _HotKeyPill extends StatelessWidget {
  final HotKey? hotKey;
  final bool enabled;
  final bool hasError;
  final VoidCallback? onTap;

  const _HotKeyPill({
    required this.hotKey,
    required this.enabled,
    required this.hasError,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = hotKey != null ? formatHotKey(hotKey!) : 'Not Set';

    final Color bgColor;
    final Color textColor;
    if (!enabled) {
      bgColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.4,
      );
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    } else if (hasError) {
      bgColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
    } else if (hotKey == null) {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.outline;
    } else {
      bgColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
    }

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError
              ? theme.colorScheme.error
              : theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (onTap != null) {
      pill = HoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: pill,
      );
    }

    return pill;
  }
}

class _InAppShortcutTile extends StatelessWidget {
  final String label;
  final String description;
  final String shortcut;

  const _InAppShortcutTile({
    required this.label,
    required this.description,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      subtitle: Text(description),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          shortcut,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RecordHotKeyDialog extends StatefulWidget {
  final HotKeyAction action;
  final HotKey? currentHotKey;
  final ValueChanged<HotKey?> onSave;

  const _RecordHotKeyDialog({
    required this.action,
    required this.currentHotKey,
    required this.onSave,
  });

  @override
  State<_RecordHotKeyDialog> createState() => _RecordHotKeyDialogState();
}

class _RecordHotKeyDialogState extends State<_RecordHotKeyDialog> {
  HotKey? _recordedHotKey;

  @override
  void initState() {
    super.initState();
    _recordedHotKey = widget.currentHotKey;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;

    final physicalKeys = HardwareKeyboard.instance.physicalKeysPressed;
    final pressedKey = event.physicalKey;

    final modifiers = HotKeyModifier.values
        .where((m) => m.physicalKeys.any(physicalKeys.contains))
        .toList();

    // If key is only a modifier, don't record as the primary key
    if (HotKeyModifier.values.any((m) => m.physicalKeys.contains(pressedKey))) {
      return false;
    }

    setState(() {
      _recordedHotKey = HotKey(
        identifier: 'flax_hotkey_${widget.action.name}',
        key: pressedKey,
        modifiers: modifiers.isEmpty ? null : modifiers,
        scope: HotKeyScope.system,
      );
    });

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentText = _recordedHotKey != null
        ? formatHotKey(_recordedHotKey!)
        : 'None';

    return AlertDialog(
      title: Text('Shortcut: ${widget.action.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Press the new key combination (e.g. Cmd+Option+Space or Ctrl+Alt+Right).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Text(
                  currentText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Recording keypresses...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _recordedHotKey = null;
            });
          },
          child: const Text('Clear'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_recordedHotKey);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
