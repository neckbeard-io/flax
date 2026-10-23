import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/shared/audio/eq_filter.dart';

/// Reads and writes the seen-devices table and the profiles saved for each.
/// Issue #69.
class AudioDeviceDao {
  AudioDeviceDao(this._db);

  final FlaxDatabase _db;

  static const _uuid = Uuid();

  // ── Devices ──────────────────────────────────────────────────────────────

  /// Records that [endpoint] is the output now, adding it if it is new.
  ///
  /// [isNew] is true the first time a device is seen; [firstEver] when it is
  /// also the first device of all, which is when the EQ already set up becomes
  /// that device's rather than being replaced.
  Future<({AudioDeviceRecord record, bool isNew, bool firstEver})> recordSeen(
    AudioEndpoint endpoint,
    DateTime now,
  ) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.audioDevices,
      )..where((t) => t.deviceId.equals(endpoint.id))).getSingleOrNull();

      if (existing != null) {
        await (_db.update(
          _db.audioDevices,
        )..where((t) => t.deviceId.equals(endpoint.id))).write(
          AudioDevicesCompanion(
            deviceName: Value(endpoint.name),
            // A guess from a device name never overrides what a platform said.
            deviceType: endpoint.type == AudioDeviceType.other
                ? const Value.absent()
                : Value(endpoint.type.stored),
            lastSeenAt: Value(now),
          ),
        );
        return (
          record: (await device(endpoint.id))!,
          isNew: false,
          firstEver: false,
        );
      }

      final count = await _db.audioDevices.count().getSingle();
      await _db
          .into(_db.audioDevices)
          .insert(
            AudioDevicesCompanion.insert(
              deviceId: endpoint.id,
              deviceName: endpoint.name,
              deviceType: endpoint.type.stored,
              firstSeenAt: now,
              lastSeenAt: now,
            ),
          );
      return (
        record: (await device(endpoint.id))!,
        isNew: true,
        firstEver: count == 0,
      );
    });
  }

  Future<AudioDeviceRecord?> device(String deviceId) async {
    final row = await (_db.select(
      _db.audioDevices,
    )..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    return row == null ? null : _deviceFromRow(row);
  }

  Future<int> deviceCount() => _db.audioDevices.count().getSingle();

  /// Every device, most recently used first.
  Stream<List<AudioDeviceRecord>> watchDevices() {
    final q = _db.select(_db.audioDevices)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)]);
    return q.watch().map((rows) => rows.map(_deviceFromRow).toList());
  }

  Future<void> renameDevice(String deviceId, String? customName) {
    final trimmed = customName?.trim();
    return (_db.update(
      _db.audioDevices,
    )..where((t) => t.deviceId.equals(deviceId))).write(
      AudioDevicesCompanion(
        customName: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  Future<void> setAutoSwitch(String deviceId, bool enabled) {
    return (_db.update(_db.audioDevices)
          ..where((t) => t.deviceId.equals(deviceId)))
        .write(AudioDevicesCompanion(autoSwitch: Value(enabled)));
  }

  Future<void> setDefaultProfile(String deviceId, String profileId) {
    return (_db.update(_db.audioDevices)
          ..where((t) => t.deviceId.equals(deviceId)))
        .write(AudioDevicesCompanion(defaultProfileId: Value(profileId)));
  }

  /// Forgets a device and, through the cascade, every profile saved for it.
  Future<void> deleteDevice(String deviceId) {
    return (_db.delete(
      _db.audioDevices,
    )..where((t) => t.deviceId.equals(deviceId))).go();
  }

  // ── Profiles ─────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> _profilesQuery() {
    return _db.select(_db.deviceEqProfiles).join([
      innerJoin(
        _db.audioDevices,
        _db.audioDevices.deviceId.equalsExp(_db.deviceEqProfiles.deviceId),
      ),
    ])..orderBy([
      OrderingTerm.asc(_db.deviceEqProfiles.createdAt),
      OrderingTerm.asc(_db.deviceEqProfiles.profileName),
    ]);
  }

  DeviceEqProfile _profileFromJoin(TypedResult row) {
    final profile = row.readTable(_db.deviceEqProfiles);
    final device = row.readTable(_db.audioDevices);
    return _profileFromRow(
      profile,
      isDefault: device.defaultProfileId == profile.id,
    );
  }

  /// A device's profiles in the order they were made.
  Future<List<DeviceEqProfile>> profilesFor(String deviceId) async {
    final q = _profilesQuery()
      ..where(_db.deviceEqProfiles.deviceId.equals(deviceId));
    return (await q.get()).map(_profileFromJoin).toList();
  }

  /// Every profile of every device, for the device list.
  Stream<List<DeviceEqProfile>> watchAllProfiles() {
    return _profilesQuery().watch().map(
      (rows) => rows.map(_profileFromJoin).toList(),
    );
  }

  Future<DeviceEqProfile?> profile(String id) async {
    final q = _profilesQuery()..where(_db.deviceEqProfiles.id.equals(id));
    final row = await q.getSingleOrNull();
    return row == null ? null : _profileFromJoin(row);
  }

  /// Saves [chain] as a new profile of [deviceId].
  Future<DeviceEqProfile> insertProfile(
    String deviceId,
    String name,
    EqChain chain, {
    bool makeDefault = false,
    DateTime? now,
  }) {
    return _db.transaction(() async {
      final id = _uuid.v4();
      await _db
          .into(_db.deviceEqProfiles)
          .insert(
            DeviceEqProfilesCompanion.insert(
              id: id,
              deviceId: deviceId,
              profileName: name,
              engine: chain.engine.name,
              presetName: Value(chain.presetName),
              bandGainsJson: jsonEncode(chain.bandGains),
              autoEqProfileJson: Value(
                chain.autoEqProfile == null
                    ? null
                    : jsonEncode(chain.autoEqProfile!.toJson()),
              ),
              preampGain: Value(chain.preampGain),
              eqEnabled: Value(chain.eqEnabled),
              createdAt: now ?? DateTime.now(),
            ),
          );
      if (makeDefault) await setDefaultProfile(deviceId, id);
      return (await profile(id))!;
    });
  }

  Future<void> updateProfileChain(String id, EqChain chain) {
    return (_db.update(
      _db.deviceEqProfiles,
    )..where((t) => t.id.equals(id))).write(
      DeviceEqProfilesCompanion(
        engine: Value(chain.engine.name),
        presetName: Value(chain.presetName),
        bandGainsJson: Value(jsonEncode(chain.bandGains)),
        autoEqProfileJson: Value(
          chain.autoEqProfile == null
              ? null
              : jsonEncode(chain.autoEqProfile!.toJson()),
        ),
        preampGain: Value(chain.preampGain),
        eqEnabled: Value(chain.eqEnabled),
      ),
    );
  }

  Future<void> renameProfile(String id, String name) {
    return (_db.update(_db.deviceEqProfiles)..where((t) => t.id.equals(id)))
        .write(DeviceEqProfilesCompanion(profileName: Value(name.trim())));
  }

  /// Deletes a profile. If it was its device's default, the oldest remaining
  /// profile takes over, so a device with profiles always has a default.
  Future<void> deleteProfile(String id) {
    return _db.transaction(() async {
      final doomed = await profile(id);
      if (doomed == null) return;
      await (_db.delete(
        _db.deviceEqProfiles,
      )..where((t) => t.id.equals(id))).go();
      if (!doomed.isDeviceDefault) return;
      final remaining = await profilesFor(doomed.deviceId);
      await (_db.update(
        _db.audioDevices,
      )..where((t) => t.deviceId.equals(doomed.deviceId))).write(
        AudioDevicesCompanion(
          defaultProfileId: Value(
            remaining.isEmpty ? null : remaining.first.id,
          ),
        ),
      );
    });
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  AudioDeviceRecord _deviceFromRow(AudioDeviceRow row) => AudioDeviceRecord(
    deviceId: row.deviceId,
    deviceName: row.deviceName,
    customName: row.customName,
    type: AudioDeviceType.fromStored(row.deviceType),
    firstSeenAt: row.firstSeenAt,
    lastSeenAt: row.lastSeenAt,
    defaultProfileId: row.defaultProfileId,
    autoSwitch: row.autoSwitch,
  );

  DeviceEqProfile _profileFromRow(
    DeviceEqProfileRow row, {
    required bool isDefault,
  }) {
    final gains = <double>[
      for (final g in (jsonDecode(row.bandGainsJson) as List<dynamic>))
        (g as num).toDouble(),
    ];
    AutoEqProfile? autoEq;
    final autoEqJson = row.autoEqProfileJson;
    if (autoEqJson != null) {
      try {
        autoEq = AutoEqProfile.fromJson(
          jsonDecode(autoEqJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // An unreadable reference is the same as none.
      }
    }
    return DeviceEqProfile(
      id: row.id,
      deviceId: row.deviceId,
      profileName: row.profileName,
      isDeviceDefault: isDefault,
      chain: EqChain(
        engine: EqEngine.values.firstWhere(
          (e) => e.name == row.engine,
          orElse: () => EqEngine.defaultEngine,
        ),
        presetName: row.presetName,
        // Padded or cut to the band count, so an older layout cannot index
        // past the end of the curve.
        bandGains: [
          for (var i = 0; i < eqBandCount; i++)
            i < gains.length ? gains[i] : 0.0,
        ],
        autoEqProfile: autoEq,
        preampGain: row.preampGain,
        eqEnabled: row.eqEnabled,
      ),
    );
  }
}
