import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';

/// Everything a lyrics lookup needs, as a record so that the family key has
/// value equality. Keying on [Song] would not: it has no `==`, so rating or
/// starring the playing track would hand the family a fresh instance and
/// refetch lyrics that had not changed.
typedef LyricsQuery = ({String songId, String? artist, String? title});

/// Lyrics for one song, structured first and plain text as a fallback.
///
/// The structured call is the OpenSubsonic one and carries timing; the plain
/// `getLyrics` call is the old artist/title lookup and never does. Servers
/// that have only the latter still get an unsynced sheet out of this.
final songLyricsProvider =
    FutureProvider.family<Lyrics?, LyricsQuery>((ref, query) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return null;

  final structured = await client.getSongLyrics(query.songId);
  if (structured != null) return structured;

  if (query.artist == null && query.title == null) return null;
  try {
    final plain = await client.getLyrics(
      artist: query.artist,
      title: query.title,
    );
    return Lyrics.fromPlainText(plain);
  } catch (_) {
    return null;
  }
});

/// Lyrics for whatever is playing. Data (null) rather than a loading state
/// when nothing is, so the panel can say "nothing playing" instead of
/// spinning forever.
final currentLyricsProvider = Provider<AsyncValue<Lyrics?>>((ref) {
  final song = ref.watch(playerProvider.select((s) => s.currentSong));
  if (song == null) return const AsyncValue<Lyrics?>.data(null);
  return ref.watch(songLyricsProvider((
    songId: song.id,
    artist: song.artistName,
    title: song.title,
  )));
});

/// Index of the lyric line being sung right now, or -1 for none.
///
/// Split out from the panel so that the position stream — which ticks several
/// times a second — only rebuilds anything when the *line* changes.
final currentLyricLineProvider = Provider<int>((ref) {
  final lyrics = ref.watch(currentLyricsProvider).valueOrNull;
  if (lyrics == null || !lyrics.synced) return -1;
  final position = ref.watch(playerProvider.select((s) => s.position));
  return lyrics.lineIndexAt(position);
});
