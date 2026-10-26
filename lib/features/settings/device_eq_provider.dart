import 'dart:async';
import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/features/settings/audio_output_settings.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/services/audio_devices/audio_device_dao.dart';
import 'package:flax/services/audio_devices/system_output.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/shared/audio/eq_filter.dart';

/// EQ profiles per audio device. Issue #69.
///
/// Each output flax plays through is recorded, with one or more saved EQ
/// setups. When the output changes, the new device's default is put in place;
/// while a profile is active, changes made on the Equalizer screen are saved
/// back to it.

final audioDeviceDaoProvider = Provider<AudioDeviceDao>((ref) {
  return AudioDeviceDao(ref.watch(flaxDatabaseProvider));
});

final systemOutputSourceProvider = Provider<SystemOutputSource>((ref) {
  return SystemOutputSource.forPlatform();
});

/// The physical device behind the system default output.
final systemOutputProvider = StreamProvider<AudioEndpoint>((ref) {
  return ref.watch(systemOutputSourceProvider).watch();
});

/// The device audio is going to: the one chosen under Audio Output, or else
/// whatever the system default is. Null until the platform has answered.
final activeAudioEndpointProvider = Provider<AudioEndpoint?>((ref) {
  final (name, description) = ref.watch(
    audioOutputSettingsProvider.select(
      (s) => (s.deviceName, s.deviceDescription),
    ),
  );
  // mpv's device choice is a desktop setting; Android routes for itself.
  if (!Platform.isAndroid && name != 'auto') {
    return AudioEndpoint(
      id: normalizeMpvDeviceId(name),
      name: description,
      type: classifyDevice(name, description),
    );
  }
  final system = ref.watch(systemOutputProvider).valueOrNull;
  if (system == null || !Platform.isLinux) return system;

  // pactl only knows the sink's name; mpv's device list has its description.
  final described = ref
      .watch(audioDevicesProvider)
      .firstWhereOrNull((d) => normalizeMpvDeviceId(d.name) == system.id);
  if (described == null || described.description.isEmpty) return system;
  return AudioEndpoint(
    id: system.id,
    name: described.description,
    type: classifyDevice(described.name, described.description),
  );
});

/// Every device seen, most recently used first.
final audioDeviceListProvider = StreamProvider<List<AudioDeviceRecord>>((ref) {
  return ref.watch(audioDeviceDaoProvider).watchDevices();
});

/// Every saved profile, for the device list.
final allDeviceProfilesProvider = StreamProvider<List<DeviceEqProfile>>((ref) {
  return ref.watch(audioDeviceDaoProvider).watchAllProfiles();
});

class DeviceEqState {
  const DeviceEqState({
    this.device,
    this.profiles = const [],
    this.activeProfileId,
    this.deviceCount = 0,
  });

  /// The output audio is going to, once it has been recorded.
  final AudioDeviceRecord? device;

  /// [device]'s profiles.
  final List<DeviceEqProfile> profiles;

  /// The profile the equalizer is showing and saving to. Null when the device
  /// does not switch automatically and none has been picked.
  final String? activeProfileId;

  /// How many devices are recorded, for the settings tile.
  final int deviceCount;

  DeviceEqProfile? get activeProfile =>
      profiles.firstWhereOrNull((p) => p.id == activeProfileId);

  DeviceEqState copyWith({
    AudioDeviceRecord? device,
    List<DeviceEqProfile>? profiles,
    String? activeProfileId,
    bool clearActive = false,
    int? deviceCount,
  }) => DeviceEqState(
    device: device ?? this.device,
    profiles: profiles ?? this.profiles,
    activeProfileId: clearActive
        ? null
        : (activeProfileId ?? this.activeProfileId),
    deviceCount: deviceCount ?? this.deviceCount,
  );
}

