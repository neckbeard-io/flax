import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the desktop artist page lays out a discography.
enum ArtistAlbumsView { grid, list }

final artistAlbumsViewProvider =
    StateNotifierProvider<ArtistAlbumsViewNotifier, ArtistAlbumsView>((ref) {
      return ArtistAlbumsViewNotifier();
    });

/// The chosen discography view, remembered across launches the way
/// [AlbumSortNotifier] remembers the order.
class ArtistAlbumsViewNotifier extends StateNotifier<ArtistAlbumsView> {
  static const storageKey = 'flax_artist_albums_view';

  ArtistAlbumsViewNotifier() : super(ArtistAlbumsView.grid) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved == null || !mounted) return;
      state = decodeArtistAlbumsView(saved);
    } catch (_) {
      // Unreadable prefs — keep the grid rather than failing to open.
    }
  }

  Future<void> setView(ArtistAlbumsView view) async {
    if (view == state) return;
    state = view;
    try {
      final prefs = await SharedPreferences.getInstance();
      // By name, never by index, for the reason AlbumSortNotifier gives.
      await prefs.setString(storageKey, view.name);
    } catch (_) {
      // Ignore write failures; the in-memory choice still applies this run.
    }
  }
}

/// Resolves a stored name, falling back to the grid for anything else.
ArtistAlbumsView decodeArtistAlbumsView(String name) => ArtistAlbumsView.values
    .firstWhere((v) => v.name == name, orElse: () => ArtistAlbumsView.grid);
