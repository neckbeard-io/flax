import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';

/// Shortest query worth asking the server about. One letter matches most of a
/// library and tells the user nothing.
const int kQuickSearchMinChars = 2;

/// How many of each kind the popup shows.
///
/// The server returns them in relevance order, so this is a "top N" rather
/// than an arbitrary truncation — and the point of the popup is the first
/// couple of hits, not completeness. Everything else is what the search screen
/// is for.
const int kQuickSearchLimit = 5;

/// How long typing has to pause before a query is sent.
const Duration kQuickSearchDebounce = Duration(milliseconds: 250);

/// What the "/" popup shows: artists and albums only.
///
/// Songs are deliberately absent. A library has far more songs than albums, so
/// including them buries the album you were reaching for under ten tracks that
/// happen to share a word with it.
class QuickSearchResults {
  final List<Artist> artists;
  final List<Album> albums;

  const QuickSearchResults({this.artists = const [], this.albums = const []});

  static const empty = QuickSearchResults();

  bool get isEmpty => artists.isEmpty && albums.isEmpty;
  int get length => artists.length + albums.length;
}

/// The query the popup is actually searching for, which lags what is in the
/// field by [kQuickSearchDebounce].
///
/// Separate from the search screen's [searchQueryProvider] on purpose: typing
/// in the sidebar used to drive the screen and navigate to it, so a quick look
/// for an album threw away whatever you were doing. The two searches now share
/// nothing but the server call.
final quickSearchProvider =
    StateNotifierProvider<QuickSearchController, String>((ref) {
      return QuickSearchController();
    });

class QuickSearchController extends StateNotifier<String> {
  QuickSearchController() : super('');

  Timer? _debounce;

  /// Called on every keystroke. Only the last one in a burst is searched for —
  /// otherwise typing "testament" is nine round trips, eight of them stale
  /// before they return.
  void setQuery(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    // Clearing is immediate. Waiting a quarter second to hide results the user
    // has just deleted the query for looks broken.
    if (trimmed.length < kQuickSearchMinChars) {
      state = '';
      return;
    }

    _debounce = Timer(kQuickSearchDebounce, () {
      if (mounted) state = trimmed;
    });
  }

  /// Drops the query and any pending search.
  void clear() {
    _debounce?.cancel();
    state = '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Quick search results: whatever is cached, immediately, then widened by the
/// server. Issue #8.
///
/// Emitting twice is the point. The local query is instant and is the only
/// answer available with no network; the server reaches things that have never
/// been browsed. If the server call fails the local hits simply stand, which is
/// what makes searching offline work rather than error.
final quickSearchResultsProvider =
    StreamProvider.autoDispose<QuickSearchResults>((ref) async* {
      final query = ref.watch(quickSearchProvider);
      if (query.length < kQuickSearchMinChars) {
        yield QuickSearchResults.empty;
        return;
      }

      final repo = ref.watch(libraryRepositoryProvider);
      if (repo == null) {
        yield QuickSearchResults.empty;
        return;
      }

      Future<QuickSearchResults> local() async => QuickSearchResults(
        artists: await repo
            .watchArtistSearch(query, limit: kQuickSearchLimit)
            .first,
        albums: await repo
            .watchAlbumSearch(query, limit: kQuickSearchLimit)
            .first,
      );

      yield await local();

      try {
        await repo.cacheSearch(
          query,
          artistCount: kQuickSearchLimit,
          albumCount: kQuickSearchLimit,
          songCount: 0,
        );
      } catch (_) {
        return;
      }

      yield await local();
    });
