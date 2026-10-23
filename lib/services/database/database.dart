import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flax/services/database/tables/audio_devices.dart';
import 'package:flax/services/database/tables/entities.dart';
import 'package:flax/services/database/tables/orderings.dart';

part 'database.g.dart';

/// The local metadata database. Issue #8.
///
/// The server owns the truth about the library; this is the **read path**. The
/// UI never queries the network directly — responses are written here, and
/// screens update because they are watching these tables. That is what makes
/// browsing work offline, and it is also why hearting an album in one screen
/// updates it in every other one without any invalidation code.
@DriftDatabase(
  tables: [
    Artists,
    Albums,
    Songs,
    Playlists,
    AlbumListEntries,
    PlaylistEntries,
    SyncStates,
    PendingScrobbles,
    AudioDevices,
    DeviceEqProfiles,
  ],
)
class FlaxDatabase extends _$FlaxDatabase {
  FlaxDatabase(super.e);

  /// In-memory, for tests. Needs no server, no mpv and no router.
  FlaxDatabase.memory() : super(NativeDatabase.memory());

  FlaxDatabase.open() : super(_openOnDisk());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    // Every step must be safe to run again. Drift runs these outside a
    // transaction and stores the new version only after all of them, so a
    // launch killed partway leaves columns added at the old version, and the
    // next launch repeats the step. A plain ALTER then fails on the duplicate
    // column, and the database never opens again.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(m, artists, artists.country);
        await _addColumnIfMissing(m, artists, artists.countryCode);
        await _addColumnIfMissing(m, artists, artists.activeYears);
      }
      if (from < 3) {
        // CREATE TABLE IF NOT EXISTS, so already safe to repeat.
        await m.createTable(pendingScrobbles);
      }
      if (from < 4) {
        // Columns only. Existing rows keep a null list, which is what the
        // genre backfill looks for; rewriting them here would touch every
        // song row on the first launch after the update.
        await _addColumnIfMissing(m, albums, albums.genresJson);
        await _addColumnIfMissing(m, songs, songs.genresJson);
      }
      if (from < 5) {
        // Columns only, as for v4: rows keep a null list, which the artist
        // refresh reads as unknown and fills in.
        await _addColumnIfMissing(m, albums, albums.releaseTypesJson);
        await _addColumnIfMissing(m, albums, albums.isCompilation);
      }
      if (from < 6) {
        // CREATE TABLE IF NOT EXISTS, as for v3. The generated index
        // statement has no IF NOT EXISTS, so it is written out here instead.
        await m.createTable(audioDevices);
        await m.createTable(deviceEqProfiles);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS device_eq_profile_device '
          'ON device_eq_profiles (device_id)',
        );
      }
    },
    beforeOpen: (details) async {
      // Drift does not enable this by default, and without it the cascade on
      // playlist entries silently does nothing.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final existing = await customSelect(
      'SELECT name FROM pragma_table_info(?)',
      variables: [Variable.withString(table.actualTableName)],
    ).get();
    if (existing.any((row) => row.read<String>('name') == column.name)) {
      return;
    }
    await m.addColumn(table, column);
  }
}

LazyDatabase _openOnDisk() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'flax_library.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
