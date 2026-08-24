import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/hotkeys/hotkey_models.dart';
import 'package:flax/services/platform/window_state.dart';

const String kGlobalHotkeysEnabledKey = 'flax_global_hotkeys_enabled';
const String kGlobalHotkeysBindingsKey = 'flax_global_hotkeys_bindings';

class HotKeyState {
  final bool enabled;
  final Map<HotKeyAction, HotKey?> bindings;
  final Map<HotKeyAction, String?> errors;

  const HotKeyState({
    this.enabled = true,
    this.bindings = const {},
    this.errors = const {},
  });

  HotKeyState copyWith({
    bool? enabled,
    Map<HotKeyAction, HotKey?>? bindings,
    Map<HotKeyAction, String?>? errors,
  }) {
    return HotKeyState(
      enabled: enabled ?? this.enabled,
      bindings: bindings ?? this.bindings,
      errors: errors ?? this.errors,
    );
  }
}

/// Abstract interface to allow unit testing without native platform channels.
abstract class HotKeyClient {
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  });
  Future<void> unregister(HotKey hotKey);
  Future<void> unregisterAll();
}

class SystemHotKeyClient implements HotKeyClient {
  const SystemHotKeyClient();

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) {
    return hotKeyManager.register(
      hotKey,
      keyDownHandler: keyDownHandler,
      keyUpHandler: keyUpHandler,
    );
  }

  @override
  Future<void> unregister(HotKey hotKey) {
    return hotKeyManager.unregister(hotKey);
  }

  @override
  Future<void> unregisterAll() {
    return hotKeyManager.unregisterAll();
  }
}

class HotKeyNotifier extends StateNotifier<HotKeyState> {
  final Ref? _ref;
  final HotKeyClient _client;
  final bool _isDesktop;
  SharedPreferences? _prefs;

  HotKeyNotifier({
    this._ref,
    HotKeyClient? client,
    bool? isDesktop,
    this._prefs,
  }) : _client = client ?? const SystemHotKeyClient(),
       _isDesktop =
           isDesktop ??
           (!kIsWeb &&
               (Platform.isMacOS || Platform.isWindows || Platform.isLinux)),
       super(const HotKeyState()) {
    if (_isDesktop) {
      init();
    }
  }

  Future<void>? _initFuture;

  bool get isDesktop => _isDesktop;

  Future<void> init() {
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    _prefs ??= await SharedPreferences.getInstance();

    final enabled = _prefs?.getBool(kGlobalHotkeysEnabledKey) ?? true;
    final storedJson = _prefs?.getString(kGlobalHotkeysBindingsKey);

    final bindings = <HotKeyAction, HotKey?>{};
    if (storedJson != null && storedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
        for (final action in HotKeyAction.values) {
          if (decoded.containsKey(action.name)) {
            final raw = decoded[action.name];
            if (raw == null) {
              bindings[action] = null;
            } else {
              bindings[action] = HotKey.fromJson(
                Map<String, dynamic>.from(raw as Map),
              );
            }
          } else {
            bindings[action] = action.defaultHotKey();
          }
        }
      } catch (e) {
        developer.log(
          'Failed to parse hotkeys json: $e',
          name: 'HotKeyService',
        );
        for (final action in HotKeyAction.values) {
          bindings[action] = action.defaultHotKey();
        }
      }
    } else {
      for (final action in HotKeyAction.values) {
        bindings[action] = action.defaultHotKey();
      }
    }

    state = state.copyWith(enabled: enabled, bindings: bindings);

    if (enabled) {
      await _registerAll();
    }
  }

  Future<void> _registerAll() async {
    await _client.unregisterAll();
    final errors = <HotKeyAction, String?>{};
    for (final entry in state.bindings.entries) {
      final action = entry.key;
      final hotKey = entry.value;
      if (hotKey == null) continue;

      try {
        await _client.register(
          hotKey,
          keyDownHandler: (_) => _handleAction(action),
        );
      } catch (e) {
        developer.log(
          'Failed to register global hotkey for $action: $e',
          name: 'HotKeyService',
        );
        errors[action] = e.toString();
      }
    }
    state = state.copyWith(errors: errors);
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _prefs?.setBool(kGlobalHotkeysEnabledKey, enabled);

    if (enabled) {
      await _registerAll();
    } else {
      await _client.unregisterAll();
      state = state.copyWith(errors: const {});
    }
  }

  Future<void> updateBinding(HotKeyAction action, HotKey? newHotKey) async {
    final oldHotKey = state.bindings[action];
    if (oldHotKey != null) {
      try {
        await _client.unregister(oldHotKey);
      } catch (_) {}
    }

    final newBindings = Map<HotKeyAction, HotKey?>.from(state.bindings);
    newBindings[action] = newHotKey;

    final newErrors = Map<HotKeyAction, String?>.from(state.errors);
    newErrors.remove(action);

    if (state.enabled && newHotKey != null) {
      try {
        await _client.register(
          newHotKey,
          keyDownHandler: (_) => _handleAction(action),
        );
        newErrors[action] = null;
      } catch (e) {
        newErrors[action] = e.toString();
      }
    }

    state = state.copyWith(bindings: newBindings, errors: newErrors);
    await _saveBindings();
  }

  Future<void> resetToDefaults() async {
    await _client.unregisterAll();

    final bindings = <HotKeyAction, HotKey?>{};
    for (final action in HotKeyAction.values) {
      bindings[action] = action.defaultHotKey();
    }

    state = state.copyWith(bindings: bindings, errors: const {});
    await _saveBindings();

    if (state.enabled) {
      await _registerAll();
    }
  }

  Future<void> _saveBindings() async {
    final map = <String, dynamic>{};
    for (final entry in state.bindings.entries) {
      map[entry.key.name] = entry.value?.toJson();
    }
    await _prefs?.setString(kGlobalHotkeysBindingsKey, jsonEncode(map));
  }

  void _handleAction(HotKeyAction action) {
    final ref = _ref;
    if (ref == null) return;
    final player = ref.read(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    switch (action) {
      case HotKeyAction.playPause:
        playerNotifier.togglePlayPause();
        break;
      case HotKeyAction.nextTrack:
        playerNotifier.next();
        break;
      case HotKeyAction.previousTrack:
        playerNotifier.previous();
        break;
      case HotKeyAction.volumeUp:
        playerNotifier.setVolume((player.volume + 0.05).clamp(0.0, 1.0));
        break;
      case HotKeyAction.volumeDown:
        playerNotifier.setVolume((player.volume - 0.05).clamp(0.0, 1.0));
        break;
      case HotKeyAction.toggleMute:
        playerNotifier.toggleMute();
        break;
      case HotKeyAction.toggleFavorite:
        playerNotifier.toggleCurrentSongStarred();
        break;
      case HotKeyAction.focusWindow:
        if (WindowStateService.isSupported) {
          windowManager.show();
          windowManager.focus();
        }
        break;
    }
  }
}

final hotKeyServiceProvider =
    StateNotifierProvider<HotKeyNotifier, HotKeyState>((ref) {
      return HotKeyNotifier(ref: ref);
    });
