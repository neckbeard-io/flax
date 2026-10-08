import 'package:flax/domain/models/models.dart';

/// The first song in [queue] from [from] onward that [canPlay] allows, or
/// null when none is left. With [wrap], the search carries on from the start
/// of the queue, as repeat-all does.
int? nextPlayableIndex(
  List<Song> queue,
  int from,
  bool Function(Song song) canPlay, {
  bool wrap = false,
}) {
  for (var i = from; i < queue.length; i++) {
    if (canPlay(queue[i])) return i;
  }
  if (wrap) {
    for (var i = 0; i < from && i < queue.length; i++) {
      if (canPlay(queue[i])) return i;
    }
  }
  return null;
}
