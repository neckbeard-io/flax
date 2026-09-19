import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/hotkeys/hotkey_service.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

class HotkeysScreen extends ConsumerWidget {
  const HotkeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDesktop = isDesktopPlatform;

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          leading: const UpBackButton(fallbackLocation: '/settings'),
          title: const Text('Keyboard Shortcuts'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Keyboard shortcuts and global hotkeys are only available on desktop platforms (macOS, Windows, and Linux).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hotKeyState = ref.watch(hotKeyServiceProvider);
    final hotKeyNotifier = ref.read(hotKeyServiceProvider.notifier);
    final hasAssignedHotkeys = hotKeyState.bindings.values.any(
      (k) => k != null,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: const Text('Keyboard Shortcuts'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // ── Global Hotkeys Section ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final buttons = [
                      TextButton.icon(
                        onPressed: () =>
                            hotKeyNotifier.applySuggestedDefaults(),
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('Use Suggested'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      if (hasAssignedHotkeys)
                        TextButton.icon(
                          onPressed: () =>
                              _confirmClearAll(context, hotKeyNotifier),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                          ),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ];

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GLOBAL HOTKEYS',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(spacing: 8, runSpacing: 4, children: buttons),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Text(
                          'GLOBAL HOTKEYS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        ...buttons,
                      ],
                    );
                  },
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
                  onTap: hotKeyState.enabled
                      ? () => _showRecordDialog(context, ref, action, hotKey)
                      : null,
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
                            ? () => _showRecordDialog(
                                context,
                                ref,
                                action,
                                hotKey,
                              )
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

              // ── In-App Shortcuts Section ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
        ),
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
      await hotKeyNotifier.clearAll();
    }
  }

  Future<void> _showRecordDialog(
    BuildContext context,
    WidgetRef ref,
    HotKeyAction action,
    HotKey? currentHotKey,
  ) async {
    ref.read(isRecordingHotKeyProvider.notifier).state = true;
    try {
      await showDialog<void>(
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
    } finally {
      ref.read(isRecordingHotKeyProvider.notifier).state = false;
    }
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
  List<HotKeyModifier> _currentModifiers = [];

  @override
  void initState() {
    super.initState();
    _recordedHotKey = widget.currentHotKey;
    _currentModifiers = widget.currentHotKey?.modifiers ?? [];
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final physicalKeys = HardwareKeyboard.instance.physicalKeysPressed;
      final modifiers = HotKeyModifier.values
          .where((m) => m.physicalKeys.any(physicalKeys.contains))
          .toList();
      if (_currentModifiers.length != modifiers.length) {
        setState(() {
          _currentModifiers = modifiers;
        });
      }
      return false;
    }

    final physicalKeys = HardwareKeyboard.instance.physicalKeysPressed;
    final pressedKey = event.physicalKey;

    final modifiers = HotKeyModifier.values
        .where((m) => m.physicalKeys.any(physicalKeys.contains))
        .toList();

    // If key is only a modifier, update active modifier indicators
    if (HotKeyModifier.values.any((m) => m.physicalKeys.contains(pressedKey))) {
      setState(() {
        _currentModifiers = modifiers;
      });
      return false;
    }

    setState(() {
      _currentModifiers = modifiers;
      _recordedHotKey = HotKey(
        identifier: 'flax_hotkey_${widget.action.name}',
        key: pressedKey,
        modifiers: modifiers,
        scope: HotKeyScope.system,
      );
    });

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMac = !kIsWeb && Platform.isMacOS;

    final currentText = _recordedHotKey != null
        ? formatHotKey(_recordedHotKey!)
        : 'Press keys to record shortcut';

    final modifierDefinitions = isMac
        ? [
            (HotKeyModifier.meta, '⌘ Command'),
            (HotKeyModifier.alt, '⌥ Option'),
            (HotKeyModifier.control, '⌃ Control'),
            (HotKeyModifier.shift, '⇧ Shift'),
          ]
        : [
            (HotKeyModifier.control, 'Ctrl'),
            (HotKeyModifier.alt, 'Alt'),
            (HotKeyModifier.shift, 'Shift'),
            (HotKeyModifier.meta, 'Win'),
          ];

    final hasModifiers = _recordedHotKey?.modifiers?.isNotEmpty ?? false;
    final suggested = widget.action.suggestedHotKey();

    return AlertDialog(
      title: Text('Shortcut: ${widget.action.label}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.action.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modifier Keys (Hold one or more):',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: modifierDefinitions.map((item) {
                final mod = item.$1;
                final label = item.$2;
                final isHeld =
                    _currentModifiers.contains(mod) ||
                    (_recordedHotKey?.modifiers?.contains(mod) ?? false);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isHeld
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHeld
                          ? theme.colorScheme.primary
                          : theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isHeld ? FontWeight.bold : FontWeight.normal,
                      color: isHeld
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _recordedHotKey != null
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    currentText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _recordedHotKey != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Listening for keypresses...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _recordedHotKey = suggested;
                  _currentModifiers = suggested.modifiers ?? [];
                });
              },
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text('Use Suggested (${formatHotKey(suggested)})'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (!hasModifiers && _recordedHotKey != null) ...[
              const SizedBox(height: 8),
              Text(
                'Note: Global shortcuts require at least one modifier key so normal typing is not hijacked in other apps.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _recordedHotKey = null;
              _currentModifiers = [];
            });
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_recordedHotKey != null && !hasModifiers)
              ? null
              : () {
                  widget.onSave(_recordedHotKey);
                  Navigator.pop(context);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
