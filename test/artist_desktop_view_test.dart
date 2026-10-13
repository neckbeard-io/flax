import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/artist_albums_view.dart';
import 'package:flax/features/library/artist_desktop_view.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/album_grid_tile.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/star_rating.dart';

/// The desktop artist page: rail, discography groups, and nothing moving when
/// the slow lookups land. #87.
const _id = 'ar1';

const _artist = Artist(
  id: _id,
  serverId: 'srv',
  name: 'Porcupine Tree',
  albumCount: 13,
);

Album _album(String id, {List<String>? types, int year = 2000}) => Album(
  id: id,
  serverId: 'srv',
  artistId: _id,
  name: 'Album $id',
  year: year,
  songCount: 10,
  duration: 3000,
  releaseTypes: types ?? const ['album'],
  genres: const ['Progressive Rock'],
);

/// Eleven albums and two live ones: two groups, so headings show.
final _albums = [
  for (var i = 0; i < 11; i++) _album('al$i', year: 1990 + i),
  _album('live1', types: ['album', 'live']),
  _album('live2', types: ['album', 'live']),
];

final _topSongs = [
  for (var i = 0; i < 10; i++)
    Song(
      id: 's$i',
      serverId: 'srv',
      title: 'Song $i',
      albumId: 'al0',
      albumName: 'Album al0',
      duration: 240,
    ),
];

const _info = ArtistInfo(
  biography:
      'Started in 1987 by Steven Wilson as a tongue-in-cheek homage to his '
      'boyhood heroes Pink Floyd, Porcupine Tree gradually developed its own '
      'character and eventually eclipsed Wilson\'s main band of the time. '
      'Wilson launched the band in Hertfordshire, England, and invented a '
      'suitably bizarre back story for it.',
  similarArtists: [
    SimilarArtist(id: 'x1', name: 'Steven Wilson', albumCount: 9),
    SimilarArtist(id: 'x2', name: 'Riverside', albumCount: 3),
  ],
);

class _Repo implements LibraryRepository {
  final ratings = <(EntityType, String, int)>[];
  final favorites = <(EntityType, String, bool)>[];

  @override
  Future<void> setRating(EntityRef ref, {required int rating}) async =>
      ratings.add((ref.type, ref.id, rating));

