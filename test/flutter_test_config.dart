import 'dart:async';
import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Runs around every test file (flutter_test picks it up by name).
///
/// Gives each test process its own app directories. The desktop path_provider
/// implementations work without a plugin under test, so any test that opened
/// the library database used the machine's real support directory — one
/// SQLite file shared by every test file, and test files run in parallel
/// processes. Two of them writing it at once is the likely source of an
/// intermittent CI failure that no test was named for.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PathProviderPlatform.instance = _TestPaths(
    Directory.systemTemp.createTempSync('flax_test_').path,
  );
  await testMain();
}

class _TestPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TestPaths(this.root);

  final String root;

  String _dir(String name) =>
      (Directory('$root/$name')..createSync(recursive: true)).path;

  @override
  Future<String?> getTemporaryPath() async => _dir('tmp');

  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');

  @override
  Future<String?> getLibraryPath() async => _dir('library');

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('documents');

  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');

  @override
  Future<String?> getExternalStoragePath() async => _dir('external');

  @override
  Future<List<String>?> getExternalCachePaths() async => [
    _dir('external_cache'),
  ];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [_dir('external')];

  @override
  Future<String?> getDownloadsPath() async => _dir('downloads');
}
