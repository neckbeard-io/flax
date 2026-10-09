import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/player/now_playing_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/genre_chips.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

/// Genres on a phone: one line, then the sheet. #135.
const _many = [
  'Soundtrack',
  'Britpop',
  'Electronic',
  'Rock',
  'Techno',
  'House',
  'New Wave',
  'Synth-pop',
  'Ambient',
  'Punk',
  'Post-punk',
  'Dub',
  'Breakbeat',
  'Psychedelic',
];

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder get _more => find.textContaining(RegExp(r'^\+\d+$'));

void main() {
  setUp(() => debugOverrideIsDesktopPlatform = false);
  tearDown(() => debugOverrideIsDesktopPlatform = null);

  group('album page', () {
    const albumId = 'alb-1';

    Future<void> pump(WidgetTester tester, {List<String>? genres}) async {
      _phone(tester, const Size(390, 844));
      final album = Album(
        id: albumId,
        serverId: 'srv',
        name: 'Trainspotting',
        artistName: 'Various Artists',
        songCount: 2,
        genres: genres,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumDetailProvider(
              albumId,
            ).overrideWith((ref) => Stream.value(album)),
            albumSongsProvider(albumId).overrideWith(
              (ref) => Stream.value([
                for (var i = 1; i <= 2; i++)
                  Song(
                    id: 's$i',
                    serverId: 'srv',
                    albumId: albumId,
                    title: 'Track $i',
                    genres: genres,
                  ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const MediaQuery(
              data: MediaQueryData(size: Size(390, 844)),
              child: AlbumDetailScreen(albumId: albumId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');
    }

    testWidgets('shows one line of genres, then +N', (tester) async {
      await pump(tester, genres: _many);

      final shown = find.byType(GenreChip).evaluate().length;
      expect(shown, inInclusiveRange(1, _many.length - 1));
      expect(find.text('+${_many.length - shown}'), findsOneWidget);
      expect(tester.getRect(_more).right, lessThanOrEqualTo(390));
    });

    testWidgets('+N opens a sheet with every genre', (tester) async {
      await pump(tester, genres: _many);

      await tester.tap(_more);
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Genres')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(GenreChip)),
        findsNWidgets(_many.length),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an album without genres leaves no empty row', (tester) async {
      await pump(tester, genres: const []);
      expect(find.byType(GenreChips), findsNothing);
    });
  });

  group('touch chips', () {
    testWidgets('answer a tap just outside the drawn chip', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GenreChips(
                genres: const ['Dub'],
                size: GenreChipSize.touch,
                onSelected: (g) => selected = g,
              ),
            ),
          ),
        ),
      );

      final drawn = tester.getRect(find.byType(DecoratedBox).last);
      expect(drawn.height, GenreChipSize.touch.height);
      await tester.tapAt(drawn.topCenter - const Offset(0, 6));
      expect(selected, 'Dub');
    });

    testWidgets('a sheet chip closes the sheet, then selects', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGenresSheet(
                  context,
                  title: 'Ayam',
                  genres: const ['Metal', 'Death Metal'],
                  onSelected: (g) => selected = g,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ayam · 2 genres'), findsOneWidget);

      await tester.tap(find.text('Death Metal'));
      await tester.pumpAndSettle();
      expect(selected, 'Death Metal');
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('now playing', () {
    Future<double> artWidth(
      WidgetTester tester,
      Size size, {
      List<String>? genres,
    }) async {
      final song = Song(
        id: 'song-1',
        serverId: 'srv',
        title: 'Born Slippy .NUXX',
        artistName: 'Underworld',
        albumName: 'Trainspotting',
        duration: 584,
        genres: genres,
      );
      await tester.pumpWidget(
        ProviderScope(
          // A fresh scope per pump: a reused one keeps the first song.
          key: UniqueKey(),
          overrides: [
            playerProvider.overrideWith(
              (ref) => _FakePlayerNotifier(PlayerState(currentSong: song)),
            ),
            downloadedSongIdsProvider.overrideWith(
              (ref) => Stream.value(const {}),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: const NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at $size');
      return tester.getSize(find.byKey(const ValueKey('cover-null'))).width;
    }

    for (final size in const [Size(390, 844), Size(360, 640)]) {
      testWidgets(
        'fits genres at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          _phone(tester, size);
          await artWidth(tester, size, genres: _many);
          expect(find.byType(GenreChips), findsOneWidget);
          expect(tester.getRect(_more).right, lessThanOrEqualTo(size.width));
        },
      );
    }

    testWidgets('the art gives up the genre row on a short phone', (
      tester,
    ) async {
      const size = Size(390, 600);
      _phone(tester, size);
      final without = await artWidth(tester, size, genres: const []);
      final withGenres = await artWidth(tester, size, genres: _many);
      expect(withGenres, lessThan(without));
    });
  });
}
