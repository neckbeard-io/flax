@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/autoeq/autoeq_database.dart';

/// Exercises the real download-and-extract path against the live AutoEQ
/// package archive.
///
/// Skipped unless FLAX_AUTOEQ_LIVE=1, because it pulls ~113 MB over the network
/// and decompresses ~341 MB. It exists because the bug it guards against was
/// invisible to every cheaper check: extraction "succeeded", the index was
/// written, the profile count looked right, and every single curve had been
/// overwritten by the next one because they are all named `graphic.txt`. Only
/// counting the curves actually on disk catches that.
///
///   FLAX_AUTOEQ_LIVE=1 flutter test test/autoeq_database_live_test.dart
void main() {
  final live = Platform.environment['FLAX_AUTOEQ_LIVE'] == '1';

  test(
    'downloads and extracts one curve per indexed profile',
    () async {
      final tmp = Directory.systemTemp.createTempSync('flax_autoeq_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final db = AutoEqDatabase(cacheDirOverride: tmp);
      expect(
        await db.isAvailable,
        isFalse,
        reason: 'starts with an empty cache',
      );

      await for (final status in db.downloadDatabase()) {
        // ignore: avoid_print
        print('  $status');
      }

      expect(
        await db.isAvailable,
        isTrue,
        reason: 'cache must be usable, and stamped with the current version',
      );

      final index = await db.loadIndex();
      expect(index.length, greaterThan(8000));

      final curves = Directory('${tmp.path}/data')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .length;

      // The regression: this was 1. Allow a small shortfall for profiles the
      // upstream archive genuinely omits, but nothing like a collapse.
      expect(
        curves,
        greaterThan(index.length - 10),
        reason: 'nearly every indexed profile should have its own curve file',
      );

      // And the curves must be loadable and parse to real points, since a
      // profile with no points silently applies no correction.
      var loaded = 0;
      for (final profile in index.take(50)) {
        final withCurve = await db.loadProfile(profile);
        if (withCurve == null) continue;
        expect(withCurve.points, isNotEmpty);
        loaded++;
      }
      expect(
        loaded,
        greaterThan(45),
        reason: 'sampled profiles should load a parsable curve',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: live ? false : 'set FLAX_AUTOEQ_LIVE=1 to run (downloads ~113 MB)',
  );
}
