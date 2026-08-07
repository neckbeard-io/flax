import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/domain/models/models.dart';

/// How an artist's albums are ordered.
enum AlbumSortMode {
  yearAsc('Year (oldest first)'),
  yearDesc('Year (newest first)'),
  title('Title'),
  rating('Rating');

  const AlbumSortMode(this.label);

  /// Menu label, kept next to the value so the two cannot drift apart.
  final String label;

  static const AlbumSortMode defaultMode = AlbumSortMode.yearAsc;
}

/// Orders [albums] by [mode], leaving the input untouched.
///
/// Albums with no year sort to the end when ascending and to the start when
/// descending, so an unknown year never displaces a known one.
List<Album> sortAlbums(List<Album> albums, AlbumSortMode mode) {
  final sorted = List<Album>.from(albums);
  switch (mode) {
    case AlbumSortMode.yearAsc:
      sorted.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
    case AlbumSortMode.yearDesc:
      sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    case AlbumSortMode.title:
      sorted.sort((a, b) => a.name.compareTo(b.name));
    case AlbumSortMode.rating:
      sorted.sort((a, b) => (b.userRating ?? 0).compareTo(a.userRating ?? 0));
  }
  return sorted;
}

final albumSortProvider =
    StateNotifierProvider<AlbumSortNotifier, AlbumSortMode>((ref) {
  return AlbumSortNotifier();
});

/// The chosen album order, remembered across launches.
///
/// Not `autoDispose`: the choice has to survive leaving an artist page and
/// coming back, not just the frame that set it.
class AlbumSortNotifier extends StateNotifier<AlbumSortMode> {
  static const storageKey = 'flax_album_sort';

  AlbumSortNotifier() : super(AlbumSortMode.defaultMode) {
    _load();
  }

  /// Reads the saved order. Async, so the first frame draws the default and is
  /// replaced once prefs arrive — the same tradeoff the other persisted
  /// settings make, and invisible at the speed prefs actually load.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved == null) return;
      state = decodeSortMode(saved);
    } catch (_) {
      // Unreadable prefs — keep the default rather than failing to open.
    }
  }

  Future<void> setMode(AlbumSortMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Stored by name, never by index: persisting the ordinal would silently
      // remap every saved preference the moment a value is added to the enum
      // or the list is reordered.
      await prefs.setString(storageKey, mode.name);
    } catch (_) {
      // Ignore write failures; the in-memory choice still applies this run.
    }
  }
}

/// Resolves a stored name back to a mode, falling back to the default for
/// anything unrecognized — an older build's value, or a corrupt string.
AlbumSortMode decodeSortMode(String name) => AlbumSortMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => AlbumSortMode.defaultMode,
    );
