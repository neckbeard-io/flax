import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';

/// The local library database and the repository over it. Issue #8.

/// One database for the whole app, opened lazily on first use.
final flaxDatabaseProvider = Provider<FlaxDatabase>((ref) {
  final db = FlaxDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final libraryDaoProvider = Provider<LibraryDao>((ref) {
  return LibraryDao(ref.watch(flaxDatabaseProvider));
});

/// Null until a server is configured, matching [subsonicClientProvider].
///
/// Rebuilt when the active server changes, which swaps the `serverId` filter
/// rather than clearing anything — every table is keyed per server, so
/// switching back finds the previous server's cache intact.
final libraryRepositoryProvider = Provider<LibraryRepository?>((ref) {
  final server = ref.watch(activeServerProvider);
  final client = ref.watch(subsonicClientProvider);
  if (server == null || client == null) return null;

  return LibraryRepositoryImpl(
    ref.watch(libraryDaoProvider),
    client,
    server.id,
  );
});
