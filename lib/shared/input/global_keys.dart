import 'package:flutter/services.dart';

/// What a keypress means when nothing in particular has focus.
enum GlobalKeyAction {
  /// Leave the key alone.
  none,

  /// Put the caret in the sidebar search field.
  focusSearch,

  /// Play or pause.
  togglePlayback,
}

/// The app's global shortcuts, as a decision rather than a side effect.
///
/// [isEditing] is whether a text field has focus, in which case every key is
/// just a character the user is typing — the one rule that matters most here,
/// since both shortcuts are printable characters.
GlobalKeyAction globalKeyAction(KeyEvent event, {required bool isEditing}) {
  // Key *down* only. Acting on both edges toggles playback twice per press.
  if (event is! KeyDownEvent) return GlobalKeyAction.none;
  if (isEditing) return GlobalKeyAction.none;

  return switch (event.logicalKey) {
    LogicalKeyboardKey.slash => GlobalKeyAction.focusSearch,
    LogicalKeyboardKey.space => GlobalKeyAction.togglePlayback,
    _ => GlobalKeyAction.none,
  };
}
