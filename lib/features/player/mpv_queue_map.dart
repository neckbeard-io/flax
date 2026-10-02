import 'package:flax/domain/models/models.dart';

/// Which entries of the play queue mpv's playlist holds, and in which slots.
///
/// Songs that cannot be played right now — not downloaded, while offline — are
/// left out of mpv's playlist, so an mpv index is not a queue index. The two
/// used to be treated as the same thing, and with a gap in the playlist a
/// gapless advance, a skip or a resume could land on, show and save the wrong
/// track.
class MpvQueueMap {
  const MpvQueueMap._(this._ids, this._positions, this._queueLength);

  /// mpv holds nothing that corresponds to any queue.
  static const empty = MpvQueueMap._([], [], -1);

  /// The map for [queue] when the songs at [positions] (ascending queue
  /// indexes) were handed to mpv, in that order.
  factory MpvQueueMap.of(List<Song> queue, List<int> positions) =>
      MpvQueueMap._(
        List.unmodifiable([for (final p in positions) queue[p].id]),
        List.unmodifiable(positions),
        queue.length,
      );

  final List<String> _ids;
  final List<int> _positions;
  final int _queueLength;

  /// How many entries mpv holds.
  int get length => _positions.length;

  /// Whether [queue] is still the queue this map describes: same length, and
  /// every slot still names the song it was built with.
  bool matches(List<Song> queue) {
    if (queue.length != _queueLength) return false;
    if (_positions.isEmpty) return queue.isEmpty;
    for (var i = 0; i < _positions.length; i++) {
      final position = _positions[i];
      if (position >= queue.length || queue[position].id != _ids[i]) {
        return false;
      }
    }
    return true;
  }

  /// The queue index mpv's entry [mpvIndex] plays, or null.
  int? queueIndexAt(int mpvIndex) =>
      mpvIndex >= 0 && mpvIndex < _positions.length
      ? _positions[mpvIndex]
      : null;

  /// mpv's entry for queue index [queueIndex], or null when mpv does not hold
  /// that song.
  int? mpvIndexOf(int queueIndex) {
    final i = _positions.indexOf(queueIndex);
    return i < 0 ? null : i;
  }

  /// Where to start mpv for queue index [queueIndex]: its own entry, else the
  /// next one mpv holds, else the last.
  int startIndexFor(int queueIndex) {
    for (var i = 0; i < _positions.length; i++) {
      if (_positions[i] >= queueIndex) return i;
    }
    return _positions.isEmpty ? 0 : _positions.length - 1;
  }

  /// Whether queue index [queueIndex] is the final entry mpv holds, after
  /// which mpv has nothing to advance to by itself.
  bool isLastEntry(int queueIndex) =>
      _positions.isNotEmpty && _positions.last == queueIndex;

  /// This map after [count] songs were inserted into the queue at [at], before
  /// any of them is handed to mpv: later entries move down.
  MpvQueueMap shiftedForInsert(int at, int count) => MpvQueueMap._(
    _ids,
    List.unmodifiable([for (final p in _positions) p >= at ? p + count : p]),
    _queueLength + count,
  );

  /// The mpv slot a song at queue index [queueIndex] belongs in.
  int slotFor(int queueIndex) => _positions.where((p) => p < queueIndex).length;

  /// This map with the song [id] at queue index [queueIndex] added to mpv at
  /// [slotFor] that index.
  MpvQueueMap withEntry(int queueIndex, String id) {
    final slot = slotFor(queueIndex);
    return MpvQueueMap._(
      List.unmodifiable([..._ids]..insert(slot, id)),
      List.unmodifiable([..._positions]..insert(slot, queueIndex)),
      _queueLength,
    );
  }
}
