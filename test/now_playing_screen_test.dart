import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/player/now_playing_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/transcoding/transcoding_service.dart';
import 'package:flax/shared/widgets/country_chip.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

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
  PlayerState? state,
  Artist? artist,
  Future<MusicBrainzArtistInfo?>? mbInfoFuture,
  Size size = const Size(390, 844),
}) {
  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(
        (ref) => _FakePlayerNotifier(state ?? PlayerState(currentSong: song)),
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

  // A downloaded album, opened on cellular: the badge read FLAC 24/44.1 →
  // OPUS 256kbps beside the offline pin, though the track was not streamed.
  group('format badge on a phone', () {
    const flac = Song(
      id: 'song-2',
      serverId: 'srv',
      title: 'Tormento',
      artistName: 'Disillusion',
      suffix: 'flac',
      bitDepth: 24,
      sampleRate: 44100,
      duration: 264,
    );
    const cellular = TranscodeParameters(
      maxBitRate: 256,
      format: 'opus',
      quality: StreamQuality.kbps256,
      isTranscoded: true,
    );

    Future<void> pumpBadge(WidgetTester tester, PlayerState state) async {
      tester.view.physicalSize = const ui.Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(song: flac, state: state));
      await tester.pump();
    }

    testWidgets('a downloaded track shows its file, not the stream setting', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        const PlayerState(
          currentSong: flac,
          activeTranscode: cellular,
          cachedFormat: 'flac',
        ),
      );

      expect(find.text('FLAC · 24/44.1'), findsOneWidget);
      expect(find.textContaining('OPUS'), findsNothing);
      expect(find.byIcon(Icons.transform_rounded), findsNothing);
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    });

    testWidgets('a track downloaded as OPUS shows that conversion', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        const PlayerState(
          currentSong: flac,
          activeTranscode: cellular,
          cachedFormat: 'opus',
        ),
      );

      expect(find.text('OPUS'), findsOneWidget);
      expect(find.textContaining('256'), findsNothing);
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    });

    testWidgets('a streamed track shows the stream setting and no pin', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        const PlayerState(currentSong: flac, activeTranscode: cellular),
      );

      expect(find.text('OPUS 256kbps'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin), findsNothing);
    });
  });

  // Two full header sides need 504pt on desktop, and the narrowest window is
  // 460pt: the title got nothing and the queue button slid under the window
  // controls.
  group('phone header', () {
    Future<void> pumpAt(WidgetTester tester, ui.Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _harness(song: _testSong, mbInfoFuture: Future.value(null), size: size),
      );
      await tester.pump();
    }

    Rect queueButton(WidgetTester tester) => tester.getRect(
      find.ancestor(
        of: find.byIcon(Icons.queue_music),
        matching: find.byType(IconButton),
      ),
    );

    Rect title(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.text('Now Playing'),
            matching: find.byType(Expanded),
          )
          .first,
    );

    for (final width in [460.0, 511.0, 600.0]) {
      testWidgets('keeps the title and queue button in a ${width.toInt()}pt '
          'desktop window', (tester) async {
        debugOverrideIsDesktopPlatform = true;
        await pumpAt(tester, ui.Size(width, 900));

        expect(tester.takeException(), isNull);
        expect(
          queueButton(tester).right,
          lessThanOrEqualTo(width - windowButtonsReservedWidth),
        );
        expect(title(tester).width, greaterThanOrEqualTo(120));
      });
    }

    testWidgets('centers the title in a wider desktop window', (tester) async {
      debugOverrideIsDesktopPlatform = true;
      await pumpAt(tester, const ui.Size(650, 900));

      expect(tester.takeException(), isNull);
      expect(title(tester).center.dx, moreOrLessEquals(325));
      expect(
        queueButton(tester).right,
        lessThanOrEqualTo(650 - windowButtonsReservedWidth),
      );
    });

    testWidgets('is unchanged on a phone', (tester) async {
      await pumpAt(tester, const ui.Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(title(tester).center.dx, moreOrLessEquals(195));
      expect(queueButton(tester).right, moreOrLessEquals(386));
    });
  });
}
