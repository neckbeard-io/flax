import 'package:flax/domain/models/album.dart';

/// The headings an artist's discography is split under, in page order.
enum ReleaseGroup { albums, epsAndSingles, live, compilations, other }

/// Secondary types, and the rarer primary ones, that set a release apart from
/// the artist's albums without having a heading of their own.
const _otherTypes = {
  'soundtrack',
  'spokenword',
  'interview',
  'audiobook',
  'audio drama',
  'remix',
  'dj-mix',
  'mixtape/street',
  'demo',
  'field recording',
  'broadcast',
  'other',
};

/// Which heading [album] belongs under, from its OpenSubsonic release types.
///
/// The first rule that matches wins, because one release often carries
/// several types: Boris's Archive II is `album`, `compilation`, `demo` and
/// `live` at once. The types arrive alphabetized, so the first one is not the
/// primary type and is never read as it. Anything unknown, untagged or
/// unrecognized is an album, which is what most of a library is.
ReleaseGroup releaseGroupOf(Album album) {
  final types = {
    for (final type in album.releaseTypes ?? const <String>[])
      type.trim().toLowerCase(),
  };
  if (types.contains('live')) return ReleaseGroup.live;
  if (types.contains('compilation') || album.isCompilation == true) {
    return ReleaseGroup.compilations;
  }
  if (types.any(_otherTypes.contains)) return ReleaseGroup.other;
  if (types.contains('ep') || types.contains('single')) {
    return ReleaseGroup.epsAndSingles;
  }
  return ReleaseGroup.albums;
}

/// [albums] split by [releaseGroupOf], in [ReleaseGroup] order, keeping each
/// album's position from [albums] within its group. Empty groups are left out.
List<(ReleaseGroup, List<Album>)> groupReleases(List<Album> albums) {
  final byGroup = <ReleaseGroup, List<Album>>{};
  for (final album in albums) {
    byGroup.putIfAbsent(releaseGroupOf(album), () => []).add(album);
  }
  return [
    for (final group in ReleaseGroup.values)
      if (byGroup[group] case final list?) (group, list),
  ];
}
