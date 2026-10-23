import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/audio_devices_screen.dart';
import 'package:flax/features/settings/device_eq_provider.dart';
import 'package:flax/features/settings/device_profile_bar.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/audio_devices/audio_device.dart';
import 'package:flax/shared/audio/eq_filter.dart';

/// The device bar on the Equalizer screen and the Audio Devices page (#69), at
/// phone sizes and in the language whose strings run longest.
void main() {
  final flat = EqChain.flat(EqEngine.parametric);

  AudioDeviceRecord device(String id, String name, {bool autoSwitch = true}) =>
      AudioDeviceRecord(
        deviceId: id,
        deviceName: name,
        type: AudioDeviceType.bluetooth,
        firstSeenAt: DateTime(2026, 1, 1),
        lastSeenAt: DateTime(2026, 3, 14),
        defaultProfileId: '$id-a',
        autoSwitch: autoSwitch,
      );

  List<DeviceEqProfile> profilesOf(String id) => [
    DeviceEqProfile(
      id: '$id-a',
      deviceId: id,
      profileName: 'Neutral Harman target with a very long name',
      chain: flat,
      isDeviceDefault: true,
    ),
    DeviceEqProfile(
      id: '$id-b',
      deviceId: id,
      profileName: 'Bass Boost',
      chain: flat,
    ),
  ];

  Widget app(Widget home, {Locale locale = const Locale('de')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  void phone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('DeviceProfileBarView', () {
    for (final size in const [Size(390, 844), Size(360, 640)]) {
      testWidgets('fits a ${size.width.round()}px phone', (tester) async {
        phone(tester, size);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: DeviceProfileBarView(
                deviceName: 'Sony WH-1000XM4 Wireless Noise Cancelling',
                deviceType: AudioDeviceType.bluetooth,
                profiles: profilesOf('cans'),
                activeProfileId: 'cans-a',
                autoSwitch: true,
                onSelect: (_) {},
                onAutoSwitch: (_) {},
                onNew: () {},
                onManage: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final key in const [
          'eq-profile-picker',
          'eq-auto-switch',
          'eq-profile-actions',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
        }
      });
    }

    testWidgets('picks a profile and toggles auto-switch', (tester) async {
      String? selected;
      bool? autoSwitch;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DeviceProfileBarView(
              deviceName: 'Cans',
              deviceType: AudioDeviceType.bluetooth,
              profiles: profilesOf('cans'),
              activeProfileId: 'cans-a',
              autoSwitch: true,
              onSelect: (id) => selected = id,
              onAutoSwitch: (v) => autoSwitch = v,
              onNew: () {},
              onManage: () {},
            ),
          ),
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('eq-profile-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bass Boost').last);
      await tester.pumpAndSettle();
      expect(selected, 'cans-b');

      await tester.tap(find.byKey(const ValueKey('eq-auto-switch')));
      expect(autoSwitch, isFalse);
    });

    testWidgets('marks the default and disables what cannot apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DeviceProfileBarView(
              deviceName: 'Cans',
              deviceType: AudioDeviceType.bluetooth,
              profiles: profilesOf('cans'),
              activeProfileId: 'cans-a',
              autoSwitch: true,
              onSelect: (_) {},
              onAutoSwitch: (_) {},
              onNew: () {},
              onRename: () {},
              onManage: () {},
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      expect(
        find.text('Neutral Harman target with a very long name (default)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('eq-profile-actions')));
      await tester.pumpAndSettle();
      PopupMenuItem<Object?> item(String text) => tester.widget(
        find.ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      expect(item('Rename profile…').enabled, isTrue);
      expect(item('Make default').enabled, isFalse);
      expect(item('Delete profile').enabled, isFalse);
    });
  });

  group('AudioDeviceList', () {
    testWidgets('fits a phone with a device expanded', (tester) async {
      phone(tester, const Size(360, 640));
      final actions = _RecordingActions();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AudioDeviceList(
              devices: [
                device('cans', 'Sony WH-1000XM4 Wireless Noise Cancelling'),
                device('dac', 'Schiit Modi 3+'),
              ],
              profiles: [...profilesOf('cans'), ...profilesOf('dac')],
              currentDeviceId: 'cans',
              actions: actions,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sony WH-1000XM4 Wireless Noise Cancelling'));
      await tester.pumpAndSettle();

      // A non-default profile becomes the default when tapped.
      await tester.tap(find.text('Bass Boost'));
      expect(actions.calls, ['default cans cans-b']);

      // The device in use cannot be forgotten.
      final forget = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Gerät vergessen'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(forget.onPressed, isNull);
    });

    testWidgets('says so when there are no devices', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AudioDeviceList(
              devices: const [],
              profiles: const [],
              currentDeviceId: null,
              actions: _RecordingActions(),
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      expect(find.textContaining('No devices yet'), findsOneWidget);
    });

    testWidgets('forgets a device after confirming', (tester) async {
      final actions = _RecordingActions();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AudioDeviceList(
              devices: [device('dac', 'Schiit Modi 3+')],
              profiles: profilesOf('dac'),
              currentDeviceId: 'cans',
              actions: actions,
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.tap(find.text('Schiit Modi 3+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['forget dac']);
    });
  });

  testWidgets('the Equalizer screen shows the device bar on a phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    phone(tester, const Size(360, 640));
    final cans = device('cans', 'Sony WH-1000XM4');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceEqStateProvider.overrideWith(
            (ref) => DeviceEqState(
              device: cans,
              profiles: profilesOf('cans'),
              activeProfileId: 'cans-a',
              deviceCount: 1,
            ),
          ),
        ],
        child: app(const EqualizerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sony WH-1000XM4'), findsOneWidget);
    final rect = tester.getRect(find.byKey(const ValueKey('eq-auto-switch')));
    expect(rect.right, lessThanOrEqualTo(360));
  });
}

class _RecordingActions implements AudioDeviceActions {
  final calls = <String>[];

  @override
  Future<void> deleteDevice(String deviceId) async =>
      calls.add('forget $deviceId');

  @override
  Future<void> deleteProfile(String profileId) async =>
      calls.add('delete $profileId');

  @override
  Future<void> renameDevice(String deviceId, String? name) async =>
      calls.add('rename $deviceId $name');

  @override
  Future<void> setAutoSwitch(String deviceId, bool enabled) async =>
      calls.add('auto $deviceId $enabled');

  @override
  Future<void> setDefaultProfile(String deviceId, String profileId) async =>
      calls.add('default $deviceId $profileId');
}
