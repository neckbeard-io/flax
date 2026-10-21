import 'package:flax/services/platform/native_downloader.dart';

/// The covers one metadata sync hands to Android's downloader, and when they
/// are all accounted for.
///
/// The downloader is one queue, shared with audio downloads, and it reports
/// `queue_completed` for the queue rather than for a batch. One posted as an
/// earlier batch drained can reach a sync that has only just queued its
/// covers. Taken as the end of them, the sync went on to the biographies and
/// recorded itself finished while the covers were still downloading; they
/// arrived after nothing was listening, were never filed, and the next sync
/// fetched them all again (#180). So the queue's end only counts once one of
/// this batch's covers has started, which puts the batch in the queue being
/// reported on.
class NativeArtBatch {
  /// [ids] are the tasks' `songId`s; [length] is how many tasks were queued,
  /// which counts a cover queued twice twice, as the downloader reports it.
  NativeArtBatch(Iterable<String> ids, {required this.length})
    : _ids = ids.toSet();

  final Set<String> _ids;
  final int length;

  int _reported = 0;
  bool _started = false;

  /// Whether [songId] is one of this batch's covers.
  bool owns(String songId) => _ids.contains(songId);

  /// Records [event], and returns whether the batch is finished.
  ///
  /// A cancel is not handled here: it ends the whole sync, not just the batch.
  bool add(NativeDownloadEvent event) {
    switch (event) {
      case NativeTaskStartedEvent(:final songId):
        if (owns(songId)) _started = true;
      case NativeTaskCompletedEvent(:final songId) ||
          NativeTaskFailedEvent(:final songId):
        if (owns(songId)) {
          _started = true;
          _reported++;
        }
      case NativeQueueCompletedEvent():
        return _started;
      default:
        break;
    }
    return _reported >= length;
  }
}
