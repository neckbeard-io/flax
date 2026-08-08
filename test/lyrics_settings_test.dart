import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/settings/lyrics_settings.dart';
import 'package:flax/shared/widgets/shell_scaffold.dart';

void main() {
  group('lyrics settings', () {
    test('the sung line is always larger than the rest', () {
      for (final size in [
        LyricsSettings.minFontSize,
        LyricsSettings.defaultFontSize,
        LyricsSettings.maxFontSize,
      ]) {
        final s = LyricsSettings(fontSize: size);
        expect(
          s.activeFontSize,
          greaterThan(s.fontSize),
          reason: 'at ${size}pt the current line must still stand out',
        );
      }
    });

    test('alignment carries a TextAlign the panel can apply', () {
      expect(LyricsAlignment.left.textAlign, TextAlign.left);
      expect(LyricsAlignment.center.textAlign, TextAlign.center);
    });

    test('a stored size survives a round trip', () {
      final restored = LyricsSettings.fromJson(
        const LyricsSettings(fontSize: 22, alignment: LyricsAlignment.center)
            .toJson(),
      );
      expect(restored.fontSize, 22);
      expect(restored.alignment, LyricsAlignment.center);
    });

    test('nonsense in prefs falls back rather than breaking the panel', () {
      // A size from a future build with a wider range, and an alignment that
      // no longer exists. Neither may produce unreadable lyrics.
      final restored = LyricsSettings.fromJson({
        'fontSize': 400.0,
        'alignment': 'justified',
      });
      expect(restored.fontSize, LyricsSettings.maxFontSize);
      expect(restored.alignment, LyricsAlignment.left);

      final empty = LyricsSettings.fromJson({});
      expect(empty.fontSize, LyricsSettings.defaultFontSize);
    });
  });

  group('shell chrome', () {
    test('the phone now-playing screen takes the whole window', () {
      expect(ShellScaffold.isImmersiveRoute('/now-playing', 620), isTrue);
    });

    test('at panel widths now playing is an ordinary screen in the shell', () {
      // It has to keep the shell: the sidebar and the mini player's transport
      // are part of the desktop layout. A shell of its own meant two sidebars
      // alive at once, two text fields sharing one FocusNode, and "/" dead.
      expect(ShellScaffold.isImmersiveRoute('/now-playing', 700), isFalse);
      expect(ShellScaffold.isImmersiveRoute('/now-playing', 1500), isFalse);
    });

    test('no other route is ever immersive', () {
      for (final route in ['/artists', '/albums', '/settings', '/search']) {
        expect(ShellScaffold.isImmersiveRoute(route, 400), isFalse);
      }
    });
  });
}
