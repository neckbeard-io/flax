import 'package:flax/domain/models/song.dart';

class PlayQueue {
  final List<Song> songs;
  final String? currentId;
  final int positionMs;

  const PlayQueue({
    required this.songs,
    this.currentId,
    this.positionMs = 0,
  });

  int get currentIndex {
    if (currentId == null) return 0;
    final idx = songs.indexWhere((s) => s.id == currentId);
    return idx >= 0 ? idx : 0;
  }
}
