/// Genre names, as the server tags albums and tracks with them.
///
/// Navidrome sends every genre in the OpenSubsonic `genres` array and the first
/// of them again as the plain Subsonic `genre`. These helpers are the one place
/// that decides what counts as the same genre, so the album page, the genre
/// page and the offline filters cannot disagree about it.
library;

/// [names] trimmed, without blanks, and without repeats that differ only in
/// case. The first spelling and the server's order win.
List<String> normalizeGenres(Iterable<String> names) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in names) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) result.add(name);
  }
  return result;
}

/// The plain Subsonic `genre` as a list: empty when there is none.
///
/// Not split on separators. A server that packs several genres into one string
/// does so in its own format, and guessing at it would turn "Rock & Roll" into
/// two genres.
List<String> genresFromSingle(String? genre) =>
    genre == null ? const [] : normalizeGenres([genre]);

/// Whether [genres] includes [name], ignoring case.
bool hasGenre(Iterable<String> genres, String name) {
  final wanted = name.trim().toLowerCase();
  return genres.any((g) => g.trim().toLowerCase() == wanted);
}

/// Whether [a] and [b] name the same genres, ignoring order and case.
bool sameGenres(Iterable<String> a, Iterable<String> b) {
  final left = {for (final g in a) g.trim().toLowerCase()};
  final right = {for (final g in b) g.trim().toLowerCase()};
  return left.length == right.length && left.containsAll(right);
}
