import 'dart:io';

import 'package:flax/shared/widgets/cover_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_cache_info_repository.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cover_index'));
  tearDown(() => dir.deleteSync(recursive: true));

  void writeFile(String name, int bytes) =>
      File(p.join(dir.path, name)).writeAsBytesSync(List.filled(bytes, 0));

  const keys = [
    'cover-a-512',
    'cover-b-512',
    'cover-gone-512',
    'cover-new-512',
  ];

  late FakeCacheInfoRepository repo;

  setUp(() {
    writeFile('a.jpg', 100);
    writeFile('b.jpg', 7);
    repo = FakeCacheInfoRepository([
      coverRow('cover-a-512', 'a.jpg', length: 100),
      // Filed with putFile, as Android's downloader does: no length recorded.
      coverRow('cover-b-512', 'b.jpg'),
      // The row outlived its file, deleted behind the store's back.
      coverRow('cover-gone-512', 'gone.jpg', length: 50),
    ]);
  });

  test('counts stored covers and their bytes', () async {
    final index = await CoverIndex.read(repo: repo, directory: dir);

    expect(await index.measure(keys), (count: 2, bytes: 107));
  });

  test('lists covers with no row, or a row whose file is gone', () async {
    final index = await CoverIndex.read(repo: repo, directory: dir);

    expect(index.missing(keys, (key) => key), [
      'cover-gone-512',
      'cover-new-512',
    ]);
  });

  test('a cover stored at another size is missing at this one', () async {
    final index = await CoverIndex.read(repo: repo, directory: dir);

    expect(index.missing(['cover-a-128'], (key) => key), ['cover-a-128']);
    expect(await index.measure(['cover-a-128']), (count: 0, bytes: 0));
  });

  test('closes the index it opened', () async {
    await CoverIndex.read(repo: repo, directory: dir);

    expect(repo.openConnections, 0);
  });

  test('with no folder yet, every cover is missing', () async {
    dir.deleteSync(recursive: true);
    final index = await CoverIndex.read(repo: repo, directory: dir);
    dir.createSync();

    expect(index.missing(keys, (key) => key), keys);
    expect(await index.measure(keys), (count: 0, bytes: 0));
  });
}
