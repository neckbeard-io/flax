import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cover store's index held in memory. It can only be opened, read and
/// closed: any write throws, so a test using it also shows nothing was
/// written back.
class FakeCacheInfoRepository extends Fake implements CacheInfoRepository {
  FakeCacheInfoRepository([List<CacheObject>? objects])
    : objects = objects ?? [];

  final List<CacheObject> objects;

  /// Opens not yet matched by a close.
  int openConnections = 0;

  @override
  Future<bool> open() async {
    openConnections++;
    return true;
  }

  @override
  Future<List<CacheObject>> getAllObjects() async => List.of(objects);

  @override
  Future<bool> close() async {
    openConnections--;
    return openConnections == 0;
  }
}

/// An index row for [key], stored in the file [relativePath].
CacheObject coverRow(String key, String relativePath, {int? length}) =>
    CacheObject(
      key,
      key: key,
      relativePath: relativePath,
      validTill: DateTime(2100),
      length: length,
    );