/// What the screens show. Passive: watching it starts nothing, so a screen can
/// be built without a database or a platform to ask. [DeviceEqController]
/// writes it.
final deviceEqStateProvider = StateProvider<DeviceEqState>(
  (ref) => const DeviceEqState(),
);

/// Started by the player; read by screens only to act.
final deviceEqControllerProvider = Provider<DeviceEqController>((ref) {
  final controller = DeviceEqController(ref, ref.watch(audioDeviceDaoProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

class DeviceEqController {
  DeviceEqController(
    this._ref,
    this._dao, {
    this._settle = const Duration(milliseconds: 500),
    this._saveDelay = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _endpointSub = _ref.listen<AudioEndpoint?>(
      activeAudioEndpointProvider,
      (_, next) => _onEndpoint(next),
      fireImmediately: true,
    );
    _eqSub = _ref.listen<EqState>(eqProvider, (_, _) => _scheduleSave());
    _autoEqSub = _ref.listen<AutoEqState>(
      autoEqProvider,
      (_, _) => _scheduleSave(),
    );
    _engineSub = _ref.listen<EqEngine>(
      eqEngineProvider,
      (_, _) => _scheduleSave(),
    );
  }

  final Ref _ref;
  final AudioDeviceDao _dao;
  final Duration _settle;
  final Duration _saveDelay;
  final DateTime Function() _now;

  late final ProviderSubscription<AudioEndpoint?> _endpointSub;
  late final ProviderSubscription<EqState> _eqSub;
  late final ProviderSubscription<AutoEqState> _autoEqSub;
  late final ProviderSubscription<EqEngine> _engineSub;

  bool _disposed = false;
  bool get mounted => !_disposed;

  DeviceEqState get state => _ref.read(deviceEqStateProvider);
  set state(DeviceEqState value) =>
      _ref.read(deviceEqStateProvider.notifier).state = value;

  AudioEndpoint? _pendingEndpoint;
  Timer? _endpointTimer;
  Timer? _saveTimer;

  /// True while a profile is being put in place, so its own changes to the
  /// equalizer are not mistaken for edits and saved back.
  bool _applying = false;

  /// The live chain as it stood once the active profile was in place, or last
  /// saved. Edits are what differs from it.
  EqChain? _baseline;

  /// Every change to the database or the equalizer runs here, one at a time,
  /// so a device switch cannot interleave with a save to the previous device.
  Future<void> _tail = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>(
      (_) {},
      onError: (Object e, StackTrace st) {
        AppLogger.w('DeviceEq', 'Device EQ update failed: $e', stackTrace: st);
      },
    );
    return result;
  }

  /// [_serialized] for work nobody awaits; [_tail] has already logged a
  /// failure.
  void _inBackground(Future<void> Function() action) {
    unawaited(_serialized(action).catchError((Object _) {}));
  }

  // ── Following the output ─────────────────────────────────────────────────

  /// A listener, so it only schedules: the work reads and changes providers.
  ///
  /// The settle also rides out a route that flaps while a Bluetooth device
  /// connects, and lets the saved Audio Output choice load before the default
  /// device is taken for the one in use.
  void _onEndpoint(AudioEndpoint? endpoint) {
    if (endpoint == null) return;
    _pendingEndpoint = endpoint;
    _endpointTimer?.cancel();
    _endpointTimer = Timer(_settle, () {
      final next = _pendingEndpoint;
      if (next != null) _inBackground(() => _switchTo(next));
    });
  }

  Future<void> _switchTo(AudioEndpoint endpoint) async {
    if (!mounted) return;
    // Nothing may be snapshotted or overwritten before the saved EQ is in.
    await _equalizerReady();
    await _saveNow();

    final previous = state.device;
    final seen = await _dao.recordSeen(endpoint, _now());
    if (!mounted) return;

    // The same device again — a rename in the system settings, say.
    if (previous?.deviceId == endpoint.id) {
      state = state.copyWith(device: seen.record);
      return;
    }

    var record = seen.record;
    if (seen.isNew) {
      // The first device inherits the EQ already set up, so updating flax
      // loses nobody's tuning. Every later one starts with nothing applied.
      final chain = seen.firstEver
          ? _liveChain()
          : EqChain.flat(_ref.read(eqEngineProvider));
      await _dao.insertProfile(
        endpoint.id,
        chain.presetName ?? 'Flat',
        chain,
        makeDefault: true,
        now: _now(),
      );
      record = (await _dao.device(endpoint.id)) ?? record;
    }
    final profiles = await _dao.profilesFor(endpoint.id);
    final deviceCount = await _dao.deviceCount();
    if (!mounted) return;

    final toApply = record.autoSwitch
        ? profiles.firstWhereOrNull((p) => p.isDeviceDefault) ??
              profiles.firstOrNull
        : null;
    AppLogger.i(
      'DeviceEq',
      'Output is now ${endpoint.name} (${endpoint.type.stored})'
          '${toApply == null ? '' : ', applying "${toApply.profileName}"'}',
    );
    state = DeviceEqState(
      device: record,
      profiles: profiles,
      activeProfileId: toApply?.id,
      deviceCount: deviceCount,
    );
    if (toApply != null) await _apply(toApply.chain);
    _baseline = _liveChain();
  }

  Future<void> _equalizerReady() async {
    try {
      await Future.wait([
        _ref.read(eqProvider.notifier).ready,
        _ref.read(eqEngineProvider.notifier).ready,
        _ref.read(autoEqProvider.notifier).ready,
      ]);
    } catch (_) {
      // Each falls back to its defaults on a failed load.
    }
  }

  // ── Applying and saving ──────────────────────────────────────────────────

  EqChain _liveChain() {
    final eq = _ref.read(eqProvider);
    return EqChain(
      engine: _ref.read(eqEngineProvider),
      presetName: eq.presetName,
      bandGains: [for (final band in eq.bands) band.gain],
      autoEqProfile: _ref.read(autoEqProvider).activeProfile,
      preampGain: eq.preamp,
      eqEnabled: eq.enabled,
    );
  }

  /// Puts [chain] in place. No crossfade: mpv rebuilds its filter chain for any
  /// change to an equalizer, so there are no coefficients to glide between, and
  /// a change of output reopens the audio device anyway.
  Future<void> _apply(EqChain chain) async {
    _applying = true;
    try {
      _ref
          .read(eqProvider.notifier)
          .loadChain(
            enabled: chain.eqEnabled,
            gains: chain.bandGains,
            preamp: chain.preampGain,
            presetName: chain.presetName ?? 'Custom',
          );
      await _ref.read(eqEngineProvider.notifier).setEngine(chain.engine);
      final autoEq = _ref.read(autoEqProvider.notifier);
      final liveKey = _liveChain().autoEqKey;
      if (liveKey != chain.autoEqKey) {
        await autoEq.restoreProfile(chain.autoEqProfile);
      }
    } finally {
      _applying = false;
    }
  }

  void _scheduleSave() {
    if (_applying || state.activeProfileId == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => _inBackground(_saveNow));
  }

  /// Writes the edits made since [_baseline] to the active profile.
  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final baseline = _baseline;
    final profile = state.activeProfile;
    if (baseline == null || profile == null) return;
    final live = _liveChain();
    if (live == baseline) return;
    final merged = live.changesOnto(profile.chain, before: baseline);
    _baseline = live;
    if (merged == profile.chain) return;
    await _dao.updateProfileChain(profile.id, merged);
    if (!mounted) return;
    state = state.copyWith(
      profiles: [
        for (final p in state.profiles)
          p.id == profile.id ? p.copyWith(chain: merged) : p,
      ],
    );
  }

  Future<void> _reloadProfiles() async {
    final device = state.device;
    if (device == null) return;
    final record = await _dao.device(device.deviceId);
    final profiles = await _dao.profilesFor(device.deviceId);
    if (!mounted || record == null) return;
    state = state.copyWith(device: record, profiles: profiles);
  }

  // ── Actions on the current device ────────────────────────────────────────

  /// Switches the equalizer to one of the current device's profiles.
  Future<void> selectProfile(String id) => _serialized(() async {
    await _saveNow();
    final profile = state.profiles.firstWhereOrNull((p) => p.id == id);
    if (profile == null) return;
    state = state.copyWith(activeProfileId: id);
    await _apply(profile.chain);
    _baseline = _liveChain();
  });

  /// Saves the equalizer as it is now as a new profile of the current device,
  /// and makes it the active one.
  Future<void> saveAsNewProfile(String name) => _serialized(() async {
    final device = state.device;
    final trimmed = name.trim();
    if (device == null || trimmed.isEmpty) return;
    await _saveNow();
    final live = _liveChain();
    final created = await _dao.insertProfile(
      device.deviceId,
      trimmed,
      live,
      makeDefault: state.profiles.isEmpty,
      now: _now(),
    );
    await _reloadProfiles();
    if (!mounted) return;
    state = state.copyWith(activeProfileId: created.id);
    _baseline = live;
  });

  Future<void> setAutoSwitch(bool enabled) => _serialized(() async {
    final device = state.device;
    if (device == null) return;
    await _dao.setAutoSwitch(device.deviceId, enabled);
    await _reloadProfiles();
  });

  // ── Actions on any device ────────────────────────────────────────────────

  Future<void> renameProfile(String id, String name) => _serialized(() async {
    if (name.trim().isEmpty) return;
    await _dao.renameProfile(id, name);
    await _reloadProfiles();
  });

  Future<void> setDefaultProfile(String deviceId, String profileId) =>
      _serialized(() async {
        await _dao.setDefaultProfile(deviceId, profileId);
        await _reloadProfiles();
      });

  /// Deletes a profile. A device's last profile is kept, so it always has a
  /// default to switch to. Deleting the active one switches to the default.
  Future<void> deleteProfile(String id) => _serialized(() async {
    final doomed = await _dao.profile(id);
    if (doomed == null) return;
    if ((await _dao.profilesFor(doomed.deviceId)).length <= 1) return;
    final wasActive = state.activeProfileId == id;
    if (wasActive) _saveTimer?.cancel();
    await _dao.deleteProfile(id);
    await _reloadProfiles();
    if (!mounted || !wasActive) return;
    final fallback =
        state.profiles.firstWhereOrNull((p) => p.isDeviceDefault) ??
        state.profiles.firstOrNull;
    state = fallback == null
        ? state.copyWith(clearActive: true)
        : state.copyWith(activeProfileId: fallback.id);
    if (fallback != null) await _apply(fallback.chain);
    _baseline = _liveChain();
  });

  Future<void> setDeviceAutoSwitch(String deviceId, bool enabled) =>
      _serialized(() async {
        await _dao.setAutoSwitch(deviceId, enabled);
        await _reloadProfiles();
      });

  Future<void> renameDevice(String deviceId, String? name) =>
      _serialized(() async {
        await _dao.renameDevice(deviceId, name);
        await _reloadProfiles();
      });

  /// Forgets a device and its profiles. The device in use cannot be deleted:
  /// it would be recorded again at once, without its profiles.
  Future<void> deleteDevice(String deviceId) => _serialized(() async {
    if (state.device?.deviceId == deviceId) return;
    await _dao.deleteDevice(deviceId);
    final count = await _dao.deviceCount();
    if (mounted) state = state.copyWith(deviceCount: count);
  });

  void dispose() {
    _disposed = true;
    _endpointTimer?.cancel();
    _saveTimer?.cancel();
    _endpointSub.close();
    _eqSub.close();
    _autoEqSub.close();
    _engineSub.close();
  }
}
