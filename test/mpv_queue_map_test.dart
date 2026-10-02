import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/mpv_queue_map.dart';

/// mpv's playlist next to the queue when some songs could not be handed to
/// it — offline, not downloaded. mpv's indexes are then not queue indexes,
/// and treating them as if they were showed the wrong track after a gapless
/// advance.
void main() {
  List<Song> queueOf(int n) => [
    for (var i = 0; i < n; i++)
      Song(id: 's$i', serverId: 'srv', title: 'Song $i', duration: 200),
  ];

  // Five songs; only 0, 2 and 4 are downloaded.
  final queue = queueOf(5);
  final map = MpvQueueMap.of(queue, const [0, 2, 4]);

  test('an mpv index names the queue song it actually plays', () {
    expect(map.queueIndexAt(0), 0);
    expect(map.queueIndexAt(1), 2);
    expect(map.queueIndexAt(2), 4);
    expect(map.queueIndexAt(3), isNull);
  });

  test('a queue song mpv does not hold has no mpv slot', () {
    expect(map.mpvIndexOf(2), 1);
    expect(map.mpvIndexOf(1), isNull);
  });

  test('starting at an unplayable song starts at the next playable one', () {
    expect(map.startIndexFor(1), 1);
    expect(map.startIndexFor(4), 2);
    expect(map.startIndexFor(9), 2);
  });

  test('the last entry mpv holds is not the end of the queue', () {
    expect(map.isLastEntry(4), isTrue);
    expect(map.isLastEntry(2), isFalse);
    expect(MpvQueueMap.of(queue, const [0, 2]).isLastEntry(2), isTrue);
  });

  test('matches only the queue it was built for', () {
    expect(map.matches(queue), isTrue);
    expect(map.matches(queueOf(4)), isFalse);
    final swapped = [...queue]..[2] = queue[3];
    expect(map.matches(swapped), isFalse);
    expect(MpvQueueMap.empty.matches(queue), isFalse);
  });

  test('inserting into the queue moves later entries down', () {
    final inserted = [...queue]
      ..insertAll(1, [
        const Song(id: 'new', serverId: 'srv', title: 'New', duration: 1),
      ]);
    var shifted = map.shiftedForInsert(1, 1);
    expect(shifted.matches(inserted), isTrue);
    expect(shifted.queueIndexAt(1), 3);

    // The inserted song is playable: it goes into mpv between 0 and old 2.
    expect(shifted.slotFor(1), 1);
    shifted = shifted.withEntry(1, 'new');
    expect(shifted.matches(inserted), isTrue);
    expect(shifted.queueIndexAt(1), 1);
    expect(shifted.queueIndexAt(2), 3);
    expect(shifted.length, 4);
  });
}
