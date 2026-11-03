import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The macOS window draws its own buttons and hides the traffic lights by
/// hand in MainFlutterWindow.swift. AppKit ignores `miniaturize(_:)` without
/// telling anyone in two cases, and flax hit both, leaving its minimize
/// button and Cmd-M dead:
///
/// - the style mask lacks `.miniaturizable`;
/// - the minimize button is disabled, which AppKit does to a button whose
///   `alphaValue` is 0. Fading the traffic lights out did that; hiding them
///   (`isHidden`) does not. Measured on GitHub's macOS 15 and 26 runners.
///
/// Nothing short of a real Mac shows either, so pin both in the source.
void main() {
  final code = File('macos/Runner/MainFlutterWindow.swift')
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('the macOS window can be minimized', () {
    final mask = RegExp(r'styleMask\s*=\s*\[([^\]]*)\]').firstMatch(code);
    expect(mask, isNotNull, reason: 'styleMask assignment not found');
    expect(mask!.group(1), contains('.miniaturizable'));
  });

  test('minimize and full screen go through FullScreenAwareWindow', () {
    // AppKit drops a minimize in full screen and any request mid-animation;
    // FullScreenAwareWindow sequences them. Its own tests are Swift, under
    // test/macos/, run by .github/workflows/macos-window.yml.
    expect(code, contains('class MainFlutterWindow: FullScreenAwareWindow'));
    expect(code, contains('observeFullScreenTransitions()'));
    expect(
      File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      contains('FullScreenAwareWindow.swift in Sources'),
    );
  });

  test('hiding the traffic lights leaves minimize enabled', () {
    expect(code, contains('isHidden = true'));
    expect(code, isNot(contains('alphaValue')));
  });
}
