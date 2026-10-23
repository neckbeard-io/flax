import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/features/settings/device_eq_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/shared/widgets/flax_dropdown.dart';

/// The icon for a kind of output device.
IconData audioDeviceIcon(AudioDeviceType type) => switch (type) {
  AudioDeviceType.bluetooth => Icons.bluetooth_audio,
  AudioDeviceType.usbDac => Icons.usb,
  AudioDeviceType.headphoneJack => Icons.headphones,
  AudioDeviceType.builtinSpeaker => Icons.speaker,
  AudioDeviceType.hdmiOptical => Icons.settings_input_hdmi,
  AudioDeviceType.other => Icons.volume_up,
};

/// A device's name as shown: "System Default" is the one name flax makes up.
String audioDeviceLabel(BuildContext context, AudioDeviceRecord device) {
  if (device.isSystemDefault && device.customName == null) {
    return AppLocalizations.of(context)?.systemDefault ?? 'System Default';
  }
  return device.displayName;
}

/// A profile's name, marked when it is its device's default.
String eqProfileLabel(BuildContext context, DeviceEqProfile profile) {
  if (!profile.isDeviceDefault) return profile.profileName;
  return AppLocalizations.of(
        context,
      )?.eqProfileDefaultName(profile.profileName) ??
      '${profile.profileName} (default)';
}

enum _ProfileAction { create, rename, makeDefault, delete, manage }

/// The output device and its EQ profiles, at the top of the Equalizer screen.
/// Issue #69.
class DeviceProfileBar extends ConsumerWidget {
  const DeviceProfileBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceEqStateProvider);
    final device = state.device;
    if (device == null) return const SizedBox.shrink();
    final controller = ref.read(deviceEqControllerProvider);
    final active = state.activeProfile;

    final bar = DeviceProfileBarView(
      deviceName: audioDeviceLabel(context, device),
      deviceType: device.type,
      profiles: state.profiles,
      activeProfileId: state.activeProfileId,
      autoSwitch: device.autoSwitch,
      onSelect: controller.selectProfile,
      onAutoSwitch: controller.setAutoSwitch,
      onNew: () async {
        final l10n = AppLocalizations.of(context);
        final name = await showNameDialog(
          context,
          title: l10n?.eqProfileNew ?? 'New profile…',
          initial: '',
          helper:
              l10n?.eqProfileNewHelper ??
              'Starts as a copy of the current settings. Changes are saved '
                  'to the profile in use as you make them.',
          confirm: l10n?.save ?? 'Save',
        );
        if (name != null) await controller.saveAsNewProfile(name);
      },
      onRename: active == null
          ? null
          : () async {
              final l10n = AppLocalizations.of(context);
              final name = await showNameDialog(
                context,
                title: l10n?.eqProfileRename ?? 'Rename profile…',
                initial: active.profileName,
                confirm: l10n?.rename ?? 'Rename',
              );
              if (name != null) {
                await controller.renameProfile(active.id, name);
              }
            },
      onMakeDefault: active == null || active.isDeviceDefault
          ? null
          : () => controller.setDefaultProfile(device.deviceId, active.id),
      onDelete: active == null || state.profiles.length < 2
          ? null
          : () async {
              final confirmed = await confirmDeleteProfile(context, active);
              if (confirmed) await controller.deleteProfile(active.id);
            },
      onManage: () => context.push('/settings/audio-devices'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, const Divider(height: 1)],
    );
  }
}

/// [DeviceProfileBar] without providers or a router, for tests.
class DeviceProfileBarView extends StatelessWidget {
  const DeviceProfileBarView({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.profiles,
    required this.activeProfileId,
    required this.autoSwitch,
    required this.onSelect,
    required this.onAutoSwitch,
    required this.onNew,
    this.onRename,
    this.onMakeDefault,
    this.onDelete,
    required this.onManage,
  });

