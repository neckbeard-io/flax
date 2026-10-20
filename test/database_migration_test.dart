import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/services/database/database.dart';

/// Schema upgrades that were interrupted partway.
///
/// Drift stores the new schema version only after every step has run, outside
/// a transaction. A launch killed in between leaves the added columns at the
/// old version, and the next launch has to run the same steps over them —
/// which once failed on `duplicate column name: genres_json` and kept the
/// database from ever opening again.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('flax_migration_');
    file = File('${dir.path}/flax_library.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Creates the current schema, then runs [statements] against it.
  Future<void> createCurrentSchema(List<String> statements) async {
    final db = FlaxDatabase(NativeDatabase(file));
    for (final statement in statements) {
      await db.customStatement(statement);
    }
    await db.close();
  }

  Future<Set<String>> columnsOf(FlaxDatabase db, String table) async => {
    for (final row
        in await db
            .customSelect("SELECT name FROM pragma_table_info('$table')")
            .get())
      row.read<String>('name'),
  };

  test('reopens a v3 database whose v4 upgrade stopped halfway', () async {
    // The state a killed upgrade leaves: albums got genres_json, songs did
    // not, and nothing past v3 was recorded.
    await createCurrentSchema([
      'ALTER TABLE songs DROP COLUMN genres_json',
      'ALTER TABLE albums DROP COLUMN release_types_json',
      'ALTER TABLE albums DROP COLUMN is_compilation',
      'PRAGMA user_version = 3',
    ]);

    final db = FlaxDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.select(db.albums).get();
    await db.select(db.songs).get();

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 5);
    expect(
      await columnsOf(db, 'albums'),
      containsAll(['genres_json', 'release_types_json', 'is_compilation']),
    );
    expect(await columnsOf(db, 'songs'), contains('genres_json'));
  });

  test('reruns every step over a schema that is already complete', () async {
    await createCurrentSchema(['PRAGMA user_version = 1']);

    final db = FlaxDatabase(NativeDatabase(file));
    await db.select(db.artists).get();
    await db.select(db.pendingScrobbles).get();
    await db.close();
  });
}
