import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/features/settings/device_eq_provider.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/services/audio_devices/audio_device_dao.dart';
import 'package:flax/services/audio_devices/system_output.dart';
import 'package:flax/services/autoeq/autoeq_database.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/shared/audio/eq_filter.dart';

/// EQ profiles per audio device (#69): recording devices, restoring each one's
/// default when it becomes the output, and saving edits back to the profile in
/// use.
void main() {
  const speakers = AudioEndpoint(
    id: 'coreaudio/BuiltInSpeakerDevice',
    name: 'MacBook Pro Speakers',
    type: AudioDeviceType.builtinSpeaker,
  );
  const cans = AudioEndpoint(
    id: 'coreaudio/AA-BB-CC',
    name: 'WH-1000XM4',
    type: AudioDeviceType.bluetooth,
  );

  late Directory autoEqDir;
  late FlaxDatabase db;
  late ProviderContainer container;
  late StateProvider<AudioEndpoint?> output;

  /// A tuned EQ already saved, as an existing install has before #69.
  Map<String, Object> savedEq({String preset = 'Rock', double band0 = 4}) => {
    'flax_eq_settings': jsonEncode({
      'enabled': true,
      'preamp': -3.0,
      'presetName': preset,
      'bands': [
        for (var i = 0; i < eqBandCount; i++)
          {
            'frequency': eqBandFrequencies[i],
            'gain': i == 0 ? band0 : 0.0,
            'label': '$i',
          },
      ],
    }),
  };

  void writeAutoEqCurve(int id) {
    Directory(p.join(autoEqDir.path, 'data')).createSync(recursive: true);
    File(
      p.join(autoEqDir.path, 'data', '$id.txt'),
    ).writeAsStringSync('GraphicEQ: 20 -1.0; 1000 2.0; 20000 -4.0');
  }

  ProviderContainer build() {
    output = StateProvider<AudioEndpoint?>((_) => null);
    final c = ProviderContainer(
      overrides: [
        flaxDatabaseProvider.overrideWithValue(db),
        autoEqDatabaseProvider.overrideWithValue(
          AutoEqDatabase(cacheDirOverride: autoEqDir),
        ),
        activeAudioEndpointProvider.overrideWith((ref) => ref.watch(output)),
        deviceEqControllerProvider.overrideWith((ref) {
          final controller = DeviceEqController(
            ref,
            ref.watch(audioDeviceDaoProvider),
            settle: Duration.zero,
            saveDelay: Duration.zero,
          );
          ref.onDispose(controller.dispose);
          return controller;
        }),
      ],
    );
    // Created the way the player creates it.
    c.read(deviceEqControllerProvider);
    return c;
  }

  setUp(() {
    autoEqDir = Directory.systemTemp.createTempSync('flax_device_eq_');
    db = FlaxDatabase.memory();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    autoEqDir.deleteSync(recursive: true);
  });

  DeviceEqState deviceEq() => container.read(deviceEqStateProvider);
  EqState eq() => container.read(eqProvider);

  /// Lets timers and database work run until [done] holds.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'timed out waiting');
    // And whatever was queued behind it.
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  Future<void> connect(AudioEndpoint endpoint) async {
    container.read(output.notifier).state = endpoint;
    await until(() => deviceEq().device?.deviceId == endpoint.id);
  }

  test('the first device keeps the EQ already set up', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();

    await connect(speakers);

    final profiles = deviceEq().profiles;
    expect(profiles, hasLength(1));
    expect(profiles.single.profileName, 'Rock');
    expect(profiles.single.isDeviceDefault, isTrue);
    expect(profiles.single.chain.bandGains.first, 4);
    expect(profiles.single.chain.preampGain, -3);
    expect(deviceEq().activeProfileId, profiles.single.id);
    expect(eq().presetName, 'Rock');
    expect(eq().enabled, isTrue);
  });

  test('a new device starts flat, and each device gets its own back', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();

    await connect(speakers);
    await connect(cans);

    expect(deviceEq().profiles.single.profileName, 'Flat');
    expect(eq().enabled, isFalse);
    expect(eq().bands.every((b) => b.gain == 0), isTrue);

    await connect(speakers);
    expect(eq().presetName, 'Rock');
    expect(eq().bands.first.gain, 4);
  });

  test('edits are saved to the profile in use', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();
    await connect(speakers);
    await connect(cans);

    final eqNotifier = container.read(eqProvider.notifier);
    eqNotifier.toggle();
    eqNotifier.setBandGain(3, 6);
    await until(() => deviceEq().activeProfile!.chain.bandGains[3] == 6);

    await connect(speakers);
    expect(eq().bands[3].gain, 0, reason: 'the speakers were not edited');

    await connect(cans);
    expect(eq().bands[3].gain, 6);
    expect(eq().enabled, isTrue);
    expect(eq().presetName, 'Custom');
  });

  test('several profiles per device, switched and defaulted', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();
    await connect(speakers);
    await connect(cans);

    final notifier = container.read(deviceEqControllerProvider);
    container.read(eqProvider.notifier).applyPreset('Pop');
    await until(() => deviceEq().activeProfile!.chain.presetName == 'Pop');
    final flatId = deviceEq().activeProfileId!;

    await notifier.saveAsNewProfile('Bass');
    final bassId = deviceEq().activeProfileId!;
    expect(bassId, isNot(flatId));
    container.read(eqProvider.notifier).setBandGain(0, 9);
    await until(() => deviceEq().activeProfile!.chain.bandGains[0] == 9);

    await notifier.selectProfile(flatId);
    expect(eq().presetName, 'Pop');
    expect(eq().bands[0].gain, isNot(9));

    // The original stays the default until another is chosen.
    await connect(speakers);
    await connect(cans);
    expect(deviceEq().activeProfileId, flatId);

    await notifier.setDefaultProfile(cans.id, bassId);
    await connect(speakers);
    await connect(cans);
    expect(deviceEq().activeProfileId, bassId);
    expect(eq().bands[0].gain, 9);
  });

  test('with auto-switch off, connecting leaves the EQ alone', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();
    await connect(speakers);
    await connect(cans);
    await container.read(deviceEqControllerProvider).setAutoSwitch(false);

    await connect(speakers);
    await connect(cans);

    expect(deviceEq().activeProfileId, isNull);
    expect(eq().presetName, 'Rock', reason: "the speakers' EQ stays");
  });

  test('AutoEQ follows the device', () async {
    writeAutoEqCurve(7);
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();
    await connect(speakers);
    await connect(cans);

    await container
        .read(autoEqProvider.notifier)
        .restoreProfile(AutoEqProfile(id: 7, name: 'Cans', source: 'x'));
    await until(() => deviceEq().activeProfile!.chain.autoEqProfile?.id == 7);

    await connect(speakers);
    expect(container.read(autoEqProvider).activeProfile, isNull);

    await connect(cans);
    expect(container.read(autoEqProvider).activeProfile?.id, 7);
    expect(container.read(autoEqProvider).activeProfile!.points, isNotEmpty);
  });

  test(
    'a correction missing on this machine is not erased by an edit',
    () async {
      SharedPreferences.setMockInitialValues(savedEq());
      final dao = AudioDeviceDao(db);
      final now = DateTime(2026);
      await dao.recordSeen(cans, now);
      // Saved elsewhere with a curve this machine never downloaded.
      await dao.insertProfile(
        cans.id,
        'Harman',
        EqChain.flat(EqEngine.parametric).copyWith(
          autoEqProfile: AutoEqProfile(id: 99, name: 'Gone', source: 'x'),
        ),
        makeDefault: true,
      );
      // Not the first device, so it does not inherit the live EQ.
      await dao.recordSeen(speakers, now);

      container = build();
      await connect(cans);
      expect(container.read(autoEqProvider).activeProfile, isNull);

      container.read(eqProvider.notifier).setPreamp(-6);
      await until(() => deviceEq().activeProfile!.chain.preampGain == -6);

      final saved = await dao.profilesFor(cans.id);
      expect(saved.single.chain.autoEqProfile?.id, 99);
    },
  );

  test('deleting the active profile falls back to the default', () async {
    SharedPreferences.setMockInitialValues(savedEq());
    container = build();
    await connect(speakers);
    final notifier = container.read(deviceEqControllerProvider);
    final rockId = deviceEq().activeProfileId!;

    // The last profile is kept.
    await notifier.deleteProfile(rockId);
    expect(deviceEq().profiles, hasLength(1));

    // Edits are saved as they are made, so a new profile starts as a copy and
    // is tuned afterwards.
    await notifier.saveAsNewProfile('Pop');
    final popId = deviceEq().activeProfileId!;
    container.read(eqProvider.notifier).applyPreset('Pop');
    await until(() => deviceEq().activeProfile!.chain.presetName == 'Pop');
    await notifier.deleteProfile(popId);

    expect(deviceEq().profiles.map((p) => p.id), [rockId]);
    expect(deviceEq().activeProfileId, rockId);
    expect(eq().presetName, 'Rock');
  });

  group('AudioDeviceDao', () {
    late AudioDeviceDao dao;

    setUp(() {
      container = ProviderContainer();
      dao = AudioDeviceDao(db);
    });

    test('records sightings and keeps a platform type over a guess', () async {
      final first = await dao.recordSeen(cans, DateTime(2026, 1, 1));
      expect(first.isNew, isTrue);
      expect(first.firstEver, isTrue);

      final again = await dao.recordSeen(
        const AudioEndpoint(id: 'coreaudio/AA-BB-CC', name: 'Renamed'),
        DateTime(2026, 2, 1),
      );
      expect(again.isNew, isFalse);
      expect(again.record.deviceName, 'Renamed');
      expect(again.record.type, AudioDeviceType.bluetooth);
      expect(again.record.firstSeenAt, DateTime(2026, 1, 1));
      expect(again.record.lastSeenAt, DateTime(2026, 2, 1));

      final other = await dao.recordSeen(speakers, DateTime(2026, 3, 1));
      expect(other.firstEver, isFalse);
    });

    test('a custom name wins and can be cleared', () async {
      await dao.recordSeen(cans, DateTime(2026));
      await dao.renameDevice(cans.id, '  Office cans ');
      expect((await dao.device(cans.id))!.displayName, 'Office cans');
      await dao.renameDevice(cans.id, '');
      expect((await dao.device(cans.id))!.displayName, 'WH-1000XM4');
    });

    test('deleting the default hands it to the oldest remaining', () async {
      await dao.recordSeen(cans, DateTime(2026));
      final chain = EqChain.flat(EqEngine.parametric);
      final a = await dao.insertProfile(
        cans.id,
        'A',
        chain,
        makeDefault: true,
        now: DateTime(2026, 1, 1),
      );
      final b = await dao.insertProfile(
        cans.id,
        'B',
        chain,
        now: DateTime(2026, 1, 2),
      );
      await dao.insertProfile(cans.id, 'C', chain, now: DateTime(2026, 1, 3));

      await dao.deleteProfile(a.id);

      expect((await dao.device(cans.id))!.defaultProfileId, b.id);
    });

    test("deleting a device deletes its profiles", () async {
      await dao.recordSeen(cans, DateTime(2026));
      await dao.insertProfile(cans.id, 'A', EqChain.flat(EqEngine.parametric));

      await dao.deleteDevice(cans.id);

      expect(await dao.profilesFor(cans.id), isEmpty);
      expect(
        await db.select(db.deviceEqProfiles).get(),
        isEmpty,
        reason: 'the cascade needs foreign keys on',
      );
    });

    test('round-trips a whole chain', () async {
      await dao.recordSeen(cans, DateTime(2026));
      final chain = EqChain(
        engine: EqEngine.graphic,
        presetName: 'Custom',
        bandGains: [for (var i = 0; i < eqBandCount; i++) i - 9.5],
        autoEqProfile: AutoEqProfile(id: 3, name: 'X', source: 'y', rank: 2),
        preampGain: -4.5,
        eqEnabled: true,
      );
      final saved = await dao.insertProfile(cans.id, 'All', chain);
      expect(saved.chain, chain);
    });
  });

  group('EqChain.changesOnto', () {
    test('carries only the fields that changed', () {
      final base = EqChain.flat(EqEngine.parametric).copyWith(
        autoEqProfile: AutoEqProfile(id: 99, name: 'Gone', source: 'x'),
      );
      final before = EqChain.flat(EqEngine.parametric);
      final after = before.copyWith(preampGain: -2, eqEnabled: true);

      final merged = after.changesOnto(base, before: before);

      expect(merged.preampGain, -2);
      expect(merged.eqEnabled, isTrue);
      expect(merged.autoEqProfile?.id, 99);
    });
  });

  group('device identity', () {
    test('mpv names the same Linux sink two ways', () {
      expect(
        normalizeMpvDeviceId('pipewire/alsa_output.usb-Schiit'),
        'pulse/alsa_output.usb-Schiit',
      );
      expect(
        normalizeMpvDeviceId('coreaudio/BuiltInSpeakerDevice'),
        'coreaudio/BuiltInSpeakerDevice',
      );
    });

    test('reads the default sink from pactl info', () {
      expect(
        PactlSystemOutput.parseDefaultSink(
          'Server Name: PulseAudio (on PipeWire 1.0.5)\n'
          'Default Sink: bluez_output.AC_80_0A.1\n'
          'Default Source: alsa_input.pci\n',
        ),
        'bluez_output.AC_80_0A.1',
      );
      expect(PactlSystemOutput.parseDefaultSink('Server Name: x\n'), isNull);
    });

    test('guesses a type from a device name', () {
      expect(
        classifyDevice('pulse/bluez_output.AC_80', ''),
        AudioDeviceType.bluetooth,
      );
      expect(
        classifyDevice('wasapi/{x}', 'Speakers (Schiit USB Audio)'),
        AudioDeviceType.usbDac,
      );
      expect(
        classifyDevice('pulse/alsa_output.pci.hdmi-stereo', ''),
        AudioDeviceType.hdmiOptical,
      );
      expect(
        classifyDevice('coreaudio/x', 'External Headphones'),
        AudioDeviceType.headphoneJack,
      );
      expect(
        classifyDevice('coreaudio/x', 'MacBook Pro Speakers'),
        AudioDeviceType.builtinSpeaker,
      );
    });

    test('reads what the native side sends', () {
      final e = AudioEndpoint.fromPlatform({
        'id': 'android/bluetooth_a2dp/AC:80',
        'name': 'Pixel Buds',
        'type': 'bluetooth',
      });
      expect(e?.type, AudioDeviceType.bluetooth);
      expect(AudioEndpoint.fromPlatform({'name': 'no id'}), isNull);
      expect(AudioEndpoint.fromPlatform(null), isNull);
    });
  });
}
