import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/logging/crash_log.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('flax_crash_');
    CrashLog.resetForTest();
    AppLogger.reset(debugOutput: false);
    await CrashLog.init(directory: dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  String written() => File(CrashLog.path!).readAsStringSync();

  test('an error is kept on disk with the log that led up to it', () {
    AppLogger.i('Startup', 'UI mounted');
    CrashLog.record(
      'FlutterError',
      StateError('no element'),
      StackTrace.current,
    );

    final log = written();
    expect(CrashLog.path, endsWith('logs/${CrashLog.fileName}'));
    expect(log, contains('FlutterError'));
    expect(log, contains('Bad state: no element'));
    expect(log, contains('UI mounted'));
  });

  test('an error raised on every rebuild is counted, not rewritten', () {
    for (var i = 0; i < 50; i++) {
      CrashLog.record('FlutterError', StateError('same'), null);
    }
    CrashLog.record('FlutterError', StateError('different'), null);

    final log = written();
    expect('Bad state: same'.allMatches(log), hasLength(1));
    expect(log, contains('(previous error repeated 49 more times)'));
    expect(log, contains('Bad state: different'));
  });

  test('the log is trimmed once it outgrows its limit', () {
    final big = 'x' * 4096;
    for (var i = 0; i < 120; i++) {
      CrashLog.record('Uncaught', '$i $big', null);
    }
    final size = File(CrashLog.path!).lengthSync();
    expect(size, lessThanOrEqualTo(CrashLog.maxBytes));
    expect(written(), contains('119 '));
  });

  test('a trimmed log stays readable when the cut lands mid-character', () {
    final wide = 'é' * 3000;
    for (var i = 0; i < 120; i++) {
      CrashLog.record('Uncaught', '$i $wide', null);
    }
    expect(CrashLog.readRecent(), contains('119 '));
  });

  test('nothing saved reads as nothing', () {
    expect(CrashLog.readRecent(), isNull);
  });

  test('before init nothing is written and nothing throws', () {
    CrashLog.resetForTest();
    expect(() => CrashLog.record('Uncaught', 'early', null), returnsNormally);
    expect(CrashLog.path, isNull);
  });
}
