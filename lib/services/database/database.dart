import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  ],
)
class FlaxDatabase extends _$FlaxDatabase {
  FlaxDatabase(super.e);

  /// In-memory, for tests. Needs no server, no mpv and no router.
  FlaxDatabase.memory() : super(NativeDatabase.memory());

  FlaxDatabase.open() : super(_openOnDisk());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Drift does not enable this by default, and without it the cascade on
      // playlist entries silently does nothing.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openOnDisk() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'flax_library.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
