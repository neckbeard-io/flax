import 'dart:io' as io;

import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the art cache keeps its files: a folder named after the cache in the
/// application support directory.
///
/// `flutter_cache_manager` puts files in the temporary directory unless told
/// otherwise, and every platform treats that as disposable. Android deletes
/// an app's cache folder down to its quota whenever storage is wanted
/// elsewhere, most Linux systems empty `/tmp` at boot, and Windows' Storage
/// Sense cleans `%TEMP%`. Covers stored for offline use went with it, so a
/// downloaded album lost its art. The support directory is the app's own data,
/// which the system leaves alone. The index of what is stored was always kept
/// there.
class ArtCacheFileSystem implements FileSystem {
  ArtCacheFileSystem(
    this.folderName, {
    Future<io.Directory> Function()? baseDirectory,
    Future<io.Directory> Function()? legacyBaseDirectory,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _legacyBaseDirectory = legacyBaseDirectory ?? getTemporaryDirectory;

  final String folderName;
  final Future<io.Directory> Function() _baseDirectory;
  final Future<io.Directory> Function() _legacyBaseDirectory;

  late final Future<Directory> _directory = _open();

  /// The folder the files are stored in, once covers from the old location
  /// have been moved into it.
  Future<io.Directory> get directory async =>
      io.Directory((await _directory).path);

  Future<Directory> _open() async {
    const fs = LocalFileSystem();
    final base = await _baseDirectory();
    final directory = fs.directory(p.join(base.path, folderName));
    try {
      final legacyBase = await _legacyBaseDirectory();
      await moveStoredFiles(
        from: io.Directory(p.join(legacyBase.path, folderName)),
        to: io.Directory(directory.path),
      );
    } catch (e) {
      AppLogger.w('ArtCache', 'Could not look for covers to move: $e');
    }
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await _directory;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.childFile(name);
  }

  /// Moves every file in [from] into [to] and removes [from].
  ///
  /// The cache's index refers to each file by name alone, so the entries stay
  /// valid wherever the folder lives. A file already in [to] wins over one of
  /// the same name in [from]. Renames when it can, which on Android is one
  /// operation for the whole folder; copies when [from] is on another file
  /// system, as `/tmp` often is on Linux. Never throws: a cover that cannot be
  /// moved is downloaded again next time.
  static Future<int> moveStoredFiles({
    required io.Directory from,
    required io.Directory to,
  }) async {
    if (!await from.exists()) return 0;
    var moved = 0;
    try {
      if (!await to.exists()) {
        await to.parent.create(recursive: true);
        try {
          await from.rename(to.path);
          moved = await to.list().length;
          AppLogger.i('ArtCache', 'Moved $moved covers to ${to.path}');
          return moved;
        } on io.FileSystemException {
          // Another file system: fall through and copy file by file.
        }
      }
      await to.create(recursive: true);
      await for (final entity in from.list()) {
        if (entity is! io.File) continue;
        final target = io.File(p.join(to.path, p.basename(entity.path)));
        try {
          if (await target.exists()) {
            await entity.delete();
            continue;
          }
          try {
            await entity.rename(target.path);
          } on io.FileSystemException {
            await entity.copy(target.path);
            await entity.delete();
          }
          moved++;
        } catch (e) {
          AppLogger.w('ArtCache', 'Could not move ${entity.path}: $e');
        }
      }
      await from.delete(recursive: true);
    } catch (e) {
      AppLogger.w('ArtCache', 'Could not move covers from ${from.path}: $e');
    }
    if (moved > 0) {
      AppLogger.i('ArtCache', 'Moved $moved covers to ${to.path}');
    }
    return moved;
  }
}
