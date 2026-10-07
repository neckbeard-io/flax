import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flax/shared/widgets/art_cache.dart';
import 'package:flax/shared/widgets/art_cache_file_system.dart';

/// Covers stored for offline use lived in the temporary directory, which
/// Android empties to its quota whenever storage is wanted: a phone with a
/// synced library was left with a few hundred covers out of thousands.
void main() {
  late Directory root;
  late Directory support;
  late Directory temp;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flax_art_fs_');
    support = Directory(p.join(root.path, 'support'))..createSync();
    temp = Directory(p.join(root.path, 'temp'))..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  ArtCacheFileSystem store() => ArtCacheFileSystem(
    ArtCache.key,
    baseDirectory: () async => support,
    legacyBaseDirectory: () async => temp,
  );

  Directory oldFolder() =>
      Directory(p.join(temp.path, ArtCache.key))..createSync();

  List<String> names(Directory dir) =>
      dir.listSync().map((e) => p.basename(e.path)).toList()..sort();

  test('the art cache stores its files with its own file system', () {
    expect(ArtCache.config.fileSystem, same(ArtCache.fileSystem));
  });

  test('covers are written to the support directory', () async {
    final file = await store().createFile('1b2c.jpg');
    expect(file.path, p.join(support.path, ArtCache.key, '1b2c.jpg'));
  });

  test(
    'covers in the old temporary folder move, keeping their names',
    () async {
      final old = oldFolder();
      File(p.join(old.path, 'a.jpg')).writeAsBytesSync([1]);
      File(p.join(old.path, 'b.jpg')).writeAsBytesSync([2]);

      final dir = await store().directory;

      expect(names(dir), ['a.jpg', 'b.jpg']);
      expect(File(p.join(dir.path, 'b.jpg')).readAsBytesSync(), [2]);
      expect(old.existsSync(), isFalse);
    },
  );

  test('a cover already in the new folder wins over the old copy', () async {
    final old = oldFolder();
    File(p.join(old.path, 'same.jpg')).writeAsBytesSync([1]);
    File(p.join(old.path, 'only-old.jpg')).writeAsBytesSync([3]);
    final current = Directory(p.join(support.path, ArtCache.key))..createSync();
    File(p.join(current.path, 'same.jpg')).writeAsBytesSync([2]);

    final dir = await store().directory;

    expect(names(dir), ['only-old.jpg', 'same.jpg']);
    expect(File(p.join(dir.path, 'same.jpg')).readAsBytesSync(), [2]);
    expect(old.existsSync(), isFalse);
  });

  test('with nothing to move, the store starts empty', () async {
    final dir = await store().directory;
    expect(dir.existsSync(), isTrue);
    expect(dir.listSync(), isEmpty);
  });
}
