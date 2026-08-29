import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_filter.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/library/downloads_screen.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AlbumFilter includes downloaded tab and filters correctly', (
    tester,
  ) async {
    const downloadedAlbum = Album(
      id: 'alb_dl',
      serverId: 'srv',
      name: 'Downloaded Album',
      artistName: 'Offline Artist',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumFilterProvider.overrideWith((ref) => AlbumFilter.downloaded),
          albumsProvider(
            AlbumFilter.downloaded,
          ).overrideWith((ref) => Stream.value([downloadedAlbum])),
          downloadedAlbumIdsProvider.overrideWith(
            (ref) => Stream.value({'alb_dl'}),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AlbumsScreen())),
      ),
    );

    await tester.pump();

    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Downloaded Album'), findsOneWidget);
  });

  testWidgets('OfflineStatusBanner renders and Go Online button works', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineManualOverrideProvider.overrideWith(
            (ref) => OfflineManualNotifier()..state = true,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [OfflineStatusBanner()])),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('Offline Mode active'), findsOneWidget);
    expect(find.text('Go Online'), findsOneWidget);

    await tester.tap(find.text('Go Online'));
    await tester.pump();
  });

  testWidgets(
    'DownloadsScreen renders tabs and handles empty states on mobile',
    (tester) async {
      tester.view.physicalSize = const ui.Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const testServer = Server(
        id: 'srv1',
        name: 'Test Server',
        url: 'http://localhost:4533',
        username: 'user',
        tokenHash: 'hash',
        salt: 'salt',
        isActive: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWithValue(testServer),
            downloadedAlbumsProvider.overrideWith((ref) => Stream.value([])),
            downloadedSongsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: DownloadsScreen()),
        ),
      );

      await tester.pump();

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Albums (0)'), findsOneWidget);
      expect(find.text('Tracks (0)'), findsOneWidget);
      expect(find.text('No downloaded albums'), findsOneWidget);
    },
  );
}
