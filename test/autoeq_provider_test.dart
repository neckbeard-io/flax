import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/services/autoeq/autoeq_database.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';

/// Stands in for the real database so the state transitions around a download
/// can be tested without pulling 113 MB over the network. Everything except the
/// download itself is the real implementation reading real files.
class _StubDatabase extends AutoEqDatabase {
  _StubDatabase(this.dir) : super(cacheDirOverride: dir);

  final Directory dir;

  @override
  Stream<String> downloadDatabase() async* {
    yield 'Downloading...';
    // Mirrors what the real extraction leaves behind: curves keyed by index id,
    // an index, and metadata carrying the layout version that isAvailable
    // requires. The literal 2 tracks AutoEqDatabase's private _cacheVersion; if
    // that is bumped without updating this, isAvailable goes false and these
    // tests fail loudly rather than silently testing nothing.
    Directory(p.join(dir.path, 'data')).createSync(recursive: true);
    File(p.join(dir.path, 'data', '7.txt')).writeAsStringSync(
      'GraphicEQ: 20 -1.0; 100 -2.5; 1000 0.0; 10000 1.5; 20000 -4.0',
    );
    File(p.join(dir.path, 'index.json')).writeAsStringSync(jsonEncode([
      {'id': 7, 'name': 'Test Cans', 'source': 'oratory1990', 'rank': 1},
      {'id': 8, 'name': 'Other Cans', 'source': 'crinacle', 'rank': 2},
    ]));
    File(p.join(dir.path, 'meta.json')).writeAsStringSync(jsonEncode({
      'commitTime': '2026/01/01 00:00:00',
      'profileCount': 2,
      'curveCount': 1,
      'cacheVersion': 2,
    }));
    yield 'Done';
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flax_autoeq_provider_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('a completed download leaves the profile list populated', () async {
    final notifier = AutoEqNotifier(_StubDatabase(tmp));
    addTearDown(notifier.dispose);

    // Nothing downloaded yet.
    await pumpEventQueue();
    expect(notifier.state.dbAvailable, isFalse);
    expect(notifier.state.searchResults, isEmpty);

    await notifier.downloadDatabase();

    expect(notifier.state.dbAvailable, isTrue);
    expect(notifier.state.downloading, isFalse);
    // The regression: this was empty, so the screen that triggered the download
    // showed "no profiles found" until it was rebuilt from scratch.
    expect(notifier.state.searchResults, isNotEmpty,
        reason: 'results must be loaded once the database becomes available');
    expect(notifier.state.searchResults.map((p) => p.name),
        containsAll(<String>['Test Cans', 'Other Cans']));
  });

  test('a download preserves whatever the user had typed', () async {
    final notifier = AutoEqNotifier(_StubDatabase(tmp));
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    // Query typed before the database existed, so it matched nothing.
    await notifier.search('other');
    expect(notifier.state.searchResults, isEmpty);

    await notifier.downloadDatabase();

    expect(notifier.state.searchQuery, 'other',
        reason: 'the download must not silently reset the query');
    expect(notifier.state.searchResults.map((p) => p.name), ['Other Cans']);
  });

  test('a profile saved before the download resolves afterwards', () async {
    SharedPreferences.setMockInitialValues({
      'flax_autoeq_profile': jsonEncode({
        'id': 7,
        'name': 'Test Cans',
        'source': 'oratory1990',
        'rank': 1,
      }),
    });

    final notifier = AutoEqNotifier(_StubDatabase(tmp));
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    // No database, so nothing to restore from yet.
    expect(notifier.state.activeProfile, isNull);

    await notifier.downloadDatabase();

    expect(notifier.state.activeProfile, isNotNull);
    expect(notifier.state.activeProfile!.name, 'Test Cans');
    expect(notifier.state.activeProfile!.points, isNotEmpty,
        reason: 'a restored profile must carry a real curve');
  });

  test('selecting a profile with no curve reports an error and stays inactive',
      () async {
    final notifier = AutoEqNotifier(_StubDatabase(tmp));
    addTearDown(notifier.dispose);
    await notifier.downloadDatabase();

    // Id 8 is in the index but has no curve file, matching the handful of
    // profiles the upstream archive indexes without shipping data for.
    final withoutCurve =
        notifier.state.searchResults.firstWhere((p) => p.id == 8);
    await notifier.selectProfile(withoutCurve);

    expect(notifier.state.activeProfile, isNull,
        reason: 'a profile that corrects nothing must not appear active');
    expect(notifier.state.error, isNotNull);
  });

  test('selecting a profile with a curve activates it', () async {
    final notifier = AutoEqNotifier(_StubDatabase(tmp));
    addTearDown(notifier.dispose);
    await notifier.downloadDatabase();

    final withCurve = notifier.state.searchResults.firstWhere((p) => p.id == 7);
    await notifier.selectProfile(withCurve);

    expect(notifier.state.error, isNull);
    expect(notifier.state.activeProfile?.name, 'Test Cans');
    expect(notifier.state.activeProfile!.points.length, 5);
  });
}
