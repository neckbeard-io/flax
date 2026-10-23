import 'package:collection/collection.dart';

import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/shared/audio/eq_filter.dart';

/// What kind of output a device is. Issue #69.
///
/// Only used to pick an icon and to tell devices apart in a list; nothing about
/// the EQ depends on it.
enum AudioDeviceType {
  bluetooth('bluetooth'),
  usbDac('usb_dac'),
  headphoneJack('headphone_jack'),
  builtinSpeaker('builtin_speaker'),
  hdmiOptical('hdmi_optical'),
  other('other');

  const AudioDeviceType(this.stored);

  /// The value written to the `device_type` column.
  final String stored;

  static AudioDeviceType fromStored(String? value) =>
      values.firstWhereOrNull((t) => t.stored == value) ?? other;
}

/// The output audio is going to right now, as the platform reports it.
class AudioEndpoint {
  const AudioEndpoint({
    required this.id,
    required this.name,
    this.type = AudioDeviceType.other,
  });

  /// Where the platform cannot say which device the system default is
  /// (Windows, or a Linux without `pactl`), the default itself stands in for
  /// it. Choosing a device under Audio Output gives it its own entry.
  static const systemDefaultId = 'auto';

  static const systemDefault = AudioEndpoint(
    id: systemDefaultId,
    name: 'System Default',
  );

  final String id;
  final String name;
  final AudioDeviceType type;

  bool get isSystemDefault => id == systemDefaultId;

  /// Reads the map the native audio route channels send.
  static AudioEndpoint? fromPlatform(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    if (id is! String || id.isEmpty) return null;
    final name = value['name'];
    return AudioEndpoint(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      type: AudioDeviceType.fromStored(value['type'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioEndpoint &&
      other.id == id &&
      other.name == name &&
      other.type == type;

  @override
  int get hashCode => Object.hash(id, name, type);

  @override
  String toString() => 'AudioEndpoint($id, $name, ${type.stored})';
}

/// Guesses a device's type from an mpv device name and description, for the
/// outputs no native code describes: a device chosen under Audio Output, and
/// every device on Linux.
AudioDeviceType classifyDevice(String name, String description) {
  final text = '$name $description'.toLowerCase();
  bool has(List<String> words) => words.any(text.contains);
  if (has(['bluetooth', 'bluez', 'airpods', 'a2dp'])) {
    return AudioDeviceType.bluetooth;
  }
  if (has(['usb'])) return AudioDeviceType.usbDac;
  if (has(['hdmi', 'displayport', 'spdif', 's/pdif', 'optical', 'iec958'])) {
    return AudioDeviceType.hdmiOptical;
  }
  if (has(['headphone', 'headset'])) return AudioDeviceType.headphoneJack;
  if (has(['speaker', 'built-in', 'builtin', 'internal'])) {
    return AudioDeviceType.builtinSpeaker;
  }
  return AudioDeviceType.other;
}

/// A device flax has played through, as stored.
class AudioDeviceRecord {
  const AudioDeviceRecord({
    required this.deviceId,
    required this.deviceName,
    this.customName,
    required this.type,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.defaultProfileId,
    this.autoSwitch = true,
  });

  final String deviceId;
  final String deviceName;
  final String? customName;
  final AudioDeviceType type;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? defaultProfileId;
  final bool autoSwitch;

  /// The user's name for it if they gave one, the platform's otherwise.
  String get displayName {
    final custom = customName?.trim();
    return custom == null || custom.isEmpty ? deviceName : custom;
  }

  bool get isSystemDefault => deviceId == AudioEndpoint.systemDefaultId;
}

/// Everything the equalizer applies: the manual curve, the AutoEQ correction
/// on top of it, the preamp and the filter they run through.
class EqChain {
  const EqChain({
    required this.engine,
    this.presetName,
    required this.bandGains,
    this.autoEqProfile,
    this.preampGain = 0,
    this.eqEnabled = false,
  });

  /// What a newly seen device starts with: nothing applied.
  factory EqChain.flat(EqEngine engine) => EqChain(
    engine: engine,
    presetName: 'Flat',
    bandGains: List<double>.filled(eqBandCount, 0),
  );

  final EqEngine engine;
  final String? presetName;

  /// Exactly [eqBandCount] gains in dB, in band order.
  final List<double> bandGains;

  /// Which AutoEQ correction, without its curve: the curve is loaded from the
  /// AutoEQ database when the profile is applied.
  final AutoEqProfile? autoEqProfile;
  final double preampGain;
  final bool eqEnabled;

  /// Identifies [autoEqProfile] for comparison; the class has no equality.
  String? get autoEqKey => autoEqProfile == null
      ? null
      : '${autoEqProfile!.id}|${autoEqProfile!.source}';

  EqChain copyWith({
    EqEngine? engine,
    String? presetName,
    List<double>? bandGains,
    AutoEqProfile? autoEqProfile,
    bool clearAutoEq = false,
    double? preampGain,
    bool? eqEnabled,
  }) => EqChain(
    engine: engine ?? this.engine,
    presetName: presetName ?? this.presetName,
    bandGains: bandGains ?? this.bandGains,
    autoEqProfile: clearAutoEq ? null : (autoEqProfile ?? this.autoEqProfile),
    preampGain: preampGain ?? this.preampGain,
    eqEnabled: eqEnabled ?? this.eqEnabled,
  );

  /// Applies to [base] only the fields that differ between [before] and this.
  ///
  /// How edits reach a profile. A field the user did not touch keeps the
  /// profile's value even where the live chain could not reproduce it — an
  /// AutoEQ correction whose curve is missing because the database has not been
  /// downloaded on this machine, say — so that gap is never written back over
  /// the profile.
  EqChain changesOnto(EqChain base, {required EqChain before}) => EqChain(
    engine: engine != before.engine ? engine : base.engine,
    presetName: presetName != before.presetName ? presetName : base.presetName,
    bandGains: const ListEquality<double>().equals(bandGains, before.bandGains)
        ? base.bandGains
        : bandGains,
    autoEqProfile: autoEqKey != before.autoEqKey
        ? autoEqProfile
        : base.autoEqProfile,
    preampGain: preampGain != before.preampGain ? preampGain : base.preampGain,
    eqEnabled: eqEnabled != before.eqEnabled ? eqEnabled : base.eqEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is EqChain &&
      other.engine == engine &&
      other.presetName == presetName &&
      const ListEquality<double>().equals(other.bandGains, bandGains) &&
      other.autoEqKey == autoEqKey &&
      other.preampGain == preampGain &&
      other.eqEnabled == eqEnabled;

  @override
  int get hashCode => Object.hash(
    engine,
    presetName,
    Object.hashAll(bandGains),
    autoEqKey,
    preampGain,
    eqEnabled,
  );
}

/// A named EQ setup saved for one device. A device can have several, and one
/// of them is its default.
class DeviceEqProfile {
  const DeviceEqProfile({
    required this.id,
    required this.deviceId,
    required this.profileName,
    required this.chain,
    this.isDeviceDefault = false,
  });

  final String id;
  final String deviceId;
  final String profileName;
  final EqChain chain;

  /// Read from the device's `default_profile_id`, not stored on the profile.
  final bool isDeviceDefault;

  DeviceEqProfile copyWith({
    String? profileName,
    EqChain? chain,
    bool? isDeviceDefault,
  }) => DeviceEqProfile(
    id: id,
    deviceId: deviceId,
    profileName: profileName ?? this.profileName,
    chain: chain ?? this.chain,
    isDeviceDefault: isDeviceDefault ?? this.isDeviceDefault,
  );
}
