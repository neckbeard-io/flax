import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The macOS window draws its own buttons and hides the traffic lights, so its
/// style mask is set by hand in MainFlutterWindow.swift. AppKit ignores
/// `miniaturize(_:)` on a window whose style mask lacks `.miniaturizable` — no
/// error, nothing happens — which is how flax's minimize button and Cmd-M were
/// both dead on macOS. Nothing short of a real Mac shows it, so pin the mask.
void main() {
  test('the macOS window can be minimized', () {
    final code = File('macos/Runner/MainFlutterWindow.swift')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    final mask = RegExp(r'styleMask\s*=\s*\[([^\]]*)\]').firstMatch(code);
    expect(mask, isNotNull, reason: 'styleMask assignment not found');
    expect(mask!.group(1), contains('.miniaturizable'));
  });
}
