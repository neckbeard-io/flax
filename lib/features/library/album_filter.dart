import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/domain/enums.dart';

/// The Albums screen's tabs — one server-side view of the library each.
///
/// These replaced the Home screen: its Recently Added / Random / Most Played
/// shelves are three of the tabs below, so the same content is reachable
/// without a second top-level destination that only ever showed twenty albums
/// of each.
enum AlbumFilter {
  all('All', AlbumListType.alphabeticalByName),
  random('Random', AlbumListType.random),
  recentlyAdded('Recently Added', AlbumListType.newest),
  recentlyPlayed('Recently Played', AlbumListType.recent),
  mostPlayed('Most Played', AlbumListType.frequent),
  favorites('Favorites', AlbumListType.starred),
  // Ratings, not favorites. `highest` is the 0–5 userRating; `starred` above is
  // the boolean favorite flag. Keeping both tabs is only coherent because they
  // are genuinely different fields.
  topRated('Top Rated', AlbumListType.highest);

  const AlbumFilter(this.label, this.listType);

  /// Tab label, held next to the value so the two cannot drift apart.
  final String label;

  /// `getAlbumList2` type this tab asks the server for.
  final AlbumListType listType;

  /// Shown instead of an empty grid. Several of these are legitimately empty on
  /// a fresh library, where a bare white page reads as a failed request.
  String get emptyMessage => switch (this) {
        AlbumFilter.favorites => 'No favorite albums yet',
        AlbumFilter.topRated => 'No rated albums yet',
        AlbumFilter.recentlyPlayed => 'Nothing played yet',
        AlbumFilter.mostPlayed => 'Nothing played yet',
        _ => 'No albums',
      };

  static const AlbumFilter defaultFilter = AlbumFilter.all;
}

/// How many albums a tab asks for. 500 is the Subsonic ceiling on `size`.
const int albumFilterPageSize = 500;

/// The open tab.
///
/// Not `autoDispose`: opening an album and coming back has to land on the tab
/// you left, not reset to All.
final albumFilterProvider =
    StateProvider<AlbumFilter>((ref) => AlbumFilter.defaultFilter);
