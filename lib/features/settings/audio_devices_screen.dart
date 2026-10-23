import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flax/features/settings/device_eq_provider.dart';
import 'package:flax/features/settings/device_profile_bar.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Every output flax has played through, with the EQ profiles saved for each.
/// Issue #69.
class AudioDevicesScreen extends ConsumerWidget {
  const AudioDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devices = ref.watch(audioDeviceListProvider).valueOrNull;
    final profiles = ref.watch(allDeviceProfilesProvider).valueOrNull ?? [];
    final current = ref.watch(
      deviceEqStateProvider.select((s) => s.device?.deviceId),
    );

    return Scaffold(
      appBar: AppBar(
        // Keeps the title out from under the window controls.
        actions: [SizedBox(width: WindowControlsInset.of(context))],
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: Text(l10n?.audioDevices ?? 'Audio Devices'),
      ),
      body: devices == null
          ? const Center(child: CircularProgressIndicator())
          : AudioDeviceList(
              devices: devices,
              profiles: profiles,
              currentDeviceId: current,
              actions: _ControllerActions(ref.read(deviceEqControllerProvider)),
            ),
    );
  }
}

/// What the list can ask for. An interface so the list can be tested without
/// a database or a platform.
abstract class AudioDeviceActions {
  Future<void> setAutoSwitch(String deviceId, bool enabled);
  Future<void> setDefaultProfile(String deviceId, String profileId);
  Future<void> deleteProfile(String profileId);
  Future<void> renameDevice(String deviceId, String? name);
  Future<void> deleteDevice(String deviceId);
}

class _ControllerActions implements AudioDeviceActions {
  _ControllerActions(this._controller);

  final DeviceEqController _controller;

  @override
  Future<void> setAutoSwitch(String deviceId, bool enabled) =>
      _controller.setDeviceAutoSwitch(deviceId, enabled);

  @override
  Future<void> setDefaultProfile(String deviceId, String profileId) =>
      _controller.setDefaultProfile(deviceId, profileId);

  @override
  Future<void> deleteProfile(String profileId) =>
      _controller.deleteProfile(profileId);

  @override
  Future<void> renameDevice(String deviceId, String? name) =>
      _controller.renameDevice(deviceId, name);

  @override
  Future<void> deleteDevice(String deviceId) =>
      _controller.deleteDevice(deviceId);
}

/// The device list itself, without providers.
class AudioDeviceList extends StatelessWidget {
  const AudioDeviceList({
    super.key,
    required this.devices,
    required this.profiles,
    required this.currentDeviceId,
    required this.actions,
  });

  final List<AudioDeviceRecord> devices;
  final List<DeviceEqProfile> profiles;
  final String? currentDeviceId;
  final AudioDeviceActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n?.audioDevicesEmpty ??
                'No devices yet. The output in use is added here once flax '
                    'plays through it.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      children: [
        for (final device in devices)
          _DeviceTile(
            key: ValueKey(device.deviceId),
            device: device,
            profiles: [
              for (final p in profiles)
                if (p.deviceId == device.deviceId) p,
            ],
            connected: device.deviceId == currentDeviceId,
            actions: actions,
          ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    super.key,
    required this.device,
    required this.profiles,
    required this.connected,
    required this.actions,
  });

  final AudioDeviceRecord device;
  final List<DeviceEqProfile> profiles;
  final bool connected;
  final AudioDeviceActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final when = connected
        ? l10n?.audioDeviceConnected ?? 'Connected now'
        : l10n?.audioDeviceLastUsed(
                DateFormat.yMMMd(locale).format(device.lastSeenAt),
              ) ??
              'Last used ${DateFormat.yMMMd(locale).format(device.lastSeenAt)}';
    final count =
        l10n?.eqProfileCount(profiles.length) ??
        '${profiles.length} profile${profiles.length == 1 ? '' : 's'}';

    final forget = OutlinedButton.icon(
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(l10n?.audioDeviceForget ?? 'Forget device'),
      onPressed: connected ? null : () => _forget(context),
    );

    return ExpansionTile(
      leading: Icon(
        audioDeviceIcon(device.type),
        color: connected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        audioDeviceLabel(context, device),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$when · $count'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        SwitchListTile(
          title: Text(l10n?.audioDeviceAutoSwitch ?? 'Switch EQ automatically'),
          subtitle: Text(
            l10n?.audioDeviceAutoSwitchSubtitle ??
                'Restores the default profile when this device becomes the '
                    'output',
          ),
          value: device.autoSwitch,
          onChanged: (v) => actions.setAutoSwitch(device.deviceId, v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n?.audioDeviceDefaultProfile ?? 'Default profile',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final profile in profiles)
          ListTile(
            leading: Icon(
              profile.isDeviceDefault
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: profile.isDeviceDefault ? theme.colorScheme.primary : null,
            ),
            title: Text(
              profile.profileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: profile.isDeviceDefault
                ? null
                : () => actions.setDefaultProfile(device.deviceId, profile.id),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: profiles.length < 2
                  ? l10n?.eqProfileKeepOne ??
                        'A device keeps at least one profile'
                  : l10n?.eqProfileDelete ?? 'Delete profile',
              onPressed: profiles.length < 2
                  ? null
                  : () async {
                      if (await confirmDeleteProfile(context, profile)) {
                        await actions.deleteProfile(profile.id);
                      }
                    },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n?.audioDeviceRename ?? 'Rename device'),
                onPressed: () => _rename(context),
              ),
              if (connected)
                Tooltip(
                  message:
                      l10n?.audioDeviceForgetInUse ??
                      "The device in use can't be forgotten",
                  child: forget,
                )
              else
                forget,
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await showNameDialog(
      context,
      title: l10n?.audioDeviceRename ?? 'Rename device',
      initial: device.customName ?? '',
      confirm: l10n?.rename ?? 'Rename',
      label: l10n?.deviceNameLabel ?? 'Name',
      helper:
          l10n?.audioDeviceRenameHelper ??
          "Leave empty to use the system's name",
      allowEmpty: true,
    );
    if (name != null) await actions.renameDevice(device.deviceId, name);
  }

  Future<void> _forget(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = audioDeviceLabel(context, device);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.audioDeviceForgetTitle(name) ?? 'Forget $name?'),
        content: Text(
          l10n?.audioDeviceForgetMessage ??
              'Its EQ profiles are deleted too. It is added again, with no '
                  'EQ, the next time it is used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.forget ?? 'Forget'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await actions.deleteDevice(device.deviceId);
  }
}
