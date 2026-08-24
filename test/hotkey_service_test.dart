import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/hotkeys/hotkey_service.dart';

class MockHotKeyClient implements HotKeyClient {
  final List<HotKey> registered = [];
  final Map<String, HotKeyHandler> handlers = {};
  bool failNextRegister = false;

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    if (failNextRegister) {
      throw PlatformException(
        code: 'hotkey_already_registered',
        message: 'Shortcut conflict with OS',
      );
    }
    registered.add(hotKey);
    if (keyDownHandler != null) {
      handlers[hotKey.identifier] = keyDownHandler;
    }
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    registered.removeWhere((k) => k.identifier == hotKey.identifier);
    handlers.remove(hotKey.identifier);
  }

  @override
  Future<void> unregisterAll() async {
    registered.clear();
    handlers.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HotKey Models & Formatting', () {
    test('formats macOS hotkey combinations correctly', () {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.alt],
      );

      expect(formatHotKey(hotKey, isMacOS: true), equals('⌥ ⌘ Space'));
    });

    test('formats Windows/Linux hotkey combinations correctly', () {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.arrowRight,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      );

      expect(
        formatHotKey(hotKey, isMacOS: false),
        equals('Ctrl + Alt + Right'),
      );
    });

    test('defaults are unassigned/null for all HotKeyActions', () {
      for (final action in HotKeyAction.values) {
        expect(action.defaultHotKey(), isNull);
        final macHotKey = action.suggestedHotKey(isMacOS: true);
        final winHotKey = action.suggestedHotKey(isMacOS: false);

        expect(macHotKey.modifiers, contains(HotKeyModifier.meta));
        expect(winHotKey.modifiers, contains(HotKeyModifier.control));
        expect(action.label.isNotEmpty, isTrue);
        expect(action.description.isNotEmpty, isTrue);
      }
    });
  });

  group('HotKeyNotifier', () {
    late MockHotKeyClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockHotKeyClient();
    });

    test(
      'initializes default bindings as unassigned when on desktop',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = HotKeyNotifier(
          client: mockClient,
          isDesktop: true,
          prefs: prefs,
        );

        await notifier.init();

        expect(notifier.state.enabled, isTrue);
        expect(
          notifier.state.bindings.length,
          equals(HotKeyAction.values.length),
        );
        expect(notifier.state.bindings.values.every((v) => v == null), isTrue);
        expect(mockClient.registered.isEmpty, isTrue);
        expect(notifier.state.errors.isEmpty, isTrue);
      },
    );

    test('disabling global hotkeys unregisters all shortcuts', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = HotKeyNotifier(
        client: mockClient,
        isDesktop: true,
        prefs: prefs,
      );

      await notifier.init();
      await notifier.updateBinding(
        HotKeyAction.playPause,
        HotKeyAction.playPause.suggestedHotKey(),
      );
      expect(mockClient.registered.isNotEmpty, isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state.enabled, isFalse);
      expect(mockClient.registered.isEmpty, isTrue);
      expect(prefs.getBool(kGlobalHotkeysEnabledKey), isFalse);
    });

    test(
      'updateBinding registers new hotkey and persists to SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = HotKeyNotifier(
          client: mockClient,
          isDesktop: true,
          prefs: prefs,
        );

        await notifier.init();

        final customHotKey = HotKey(
          identifier: 'custom_play_pause',
          key: PhysicalKeyboardKey.keyP,
          modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        );

        await notifier.updateBinding(HotKeyAction.playPause, customHotKey);

        expect(
          notifier.state.bindings[HotKeyAction.playPause],
          equals(customHotKey),
        );
        final savedStr = prefs.getString(kGlobalHotkeysBindingsKey);
        expect(savedStr, isNotNull);
        final decoded = jsonDecode(savedStr!) as Map<String, dynamic>;
        expect(decoded['playPause'], isNotNull);
      },
    );

    test(
      'captures registration error when client throws shortcut conflict',
      () async {
        final prefs = await SharedPreferences.getInstance();
        mockClient.failNextRegister = true;

        final notifier = HotKeyNotifier(
          client: mockClient,
          isDesktop: true,
          prefs: prefs,
        );

        await notifier.init();
        await notifier.updateBinding(
          HotKeyAction.playPause,
          HotKeyAction.playPause.suggestedHotKey(),
        );

        expect(
          notifier.state.errors[HotKeyAction.playPause],
          contains('Shortcut conflict'),
        );
      },
    );

    test('resetToDefaults clears all bindings to null', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = HotKeyNotifier(
        client: mockClient,
        isDesktop: true,
        prefs: prefs,
      );

      await notifier.init();

      // Assign a hotkey
      await notifier.updateBinding(
        HotKeyAction.playPause,
        HotKeyAction.playPause.suggestedHotKey(),
      );
      expect(notifier.state.bindings[HotKeyAction.playPause], isNotNull);

      // Reset / Clear
      await notifier.resetToDefaults();
      expect(notifier.state.bindings[HotKeyAction.playPause], isNull);
      expect(notifier.state.bindings.values.every((v) => v == null), isTrue);
    });
  });
}
