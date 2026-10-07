import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;

import 'package:flax/shared/widgets/art_cache.dart';

/// Every cover the art store holds, read in one pass.
///
/// `getFileFromCache` is how to look up one cover, not thousands. On a fresh
/// process each call reads the cover's row from the store's index, checks its
/// file exists and writes the row's `touched` time back. Cache Status and the
/// sync's missing-art check made one call per album and artist, about 5,800
/// on a 4,549-album library, and each took 20 seconds on a Pixel emulator
/// before anything showed. This reads the index once and lists the folder
/// once, and writes nothing.
///
/// A row whose file is gone counts as missing, as `getFileFromCache` would
/// count it.
class CoverIndex {
  CoverIndex._(this._stored);

  /// Cache key to its file and the length the index recorded, for rows whose
  /// file is on disk.
  final Map<String, ({File file, int? length})> _stored;

  /// Reads [repo] and lists [directory], the folder its files live in.
  static Future<CoverIndex> read({
    required CacheInfoRepository repo,
    required Directory directory,
  }) async {
    // The index before the folder: a cover is written to disk before its row,
    // so every row read here already has its file.
    await repo.open();
    final List<CacheObject> objects;
    try {
      objects = await repo.getAllObjects();
    } finally {
      await repo.close();
    }
    final onDisk = <String>{};
    if (await directory.exists()) {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          onDisk.add(p.relative(entity.path, from: directory.path));
        }
      }
    }
    return CoverIndex._({
      for (final object in objects)
        if (onDisk.contains(p.normalize(object.relativePath)))
          object.key: (
            file: File(p.join(directory.path, object.relativePath)),
            length: object.length,
          ),
    });
  }

  /// [read] against the art store on this device.
  static Future<CoverIndex> readArtCache() async {
    // Created first so the store holds the index open, and closing this read's
    // connection never closes the database under it.
    ArtCache.instance;
    return read(
      repo: ArtCache.config.repo,
      directory: await ArtCache.fileSystem.directory,
    );
  }

  /// The [items] whose cover, under [keyOf], is not stored.
  List<T> missing<T>(Iterable<T> items, String Function(T item) keyOf) => [
    for (final item in items)
      if (!_stored.containsKey(keyOf(item))) item,
  ];

  /// How many of [keys] are stored, and their size in bytes.
  ///
  /// The index has no length for covers stored with `putFile`, which is how
  /// Android's downloader and the nightly sync file them, so those files are
  /// measured on disk.
  Future<({int count, int bytes})> measure(Iterable<String> keys) async {
    var count = 0;
    var bytes = 0;
    final unmeasured = <File>[];
    for (final key in keys) {
      final stored = _stored[key];
      if (stored == null) continue;
      count++;
      final length = stored.length;
      if (length != null) {
        bytes += length;
      } else {
        unmeasured.add(stored.file);
      }
    }
    final lengths = await Future.wait(
      unmeasured.map((file) => file.length().catchError((_) => 0)),
    );
    for (final length in lengths) {
      bytes += length;
    }
    return (count: count, bytes: bytes);
  }
}
