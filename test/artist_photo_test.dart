import 'dart:io';

import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/features/player/lyrics_provider.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/artist_photo.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/domain/models/models.dart';
import 'package:mockito/mockito.dart';

import 'helpers/fake_cover_store.dart';

const _url = 'https://photos.example.com/ar.jpg';
const _fallback = Text('fallback');

class _Client extends Mock implements SubsonicClient {
  var asked = 0;

  @override
  Future<void> whenTargetChosen() async {}

  @override
  Future<String?> tryPing({Duration? timeout}) async => null;

  @override
  Future<Lyrics?> getSongLyrics(String? songId) async {
    asked++;
    return null;
  }

  @override
  Future<String?> getLyrics({String? artist, String? title}) async {
    asked++;
    return 'From the server';
  }
}

void main() {
  late Directory dir;
  late Directory base;
  late FakeCoverStore covers;
  late _Client client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('artist_photo');
    base = Directory.systemTemp.createTempSync('artist_lyrics');
    covers = FakeCoverStore(const LocalFileSystem().directory(dir.path));
    client = _Client();
    AudioCacheService.cachedBasePath = base.path;
  });

  tearDown(() {
    AudioCacheService.cachedBasePath = null;
    dir.deleteSync(recursive: true);
    base.deleteSync(recursive: true);
  });

  ProviderContainer offlineContainer() {
    final container = ProviderContainer(
      overrides: [
        artCacheProvider.overrideWithValue(covers),
        subsonicClientProvider.overrideWithValue(client),
        activeServerProvider.overrideWithValue(
          const Server(
            id: 'srv',
            name: 'Home',
            url: 'https://music.example.com',
            username: 'driver',
            tokenHash: 'tok',
            salt: 'salt',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(offlineManualOverrideProvider.notifier).set(true);
    return container;
  }

  Future<void> pumpPhoto(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: offlineContainer(),
        child: const MaterialApp(
          home: SizedBox.square(
            dimension: 200,
            child: ArtistPhoto(url: _url, fallback: _fallback),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  group('ArtistPhoto offline', () {
    testWidgets('shows the stored photo', (tester) async {
      covers.add(_url);

      await pumpPhoto(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('fallback'), findsNothing);
      expect(covers.downloaded, isEmpty);
    });

    testWidgets('falls back without asking the network', (tester) async {
      await pumpPhoto(tester);

      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(covers.downloaded, isEmpty);
    });
  });

  group('lyrics offline', () {
    const query = (songId: 's1', artist: 'Artist', title: 'Song');

    test('come from the stored file', () async {
      File('${base.path}/lyrics/srv/s1.lrc')
        ..createSync(recursive: true)
        ..writeAsStringSync('[00:01.00]Stored line');

      final lyrics = await offlineContainer().read(
        songLyricsProvider(query).future,
      );

      expect(lyrics?.lines.single.text, 'Stored line');
      expect(client.asked, 0);
    });

    test('never ask the server when none are stored', () async {
      final lyrics = await offlineContainer().read(
        songLyricsProvider(query).future,
      );

      expect(lyrics, isNull);
      expect(client.asked, 0);
    });
  });
}
