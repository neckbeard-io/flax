import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/audio_output_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AudioOutputSettings model and persistence', () {
    test('default values', () {
      const s = AudioOutputSettings();
      expect(s.engine, AudioOutputEngine.auto);
      expect(s.deviceName, 'auto');
      expect(s.deviceDescription, 'System Default');
      expect(s.exclusive, isFalse);
      expect(s.sampleRate, 'Auto');
      expect(s.bitDepth, 'Auto');
    });

    test('serialization roundtrip', () {
      const original = AudioOutputSettings(
        engine: AudioOutputEngine.pipewire,
        deviceName: 'pipewire/alsa_output.pci-0000.analog-stereo',
        deviceDescription: 'Built-in Audio Analog Stereo',
        exclusive: true,
        sampleRate: '96 kHz',
        bitDepth: '24-bit',
      );
      final json = original.toJson();
      final restored = AudioOutputSettings.fromJson(json);

      expect(restored.engine, AudioOutputEngine.pipewire);
      expect(
        restored.deviceName,
        'pipewire/alsa_output.pci-0000.analog-stereo',
      );
      expect(restored.deviceDescription, 'Built-in Audio Analog Stereo');
      expect(restored.exclusive, isTrue);
      expect(restored.sampleRate, '96 kHz');
      expect(restored.bitDepth, '24-bit');
    });

    test('AudioOutputSettingsNotifier updates and saves', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(audioOutputSettingsProvider.notifier);
      expect(
        container.read(audioOutputSettingsProvider).engine,
        AudioOutputEngine.auto,
      );

      notifier.setEngine(AudioOutputEngine.pipewire);
      expect(
        container.read(audioOutputSettingsProvider).engine,
        AudioOutputEngine.pipewire,
      );

      notifier.setDevice('pipewire/usb-dac', 'USB DAC');
      expect(
        container.read(audioOutputSettingsProvider).deviceName,
        'pipewire/usb-dac',
      );
      expect(
        container.read(audioOutputSettingsProvider).deviceDescription,
        'USB DAC',
      );

      notifier.setExclusive(true);
      expect(container.read(audioOutputSettingsProvider).exclusive, isTrue);

      notifier.setSampleRate('192 kHz');
      expect(container.read(audioOutputSettingsProvider).sampleRate, '192 kHz');

      notifier.setBitDepth('32-bit float');
      expect(
        container.read(audioOutputSettingsProvider).bitDepth,
        '32-bit float',
      );
    });
  });

  group('AudioOutputScreen widget tests', () {
    testWidgets(
      'renders on mobile viewport (390x844) without overflow and displays controls',
      (tester) async {
        tester.view.physicalSize = const ui.Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            audioDevicesProvider.overrideWith(
              (ref) => const [
                mpv.Device(name: 'auto', description: 'System Default'),
                mpv.Device(
                  name: 'pipewire/alsa_output.analog-stereo',
                  description: 'Built-in Audio Analog Stereo',
                ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AudioOutputScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audio Output'), findsOneWidget);
        expect(find.text('Engine & Device'), findsOneWidget);
        expect(find.text('Output Device'), findsOneWidget);
        expect(find.text('Exclusive Mode'), findsOneWidget);
        expect(find.text('Format'), findsOneWidget);
        expect(find.text('Playback'), findsOneWidget);

        // Open Device Picker
        await tester.tap(find.text('Output Device'));
        await tester.pumpAndSettle();

        expect(find.text('Select Audio Device'), findsOneWidget);
        expect(find.text('Built-in Audio Analog Stereo'), findsOneWidget);

        // Select device
        await tester.tap(find.text('Built-in Audio Analog Stereo'));
        await tester.pumpAndSettle();

        expect(
          container.read(audioOutputSettingsProvider).deviceDescription,
          'Built-in Audio Analog Stereo',
        );
      },
    );
  });
}
