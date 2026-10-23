/// Audio outputs flax has played through, and the EQ profiles saved for each.
/// Issue #69.
///
/// Unlike the entity tables these are not per server: a pair of headphones
/// sounds the same whichever library is playing through it.
library;

import 'package:drift/drift.dart';

@DataClassName('AudioDeviceRow')
class AudioDevices extends Table {
  /// Stable platform identifier: mpv's device name (`coreaudio/<UID>`,
  /// `wasapi/{…}`, `pulse/<sink>`) on desktop, type plus address on Android.
  TextColumn get deviceId => text()();

  /// The name the platform last reported. Updated on every sighting, so a
  /// device renamed in the system settings follows along.
  TextColumn get deviceName => text()();

  /// The name the user gave it in flax, which wins over [deviceName].
  TextColumn get customName => text().nullable()();

  /// One of `AudioDeviceType`'s stored names: `bluetooth`, `usb_dac`, …
  TextColumn get deviceType => text()();

  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  /// The profile restored when this device becomes the output. Kept here
  /// rather than as a flag on each profile, so a device cannot end up with two
  /// defaults.
  TextColumn get defaultProfileId => text().nullable()();

  /// Whether connecting this device restores its default profile.
  BoolColumn get autoSwitch => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {deviceId};
}

@DataClassName('DeviceEqProfileRow')
@TableIndex(name: 'device_eq_profile_device', columns: {#deviceId})
class DeviceEqProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId =>
      text().references(AudioDevices, #deviceId, onDelete: KeyAction.cascade)();
  TextColumn get profileName => text()();

  /// `EqEngine.name`.
  TextColumn get engine => text()();
  TextColumn get presetName => text().nullable()();

  /// JSON array of the 18 band gains in dB.
  TextColumn get bandGainsJson => text()();

  /// `AutoEqProfile.toJson()` — enough to find its curve again.
  TextColumn get autoEqProfileJson => text().nullable()();
  RealColumn get preampGain => real().withDefault(const Constant(0))();
  BoolColumn get eqEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
