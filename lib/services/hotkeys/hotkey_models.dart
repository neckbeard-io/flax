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

/// The label for one key.
///
/// Never derived from [PhysicalKeyboardKey.debugName]: Flutter strips key
/// names from release builds, so every letter used to show as "Key" there —
/// Ctrl + Alt + A read "Ctrl + Alt + Key" — while debug builds looked right.
/// Letters, digits and function keys are read off the key's USB HID code;
/// everything else comes from [_namedKeys].
String _formatKey(PhysicalKeyboardKey key, {required bool mac}) {
  final named = (mac ? _macSymbols[key] : null) ?? _namedKeys[key];
  if (named != null) return named;

  final usage = key.usbHidUsage;
  int offset(PhysicalKeyboardKey first) => usage - first.usbHidUsage;
  bool within(PhysicalKeyboardKey first, PhysicalKeyboardKey last) =>
      usage >= first.usbHidUsage && usage <= last.usbHidUsage;

  if (within(PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.keyZ)) {
    return String.fromCharCode(0x41 + offset(PhysicalKeyboardKey.keyA));
  }
  if (within(PhysicalKeyboardKey.digit1, PhysicalKeyboardKey.digit9)) {
    return '${1 + offset(PhysicalKeyboardKey.digit1)}';
  }
  if (within(PhysicalKeyboardKey.f1, PhysicalKeyboardKey.f12)) {
    return 'F${1 + offset(PhysicalKeyboardKey.f1)}';
  }
  if (within(PhysicalKeyboardKey.f13, PhysicalKeyboardKey.f24)) {
    return 'F${13 + offset(PhysicalKeyboardKey.f13)}';
  }
  if (within(PhysicalKeyboardKey.numpad1, PhysicalKeyboardKey.numpad9)) {
    return 'Num ${1 + offset(PhysicalKeyboardKey.numpad1)}';
  }
  // Still something to recognize it by, rather than a bare "Key".
  return 'Key 0x${usage.toRadixString(16)}';
}

/// macOS writes these keys as symbols.
final Map<PhysicalKeyboardKey, String> _macSymbols = {
  PhysicalKeyboardKey.arrowRight: '→',
  PhysicalKeyboardKey.arrowLeft: '←',
  PhysicalKeyboardKey.arrowUp: '↑',
  PhysicalKeyboardKey.arrowDown: '↓',
  PhysicalKeyboardKey.enter: '⏎',
  PhysicalKeyboardKey.backspace: '⌫',
};

final Map<PhysicalKeyboardKey, String> _namedKeys = {
  PhysicalKeyboardKey.space: 'Space',
  PhysicalKeyboardKey.arrowRight: 'Right',
  PhysicalKeyboardKey.arrowLeft: 'Left',
  PhysicalKeyboardKey.arrowUp: 'Up',
  PhysicalKeyboardKey.arrowDown: 'Down',
  PhysicalKeyboardKey.escape: 'Esc',
  PhysicalKeyboardKey.enter: 'Enter',
  PhysicalKeyboardKey.tab: 'Tab',
  PhysicalKeyboardKey.backspace: 'Backspace',
  PhysicalKeyboardKey.delete: 'Del',
  PhysicalKeyboardKey.insert: 'Insert',
  PhysicalKeyboardKey.home: 'Home',
  PhysicalKeyboardKey.end: 'End',
  PhysicalKeyboardKey.pageUp: 'Page Up',
  PhysicalKeyboardKey.pageDown: 'Page Down',
  PhysicalKeyboardKey.digit0: '0',
  PhysicalKeyboardKey.numpad0: 'Num 0',
  PhysicalKeyboardKey.minus: '-',
  PhysicalKeyboardKey.equal: '=',
  PhysicalKeyboardKey.bracketLeft: '[',
  PhysicalKeyboardKey.bracketRight: ']',
  PhysicalKeyboardKey.backslash: r'\',
  PhysicalKeyboardKey.semicolon: ';',
  PhysicalKeyboardKey.quote: "'",
  PhysicalKeyboardKey.backquote: '`',
  PhysicalKeyboardKey.comma: ',',
  PhysicalKeyboardKey.period: '.',
  PhysicalKeyboardKey.slash: '/',
  PhysicalKeyboardKey.numpadAdd: 'Num +',
  PhysicalKeyboardKey.numpadSubtract: 'Num -',
  PhysicalKeyboardKey.numpadMultiply: 'Num *',
  PhysicalKeyboardKey.numpadDivide: 'Num /',
  PhysicalKeyboardKey.numpadDecimal: 'Num .',
  PhysicalKeyboardKey.numpadEnter: 'Num Enter',
  PhysicalKeyboardKey.mediaPlayPause: 'Play/Pause',
  PhysicalKeyboardKey.mediaTrackNext: 'Next Track',
  PhysicalKeyboardKey.mediaTrackPrevious: 'Previous Track',
  PhysicalKeyboardKey.mediaStop: 'Stop',
  PhysicalKeyboardKey.audioVolumeUp: 'Volume Up',
  PhysicalKeyboardKey.audioVolumeDown: 'Volume Down',
  PhysicalKeyboardKey.audioVolumeMute: 'Mute',
};
