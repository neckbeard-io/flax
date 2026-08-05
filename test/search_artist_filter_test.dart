import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// Which artists a search should list.
///
/// Real payload shapes, taken from what the server actually returned for the
/// query "liz": Lizzo with two albums, and ten credit participants with none —
/// songwriters and session performers whose names appear in track metadata but
/// who have no music of their own in the library.
void main() {
  const lizzo = {'id': '3bVawd2CLQ', 'name': 'Lizzo', 'albumCount': 2};
  const songwriter = {'id': '42KflKwbhi', 'name': 'Liz Rose', 'albumCount': 0};
  const legalName = {
    'id': '0XyBbfTPZZ',
    'name': 'Melissa “Lizzo” Jefferson',
    'albumCount': 0,
  };
  const noField = {'id': 'x', 'name': 'Some Artist'};

  test('keeps artists that have albums', () {
    expect(SubsonicClient.hasSearchableAlbums(lizzo), isTrue);
  });

  test('drops credit-only participants', () {
    // These are the entries that made a search for "liz" mostly noise.
    expect(SubsonicClient.hasSearchableAlbums(songwriter), isFalse);
    expect(SubsonicClient.hasSearchableAlbums(legalName), isFalse);
  });

  test('keeps an artist when the server omits albumCount', () {
    // Navidrome always sends it. A Subsonic server that does not would
    // otherwise have every artist filtered out of its search results, which is
    // far worse than showing a few extras.
    expect(SubsonicClient.hasSearchableAlbums(noField), isTrue);
  });
}
