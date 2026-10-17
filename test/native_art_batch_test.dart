import 'package:flutter_test/flutter_test.dart';

import 'package:flax/services/metadata/native_art_batch.dart';
import 'package:flax/services/platform/native_downloader.dart';

void main() {
  NativeDownloadEvent started(String id) =>
      NativeTaskStartedEvent(songId: id, serverId: 'srv', title: id);
  NativeDownloadEvent completed(String id) => NativeTaskCompletedEvent(
    songId: id,
    serverId: 'srv',
    localPath: '/tmp/$id.jpg',
    completedCount: 0,
    totalCount: 0,
  );
  NativeDownloadEvent failed(String id) => NativeTaskFailedEvent(
    songId: id,
    serverId: 'srv',
    error: 'HTTP 404',
    completedCount: 0,
    totalCount: 0,
  );
  const queueCompleted = NativeQueueCompletedEvent(
    totalCompleted: 1,
    totalBytes: 0,
  );

  test('the end of an earlier batch is not the end of this one', () {
    // An audio download's queue_completed, arriving just after the covers
    // were queued: the sync used to take it as its own and stop waiting.
    final batch = NativeArtBatch(['al-1', 'al-2'], length: 2);

    expect(batch.add(queueCompleted), isFalse);
  });

  test('finishes once every cover has been reported', () {
    final batch = NativeArtBatch(['al-1', 'al-2'], length: 2);

    expect(batch.add(started('al-1')), isFalse);
    expect(batch.add(completed('al-1')), isFalse);
    expect(batch.add(started('al-2')), isFalse);
    expect(batch.add(failed('al-2')), isTrue);
  });

  test('the queue ending after a cover started ends the batch', () {
    // A cover the downloader dropped without a word is still covered by the
    // whole queue draining.
    final batch = NativeArtBatch(['al-1', 'al-2'], length: 2);

    batch.add(started('al-1'));
    expect(batch.add(queueCompleted), isTrue);
  });

  test("another batch's downloads are not counted", () {
    final batch = NativeArtBatch(['al-1'], length: 1);

    expect(batch.add(started('song-9')), isFalse);
    expect(batch.add(completed('song-9')), isFalse);
    expect(batch.add(queueCompleted), isFalse);
    expect(batch.add(completed('al-1')), isTrue);
  });

  test('a cover queued twice is waited for twice', () {
    final batch = NativeArtBatch(['al-1'], length: 2);

    expect(batch.add(completed('al-1')), isFalse);
    expect(batch.add(completed('al-1')), isTrue);
  });
}
