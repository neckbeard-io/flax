import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// An in-memory stand-in for the cover-art store, keyed the way the real one
/// is: by whatever key each entry was written under.
class FakeCoverStore extends Fake implements BaseCacheManager {
  FakeCoverStore(this.dir);

  final Directory dir;
  final Map<String, File> files = {};
  final List<String> downloaded = [];

  File add(String key) {
    final name = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = const LocalFileSystem().file(p.join(dir.path, '$name.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    files[key] = file;
    return file;
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    final file = files[key];
    if (file == null) return null;
    return FileInfo(file, FileSource.Cache, DateTime(2100), key);
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    downloaded.add(key ?? url);
    final file = add(key ?? url);
    return FileInfo(file, FileSource.Online, DateTime(2100), url);
  }

  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async => add(key ?? url);

  @override
  Future<void> removeFile(String key) async {
    files.remove(key);
  }
}
