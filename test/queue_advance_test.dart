import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/queue_advance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final queue = [
    for (final id in ['a', 'b', 'c', 'd', 'e'])
      Song(id: id, serverId: 's', title: id),
  ];
  // Offline: only these are downloaded.
  bool downloaded(Song song) => {'a', 'b', 'd'}.contains(song.id);

  test('goes to the next song when it can play', () {
    expect(nextPlayableIndex(queue, 1, downloaded), 1);
  });

  test('skips songs that cannot play offline', () {
    expect(nextPlayableIndex(queue, 2, downloaded), 3);
  });

  test('the queue has run out only when nothing after can play', () {
    expect(nextPlayableIndex(queue, 4, downloaded), isNull);
    expect(nextPlayableIndex(queue, 5, downloaded), isNull);
  });

  test('repeat-all carries on from the start of the queue', () {
    expect(nextPlayableIndex(queue, 4, downloaded, wrap: true), 0);
    expect(nextPlayableIndex(queue, 5, downloaded, wrap: true), 0);
  });

  test('repeat-all with nothing playable stops', () {
    expect(nextPlayableIndex(queue, 0, (_) => false, wrap: true), isNull);
  });
}
