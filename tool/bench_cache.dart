import 'dart:io';
import 'package:flax/shared/widgets/art_cache.dart';

void main() async {
  final cache = ArtCache.instance;
  final sw = Stopwatch()..start();
  print('Checking cache stats...');
  // Let's see how long 4500 calls to getFileFromCache take
  final futures = <Future<dynamic>>[];
  for (var i = 0; i < 4500; i++) {
    futures.add(cache.getFileFromCache('cover-fake-$i-orig'));
  }
  await Future.wait(futures);
  print('4500 cache lookups took: ${sw.elapsedMilliseconds}ms');
}
