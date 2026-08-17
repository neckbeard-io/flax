import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artist_detail_screen.dart';

const _artistId = 'art-1';

final _artist = Artist(
  id: _artistId,
  serverId: 'srv',
  name: '3 Inches of Blood',
  albumCount: 2,
  starred: false,
  userRating: 0,
);

final _albums = [
  Album(
    id: 'a1',
    serverId: 'srv',
    name: 'Battlecry Under a Winter Sun',
    artistId: _artistId,
    songCount: 11,
    duration: 2400,
    year: 2002,
  ),
  Album(
    id: 'a2',
    serverId: 'srv',
    name: 'Advance and Vanquish',
    artistId: _artistId,
    songCount: 13,
    duration: 2600,
    year: 2004,
  ),
];

final _mbInfo = MusicBrainzArtistInfo(
  country: 'Victoria',
  countryCode: 'CA',
  beginDate: '1999',
  tags: const ['power metal'],
);

/// Long enough to be visible in the layout, mirroring a real Last.fm bio.
const _bio =
    'A Canadian heavy metal band from Victoria, British Columbia, '
    'formed in 2000. The group initially started as a solo project before '
    'expanding, and went on to sign with Roadrunner Records in 2004, '
    'releasing several albums over the following decade.';

Widget _harness({
  required Future<ArtistInfo?> info,
  required Future<MusicBrainzArtistInfo?> mb,
  Size size = const Size(1400, 1000),
}) {
  return ProviderScope(
    overrides: [
      artistDetailProvider(
        _artistId,
      ).overrideWith((ref) => Stream.value(_artist)),
      artistAlbumsProvider(
        _artistId,
      ).overrideWith((ref) => Stream.value(_albums)),
      artistInfoProvider(_artistId).overrideWith((ref) => info),
      musicBrainzInfoProvider(_artistId).overrideWith((ref) => mb),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const ArtistDetailScreen(artistId: _artistId),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop header shows the artist contained, not as a banner', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        info: Future.value(const ArtistInfo(biography: _bio)),
        mb: Future.value(_mbInfo),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('3 Inches of Blood'), findsOneWidget);
    expect(find.text('2 albums'), findsOneWidget);

    // The image is a bounded square, not a full-width crop. A banner was the
    // whole problem: it cropped a square publicity photo to a strip and put
    // controls over arbitrary artwork.
    final image = tester.getSize(find.byType(SizedBox).at(0));
    expect(find.text('Canada'), findsOneWidget, reason: 'country chip renders');
    expect(
      image.width,
      lessThan(1400),
      reason: 'header art must not span the window',
    );
  });

  testWidgets('album list does not move when the bio arrives', (tester) async {
    tester.view.physicalSize = const ui.Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Both third-party lookups are still in flight, which is the state a real
    // user sees for the first second or two on an artist page.
    final infoCompleter = Completer<ArtistInfo?>();
    final mbCompleter = Completer<MusicBrainzArtistInfo?>();

    await tester.pumpWidget(
      _harness(info: infoCompleter.future, mb: mbCompleter.future),
    );
    await tester.pumpAndSettle();

    final before = tester
        .getTopLeft(find.text('Battlecry Under a Winter Sun'))
        .dy;

    // Metadata lands.
    infoCompleter.complete(const ArtistInfo(biography: _bio));
    mbCompleter.complete(_mbInfo);
    await tester.pumpAndSettle();

    final after = tester
        .getTopLeft(find.text('Battlecry Under a Winter Sun'))
        .dy;

    // The regression this guards: the bio and chips collapsed to nothing while
    // loading, then pushed the album list down when they arrived — moving a row
    // out from under the pointer mid-click.
    expect(
      after,
      closeTo(before, 1.0),
      reason: 'album list shifted by ${after - before}px when info loaded',
    );
  });
}
