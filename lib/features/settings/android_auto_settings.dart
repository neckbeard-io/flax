import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/l10n/app_localizations.dart';

/// A part of the library Android Auto can show as a tab across the top of its
/// large view (left). Declared in the order the tabs are shown.
enum AutoTab { recentlyAdded, artists, albums, playlists, favorites }

extension AutoTabLabel on AutoTab {
  /// The tab's name on the phone's settings page.
  String label(AppLocalizations? l10n) => switch (this) {
    AutoTab.recentlyAdded =>
      l10n?.androidAutoTabRecentlyAdded ?? 'Recently Added',
    AutoTab.artists => l10n?.navArtists ?? 'Artists',
    AutoTab.albums => l10n?.navAlbums ?? 'Albums',
    AutoTab.playlists => l10n?.navPlaylists ?? 'Playlists',
    AutoTab.favorites => l10n?.androidAutoTabFavorites ?? 'Favorites',
  };
}

/// Which tabs Android Auto shows. It shows at most four root items as tabs, and
/// drops the rest, so the choice is capped there rather than left to the car.
final androidAutoTabsProvider =
    StateNotifierProvider<AndroidAutoTabsNotifier, List<AutoTab>>(
      (ref) => AndroidAutoTabsNotifier(),
    );

class AndroidAutoTabsNotifier extends StateNotifier<List<AutoTab>> {
  static const storageKey = 'flax_android_auto_tabs';

  /// Android Auto shows no more root tabs than this.
  static const maxTabs = 4;

  /// What the car showed before the tabs could be chosen.
  static const defaultTabs = [
    AutoTab.recentlyAdded,
    AutoTab.artists,
    AutoTab.albums,
    AutoTab.playlists,
  ];

  AndroidAutoTabsNotifier() : super(defaultTabs) {
    _loading = _load();
  }

  late final Future<void> _loading;

  /// The choice, once the saved one has been read.
  ///
  /// [state] starts at the default, and the saved choice replaces it a moment
  /// later. Android Auto browses the root as soon as a headless start brings
  /// the handler up, so it waits for this rather than showing the default
  /// tabs first.
  Future<List<AutoTab>> get loaded async {
    await _loading;
    return state;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(storageKey);
      if (saved == null) return;
      final tabs = normalize(
        saved.map((name) => AutoTab.values.asNameMap()[name]).nonNulls,
      );
      // Every change makes a connected car reload its tabs, so a saved choice
      // that matches the default changes nothing.
      if (tabs.isEmpty || !mounted) return;
      if (!const ListEquality<AutoTab>().equals(tabs, state)) state = tabs;
    } catch (_) {
      // Keep the default on error.
    }
  }

  /// [tabs] in the order they are shown, each once, and no more than the car
  /// takes.
  static List<AutoTab> normalize(Iterable<AutoTab> tabs) {
    final chosen = tabs.toSet();
    return [
      for (final tab in AutoTab.values)
        if (chosen.contains(tab)) tab,
    ].take(maxTabs).toList();
  }

  /// Whether [tab] can be switched to [selected]: no fifth tab, and never none.
  bool canSet(AutoTab tab, bool selected) {
    if (state.contains(tab) == selected) return true;
    return selected ? state.length < maxTabs : state.length > 1;
  }

  Future<void> setSelected(AutoTab tab, bool selected) async {
    if (!canSet(tab, selected) || state.contains(tab) == selected) return;
    state = normalize(
      selected ? [...state, tab] : state.where((t) => t != tab),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, [for (final t in state) t.name]);
    } catch (_) {
      // Ignore write failures
    }
  }
}