  @override
  Future<void> setFavorite(EntityRef ref, {required bool favorite}) async =>
      favorites.add((ref.type, ref.id, favorite));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  List<Album>? albums,
  String name = 'Porcupine Tree',
  Future<ArtistInfo?>? info,
  Future<MusicBrainzArtistInfo?>? mb,
  Future<List<Song>>? top,
  bool offline = false,
  Locale? locale,
  LibraryRepository? repo,
}) async {
  tester.view.physicalSize = ui.Size(size.width, size.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Stream<Set<String>> none(Ref ref) => Stream.value(const <String>{});
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        artistDetailProvider(_id).overrideWith(
          (ref) => Stream.value(
            Artist(
              id: _id,
              serverId: 'srv',
              name: name,
              albumCount: _artist.albumCount,
            ),
          ),
        ),
        artistAlbumsProvider(
          _id,
        ).overrideWith((ref) => Stream.value(albums ?? _albums)),
        artistInfoProvider(
          _id,
        ).overrideWith((ref) => info ?? Future.value(_info)),
        musicBrainzInfoProvider(
          _id,
        ).overrideWith((ref) => mb ?? Future.value(null)),
        artistTopSongsProvider(
          _id,
        ).overrideWith((ref) => top ?? Future.value(_topSongs)),
        isOfflineModeProvider.overrideWithValue(offline),
        downloadedAlbumIdsProvider.overrideWith(none),
        anyDownloadedAlbumIdsProvider.overrideWith(none),
        downloadedArtistIdsProvider.overrideWith(none),
        anyDownloadedArtistIdsProvider.overrideWith(none),
        if (repo != null) libraryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const ArtistDetailScreen(artistId: _id),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _rail => find.byKey(ArtistDesktopView.railKey);
Finder get _popular => find.byKey(ArtistDesktopView.popularKey);
Finder get _similar => find.byKey(ArtistDesktopView.similarKey);
Finder get _tiles => find.byType(AlbumGridTile);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The reference setup is a 1440px window: a portrait 1440p monitor at 1x.
  // These tests have no sidebar, so its 1220px content area is the view.
  testWidgets('the reference window gets the rail and four columns', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1220, 1280));

    expect(tester.takeException(), isNull);
    expect(_rail, findsOneWidget);
    expect(tester.getSize(_rail).width, kArtistRailWidth);
    expect(
      find.descendant(of: _rail, matching: _popular),
      findsOneWidget,
      reason: 'Popular sits in the rail',
    );
    expect(find.descendant(of: _rail, matching: _similar), findsOneWidget);

    final rowTop = tester.getTopLeft(_tiles.at(0)).dy;
    for (var i = 1; i < 4; i++) {
      expect(tester.getTopLeft(_tiles.at(i)).dy, rowTop);
    }
    expect(tester.getTopLeft(_tiles.at(4)).dy, greaterThan(rowTop));

    final art = tester.getSize(
      find.descendant(of: _tiles.first, matching: find.byType(CoverArtImage)),
    );
    expect(art.width, closeTo(art.height, 0.5), reason: 'art stays square');
  });

  testWidgets('the rail starts at 1100 of content width', (tester) async {
    await _pump(tester, size: const Size(1100, 1000));
    expect(_rail, findsOneWidget);

    await _pump(tester, size: const Size(1099, 1000));
    expect(_rail, findsNothing);
  });

  testWidgets('a narrower window puts Popular first and similar last', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1000, 3200));

    expect(tester.takeException(), isNull);
    expect(_rail, findsNothing);
    final discography = tester.getTopLeft(find.text('Discography')).dy;
    expect(tester.getTopLeft(_popular).dy, lessThan(discography));
    expect(
      tester.getTopLeft(_similar).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(_tiles.last).dy),
    );
    // Two columns of five.
    expect(
      tester.getTopLeft(find.text('Song 5')).dy,
      tester.getTopLeft(find.text('Song 0')).dy,
    );
  });

  testWidgets('offline there is no rail, Popular or similar artists', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1220, 1280), offline: true);

    expect(_rail, findsNothing);
    expect(_popular, findsNothing);
    expect(_similar, findsNothing);
    expect(find.text('13 of 13 releases downloaded'), findsOneWidget);
  });

  testWidgets('group headings appear only with two or more groups', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1220, 3000));
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);

    await _pump(tester, size: const Size(1220, 3000), albums: [_album('only')]);
    expect(find.text('Albums'), findsNothing);
    expect(_tiles, findsOneWidget);
  });

  for (final size in const [Size(1220, 1280), Size(1000, 1280)]) {
    testWidgets('nothing moves when the lookups land at ${size.width}', (
      tester,
    ) async {
      final info = Completer<ArtistInfo?>();
      final mb = Completer<MusicBrainzArtistInfo?>();
      final top = Completer<List<Song>>();
      await _pump(
        tester,
        size: size,
        info: info.future,
        mb: mb.future,
        top: top.future,
      );
      final before = tester.getTopLeft(_tiles.first).dy;

      info.complete(_info);
      mb.complete(MusicBrainzArtistInfo(countryCode: 'GB', beginDate: '1987'));
      top.complete(_topSongs);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(_tiles.first).dy, closeTo(before, 0.5));
    });
  }

  testWidgets('no biography keeps its space', (tester) async {
    final info = Completer<ArtistInfo?>();
    await _pump(tester, size: const Size(1220, 1280), info: info.future);
    final before = tester.getTopLeft(_tiles.first).dy;

    info.complete(const ArtistInfo());
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(_tiles.first).dy, closeTo(before, 0.5));
    expect(find.text('Read more').hitTestable(), findsNothing);
  });

  testWidgets('a long name fits at the breakpoint', (tester) async {
    await _pump(
      tester,
      size: const Size(1100, 1000),
      name: 'Godspeed You! Black Emperor and the Long-Named Orchestra',
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('header and toolbar fit at 1100 in ${locale.languageCode}', (
      tester,
    ) async {
      await _pump(tester, size: const Size(1100, 1000), locale: locale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(ArtistDesktopView.shuffleKey), findsOneWidget);
    });
  }

  testWidgets('list rows write the album rating and favorite', (tester) async {
    final repo = _Repo();
    await _pump(
      tester,
      size: const Size(1220, 1280),
      albums: [_album('al0')],
      repo: repo,
    );

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    expect(_tiles, findsNothing, reason: 'the list replaced the grid');

    // The header's own pair is the artist's; the row's are the album's.
    final rowStars = find.byType(StarRating).last;
    await tester.tap(
      find
          .descendant(
            of: rowStars,
            matching: find.byIcon(Icons.star_outline_rounded),
          )
          .at(3),
    );
    await tester.tap(find.byType(FavoriteButton).last);
    await tester.pump();

    expect(repo.ratings, [(EntityType.album, 'al0', 4)]);
    expect(repo.favorites, [(EntityType.album, 'al0', true)]);
  });

  group('view preference', () {
    test('persists by name', () async {
      final notifier = ArtistAlbumsViewNotifier();
      await notifier.setView(ArtistAlbumsView.list);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ArtistAlbumsViewNotifier.storageKey), 'list');
    });

    test('anything unknown is the grid', () {
      expect(decodeArtistAlbumsView('list'), ArtistAlbumsView.list);
      expect(decodeArtistAlbumsView('shelf'), ArtistAlbumsView.grid);
    });
  });
}