  final String deviceName;
  final AudioDeviceType deviceType;
  final List<DeviceEqProfile> profiles;
  final String? activeProfileId;
  final bool autoSwitch;
  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onAutoSwitch;
  final VoidCallback onNew;

  /// Null disables the action: no profile is active, or it is already the
  /// default, or it is the device's only profile.
  final VoidCallback? onRename;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = profiles.any((p) => p.id == activeProfileId)
        ? activeProfileId
        : null;

    final picker = Container(
      key: const ValueKey('eq-profile-picker'),
      height: 40,
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: FlaxDropdown<String?>(
          value: active,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.arrow_drop_down, size: 20),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          items: [
            if (active == null)
              DropdownMenuItem<String?>(
                value: null,
                enabled: false,
                child: Text(
                  l10n?.eqNoProfile ?? 'No profile',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            for (final profile in profiles)
              DropdownMenuItem<String?>(
                value: profile.id,
                child: Text(
                  eqProfileLabel(context, profile),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null && id != active) onSelect(id);
          },
        ),
      ),
    );

    final autoSwitchToggle = Tooltip(
      message:
          l10n?.eqAutoSwitchTooltip ??
          "Switch to this device's default profile whenever it becomes the "
              'output',
      child: InkWell(
        key: const ValueKey('eq-auto-switch'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => onAutoSwitch(!autoSwitch),
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: autoSwitch, onChanged: onAutoSwitch),
              Flexible(
                child: Text(
                  l10n?.eqAutoSwitch ?? 'Auto-switch',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final menu = PopupMenuButton<_ProfileAction>(
      key: const ValueKey('eq-profile-actions'),
      tooltip: l10n?.eqProfileActions ?? 'Profile actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _ProfileAction.create:
            onNew();
          case _ProfileAction.rename:
            onRename?.call();
          case _ProfileAction.makeDefault:
            onMakeDefault?.call();
          case _ProfileAction.delete:
            onDelete?.call();
          case _ProfileAction.manage:
            onManage();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ProfileAction.create,
          child: Text(l10n?.eqProfileNew ?? 'New profile…'),
        ),
        PopupMenuItem(
          value: _ProfileAction.rename,
          enabled: onRename != null,
          child: Text(l10n?.eqProfileRename ?? 'Rename profile…'),
        ),
        PopupMenuItem(
          value: _ProfileAction.makeDefault,
          enabled: onMakeDefault != null,
          child: Text(l10n?.eqProfileMakeDefault ?? 'Make default'),
        ),
        PopupMenuItem(
          value: _ProfileAction.delete,
          enabled: onDelete != null,
          child: Text(l10n?.eqProfileDelete ?? 'Delete profile'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ProfileAction.manage,
          child: Text(l10n?.audioDevicesManage ?? 'Manage devices'),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                audioDeviceIcon(deviceType),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n?.eqOutputDevice ?? 'Output device',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [picker, autoSwitchToggle],
          ),
        ],
      ),
    );
  }
}

/// Asks for a name. Null when canceled; empty only when [allowEmpty].
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirm,
  String? label,
  String? helper,
  bool allowEmpty = false,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => _NameDialog(
      title: title,
      initial: initial,
      confirm: confirm,
      label: label,
      helper: helper,
    ),
  );
  if (name == null || (name.isEmpty && !allowEmpty)) return null;
  return name;
}

/// Owns its text controller, so the field outlives nothing it depends on
/// while the dialog animates away.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.confirm,
    this.label,
    this.helper,
  });

  final String title;
  final String initial;
  final String confirm;
  final String? label;
  final String? helper;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label ?? l10n?.eqProfileNameLabel ?? 'Profile name',
          helperText: widget.helper,
          helperMaxLines: 4,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}

Future<bool> confirmDeleteProfile(
  BuildContext context,
  DeviceEqProfile profile,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        l10n?.eqProfileDeleteTitle(profile.profileName) ??
            'Delete ${profile.profileName}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n?.delete ?? 'Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
