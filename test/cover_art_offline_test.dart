import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

import 'helpers/fake_cover_store.dart';

/// Offline, a cover is drawn from whatever size of it is stored, and the
/// network is never tried.
void main() {
  late Directory dir;
  late FakeCoverStore store;

  setUp(() {
    dir = const LocalFileSystem().systemTempDirectory.createTempSync(
      'flax_cover_widget_',
    );
    store = FakeCoverStore(dir);
    CoverArtCache.resetForTest();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpCover(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineModeProvider.overrideWithValue(true),
          artCacheProvider.overrideWithValue(store),
          subsonicClientProvider.overrideWithValue(
            SubsonicClient(
              server: const Server(
                id: 'srv',
                name: 'Home',
                url: 'https://music.example.com',
                username: 'me',
                tokenHash: 'secret',
                salt: '',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CoverArtImage(coverArtId: 'al-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // Drawn from disk: a FileImage, wrapped in a ResizeImage when it is decoded
  // at the size it is shown rather than the size it was stored.
  final fileImage = find.byWidgetPredicate((w) {
    if (w is! Image) return false;
    final image = w.image;
    return image is FileImage ||
        (image is ResizeImage && image.imageProvider is FileImage);
  });

  testWidgets('a stored cover of another size is shown', (tester) async {
    // Stored by a download at the configured quality; this tile asks for a
    // different size. Offline only the exact size used to be looked up, so
    // downloaded art showed on some screens and not others.
    store.add(coverCacheKey('al-1', 512));

    await pumpCover(tester);

    expect(fileImage, findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsNothing);
    expect(store.downloaded, isEmpty);
  });

  testWidgets('with nothing stored, a placeholder and no request', (
    tester,
  ) async {
    await pumpCover(tester);

    expect(fileImage, findsNothing);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(store.downloaded, isEmpty);
  });
}
