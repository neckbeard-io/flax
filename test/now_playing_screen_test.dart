import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/player/now_playing_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/country_chip.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _artistId = 'art-100';

const _testSong = Song(
  id: 'song-1',
  serverId: 'srv',
  title: 'Tom Sawyer',
  artistId: _artistId,
  artistName: 'Rush',
  albumId: 'alb-1',
  albumName: 'Moving Pictures',
  duration: 274,
);

Widget _harness({
  required Song song,
  Artist? artist,
  Future<MusicBrainzArtistInfo?>? mbInfoFuture,
  Size size = const Size(390, 844),
}) {
  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(
        (ref) => _FakePlayerNotifier(PlayerState(currentSong: song)),
      ),
      downloadedSongIdsProvider.overrideWith((ref) => Stream.value(const {})),
      if (artist != null)
        artistDetailProvider(
          _artistId,
        ).overrideWith((ref) => Stream.value(artist)),
      if (mbInfoFuture != null)
        musicBrainzInfoProvider(_artistId).overrideWith((ref) => mbInfoFuture),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const NowPlayingScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    debugOverrideIsDesktopPlatform = false;
  });

  tearDown(() {
    debugOverrideIsDesktopPlatform = null;
  });

  testWidgets(
    'renders CountryFlagIcon beside artist name when countryCode is present',
    (tester) async {
      tester.view.physicalSize = const ui.Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const cachedArtist = Artist(
        id: _artistId,
        serverId: 'srv',
        name: 'Rush',
        country: 'Canada',
        countryCode: 'CA',
      );

      await tester.pumpWidget(
        _harness(
          song: _testSong,
          artist: cachedArtist,
          mbInfoFuture: Future.value(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tom Sawyer'), findsOneWidget);
      expect(find.text('Rush'), findsOneWidget);

      final flagFinder = find.byType(CountryFlagIcon);
      expect(flagFinder, findsOneWidget);

      final flagWidget = tester.widget<CountryFlagIcon>(flagFinder);
      expect(flagWidget.countryCode, 'CA');

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: flagFinder, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, 'Canada');
    },
  );

  testWidgets('renders placeholder slot while isFlagLoading is true', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const uncachedArtist = Artist(id: _artistId, serverId: 'srv', name: 'Rush');

    final mbCompleter = Completer<MusicBrainzArtistInfo?>();

    await tester.pumpWidget(
      _harness(
        song: _testSong,
        artist: uncachedArtist,
        mbInfoFuture: mbCompleter.future,
      ),
    );
    await tester.pump();

    expect(find.text('Rush'), findsOneWidget);
    expect(find.byType(CountryFlagIcon), findsNothing);

    // Placeholder Container is rendered with 20x14 dimension
    final containers = tester.widgetList<Container>(find.byType(Container));
    final placeholder = containers.where((c) {
      final constraints = c.constraints;
      return constraints?.maxWidth == infoChipLeadingWidth &&
          constraints?.maxHeight == 14;
    });
    expect(placeholder, isNotEmpty);

    // Once MusicBrainz resolves, placeholder transforms into the flag
    mbCompleter.complete(
      const MusicBrainzArtistInfo(country: 'Canada', countryCode: 'CA'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CountryFlagIcon), findsOneWidget);
  });

  testWidgets('renders on phone dimensions without overflow', (tester) async {
    tester.view.physicalSize = const ui.Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const cachedArtist = Artist(
      id: _artistId,
      serverId: 'srv',
      name: 'Rush with an Extraordinarily Long Name For Testing',
      country: 'Canada',
      countryCode: 'CA',
    );

    await tester.pumpWidget(
      _harness(
        song: _testSong,
        artist: cachedArtist,
        mbInfoFuture: Future.value(null),
        size: const ui.Size(390, 844),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
