import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

enum HotKeyAction {
  playPause,
  nextTrack,
  previousTrack,
  volumeUp,
  volumeDown,
  toggleMute,
  toggleFavorite,
  focusWindow,
}

extension HotKeyActionExtension on HotKeyAction {
  String get label {
    switch (this) {
      case HotKeyAction.playPause:
        return 'Play / Pause';
      case HotKeyAction.nextTrack:
        return 'Next Track';
      case HotKeyAction.previousTrack:
        return 'Previous Track';
      case HotKeyAction.volumeUp:
        return 'Volume Up';
      case HotKeyAction.volumeDown:
        return 'Volume Down';
      case HotKeyAction.toggleMute:
        return 'Mute / Unmute';
      case HotKeyAction.toggleFavorite:
        return 'Favorite / Star Track';
      case HotKeyAction.focusWindow:
        return 'Bring App to Front';
    }
  }

  String get description {
    switch (this) {
      case HotKeyAction.playPause:
        return 'Toggle playback state';
      case HotKeyAction.nextTrack:
        return 'Skip to next track in queue';
      case HotKeyAction.previousTrack:
        return 'Return to previous track or start of current';
      case HotKeyAction.volumeUp:
        return 'Increase volume by 5%';
      case HotKeyAction.volumeDown:
        return 'Decrease volume by 5%';
      case HotKeyAction.toggleMute:
        return 'Toggle audio output mute';
      case HotKeyAction.toggleFavorite:
        return 'Favorite or unfavorite the currently playing track';
      case HotKeyAction.focusWindow:
        return 'Focus the Flax application window';
    }
  }

  HotKey? defaultHotKey({bool? isMacOS}) => null;

  HotKey suggestedHotKey({bool? isMacOS}) {
    final mac = isMacOS ?? (!kIsWeb && Platform.isMacOS);
    final modifiers = mac
        ? [HotKeyModifier.meta, HotKeyModifier.alt]
        : [HotKeyModifier.control, HotKeyModifier.alt];

    PhysicalKeyboardKey key;
    switch (this) {
      case HotKeyAction.playPause:
        key = PhysicalKeyboardKey.space;
        break;
      case HotKeyAction.nextTrack:
        key = PhysicalKeyboardKey.arrowRight;
        break;
      case HotKeyAction.previousTrack:
        key = PhysicalKeyboardKey.arrowLeft;
        break;
      case HotKeyAction.volumeUp:
        key = PhysicalKeyboardKey.arrowUp;
        break;
      case HotKeyAction.volumeDown:
        key = PhysicalKeyboardKey.arrowDown;
        break;
      case HotKeyAction.toggleMute:
        key = PhysicalKeyboardKey.keyM;
        break;
      case HotKeyAction.toggleFavorite:
        key = PhysicalKeyboardKey.keyS;
        break;
      case HotKeyAction.focusWindow:
        key = PhysicalKeyboardKey.keyF;
        break;
    }

    return HotKey(
      identifier: 'flax_hotkey_$name',
      key: key,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}

String formatHotKey(HotKey hotKey, {bool? isMacOS}) {
  final mac = isMacOS ?? (!kIsWeb && Platform.isMacOS);
  final parts = <String>[];

  final modifiers = hotKey.modifiers ?? [];
  if (mac) {
    if (modifiers.contains(HotKeyModifier.control)) parts.add('⌃');
    if (modifiers.contains(HotKeyModifier.alt)) parts.add('⌥');
    if (modifiers.contains(HotKeyModifier.shift)) parts.add('⇧');
    if (modifiers.contains(HotKeyModifier.meta)) parts.add('⌘');
  } else {
    if (modifiers.contains(HotKeyModifier.control)) parts.add('Ctrl');
    if (modifiers.contains(HotKeyModifier.alt)) parts.add('Alt');
    if (modifiers.contains(HotKeyModifier.shift)) parts.add('Shift');
    if (modifiers.contains(HotKeyModifier.meta)) parts.add('Win');
  }

  parts.add(_formatKey(hotKey.physicalKey, mac: mac));

  return mac ? parts.join(' ') : parts.join(' + ');
}

String _formatKey(PhysicalKeyboardKey key, {required bool mac}) {
  if (key == PhysicalKeyboardKey.space) return 'Space';
  if (key == PhysicalKeyboardKey.arrowRight) return mac ? '→' : 'Right';
  if (key == PhysicalKeyboardKey.arrowLeft) return mac ? '←' : 'Left';
  if (key == PhysicalKeyboardKey.arrowUp) return mac ? '↑' : 'Up';
  if (key == PhysicalKeyboardKey.arrowDown) return mac ? '↓' : 'Down';
  if (key == PhysicalKeyboardKey.escape) return 'Esc';
  if (key == PhysicalKeyboardKey.enter) return mac ? '⏎' : 'Enter';
  if (key == PhysicalKeyboardKey.tab) return 'Tab';
  if (key == PhysicalKeyboardKey.backspace) return mac ? '⌫' : 'Backspace';
  if (key == PhysicalKeyboardKey.delete) return 'Del';

  // Handle keyA .. keyZ
  final debug = key.debugName ?? '';
  if (debug.startsWith('Key ')) {
    return debug.substring(4).toUpperCase();
  }
  if (debug.startsWith('Digit ')) {
    return debug.substring(6);
  }
  return debug;
}
