import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

@GenerateNiceMocks([
  MockSpec<SubsonicClient>(),
  MockSpec<LibraryDao>(),
  MockSpec<BaseCacheManager>(),
  MockSpec<FileInfo>(),
  MockSpec<File>(),
])
import 'metadata_sync_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSubsonicClient mockClient;
  late MockLibraryDao mockDao;
  late MockBaseCacheManager mockCache;
  late MetadataSyncService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockSubsonicClient();
    mockDao = MockLibraryDao();
    mockCache = MockBaseCacheManager();
    container = ProviderContainer();
    container.read(serverListProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    service = MetadataSyncService(
      container.read(providerElementProvider),
      cacheManager: mockCache,
    );
  });

  tearDown(() {
    container.dispose();
  });

  const testServer = Server(
    id: 'srv-1',
    name: 'Home',
    url: 'https://music.example.com',
    username: 'user',
    tokenHash: 'hash',
    salt: 'salt',
    metadataCacheConfig: MetadataCacheConfig(
      albumArtQuality: MetadataQuality.low,
      artistArtQuality: MetadataQuality.low,
      cacheArtistInfo: true,
      concurrency: 2,
    ),
  );

  test('MetadataSyncService starts task in registry and completes', () async {
    final testArtists = [
      const Artist(
        id: 'art-1',
        serverId: 'srv-1',
        name: 'Artist One',
        coverArtId: 'art-cov-1',
      ),
    ];
    final testAlbums = [
      const Album(
        id: 'alb-1',
        serverId: 'srv-1',
        name: 'Album One',
        coverArtId: 'alb-cov-1',
      ),
    ];

    when(
      mockDao.watchArtists('srv-1'),
    ).thenAnswer((_) => Stream.value(testArtists));
    when(
      mockDao.watchAllAlbums('srv-1'),
    ).thenAnswer((_) => Stream.value(testAlbums));
    when(mockDao.getAllArtists('srv-1')).thenAnswer((_) async => testArtists);
    when(mockDao.getAllAlbums('srv-1')).thenAnswer((_) async => testAlbums);
    when(
      mockClient.getAlbumList(
        any,
        count: anyNamed('count'),
        offset: anyNamed('offset'),
      ),
    ).thenAnswer((_) async => testAlbums);
    when(
      mockClient.getCoverArtUri(any, size: anyNamed('size')),
    ).thenReturn(Uri.parse('https://music.example.com/cover'));
    when(
      mockClient.getArtistInfoParsed(any),
    ).thenAnswer((_) async => const ArtistInfo(biography: 'Bio text'));

    final mockFileInfo = MockFileInfo();
    final mockFile = MockFile();
    when(mockFile.length()).thenAnswer((_) async => 1024);
    when(mockFileInfo.file).thenReturn(mockFile);

    when(mockCache.getFileFromCache(any)).thenAnswer((_) async => null);
    when(
      mockCache.downloadFile(any, key: anyNamed('key')),
    ).thenAnswer((_) async => mockFileInfo);

    final syncFuture = service.startSync(
      server: testServer,
      client: mockClient,
      dao: mockDao,
    );

    await syncFuture;

    final tasks = container.read(taskRegistryProvider);
    expect(tasks, isNotEmpty);
    final task = tasks.first;
    expect(task.kind, TaskKind.metadataCrawl);
    expect(task.state, TaskState.done);
    expect(task.itemsDone, 3);
  });

  test('MetadataSyncService honors cancellation', () async {
    when(mockDao.watchArtists('srv-1')).thenAnswer((_) => Stream.value([]));
    when(mockDao.watchAllAlbums('srv-1')).thenAnswer((_) => Stream.value([]));

    service.cancel();
    expect(service.isRunning, isFalse);
  });

  test(
    'startSync indexes full artist list even when database already has partial artist data',
    () async {
      // Setup: DB has 1 artist initially (e.g. from cached song)
      final initialDbArtists = [
        const Artist(
          id: 'art-1',
          serverId: 'srv-1',
          name: 'Artist One',
          coverArtId: 'art-cov-1',
          biography: 'Existing bio',
        ),
      ];
      // Server returns full list with 3 artists
      final fullServerArtists = [
        const Artist(
          id: 'art-1',
          serverId: 'srv-1',
          name: 'Artist One',
          coverArtId: 'art-cov-1',
        ),
        const Artist(
          id: 'art-2',
          serverId: 'srv-1',
          name: 'Artist Two',
          coverArtId: 'art-cov-2',
        ),
        const Artist(
          id: 'art-3',
          serverId: 'srv-1',
          name: 'Artist Three',
          coverArtId: 'art-cov-3',
        ),
      ];

      when(
        mockDao.watchArtists('srv-1'),
      ).thenAnswer((_) => Stream.value(initialDbArtists));
      when(mockDao.watchAllAlbums('srv-1')).thenAnswer((_) => Stream.value([]));
      when(
        mockClient.getAlbumList(
          any,
          count: anyNamed('count'),
          offset: anyNamed('offset'),
        ),
      ).thenAnswer((_) async => []);
      when(mockClient.getArtists()).thenAnswer((_) async => fullServerArtists);
      when(
        mockDao.getAllArtists('srv-1'),
      ).thenAnswer((_) async => fullServerArtists);
      when(mockDao.getAllAlbums('srv-1')).thenAnswer((_) async => []);
      when(
        mockClient.getCoverArtUri(any, size: anyNamed('size')),
      ).thenReturn(Uri.parse('https://music.example.com/cover'));
      when(
        mockClient.getArtistInfoParsed(any),
      ).thenAnswer((_) async => const ArtistInfo(biography: 'Bio'));

      final mockFileInfo = MockFileInfo();
      final mockFile = MockFile();
      when(mockFile.length()).thenAnswer((_) async => 512);
      when(mockFileInfo.file).thenReturn(mockFile);
      when(mockCache.getFileFromCache(any)).thenAnswer((_) async => null);
      when(
        mockCache.downloadFile(any, key: anyNamed('key')),
      ).thenAnswer((_) async => mockFileInfo);

      await service.startSync(
        server: testServer,
        client: mockClient,
        dao: mockDao,
      );

      // Verify client.getArtists() was called unconditionally
      verify(mockClient.getArtists()).called(1);
      // Verify full artist list was upserted with isFullList: true
      verify(
        mockDao.upsertArtists(fullServerArtists, any, isFullList: true),
      ).called(1);

      final task = container.read(taskRegistryProvider).first;
      expect(task.state, TaskState.done);
      // 3 artist photos + 3 artist bios = 6 items
      expect(task.itemsDone, 6);
    },
  );

  test(
    'getSummary reconciles missing artists referenced by albums and reports accurate totals',
    () async {
      // DB has 1 artist
      final artists = [
        const Artist(
          id: 'art-1',
          serverId: 'srv-1',
          name: 'Artist One',
          coverArtId: 'cov-1',
          biography: 'Bio',
        ),
      ];
      // DB has 3 albums, 2 of which reference artists not in the artists table
      final albums = [
        const Album(
          id: 'alb-1',
          serverId: 'srv-1',
          artistId: 'art-1',
          name: 'Album One',
          coverArtId: 'alb-cov-1',
        ),
        const Album(
          id: 'alb-2',
          serverId: 'srv-1',
          artistId: 'art-2',
          artistName: 'Artist Two',
          name: 'Album Two',
          coverArtId: 'alb-cov-2',
        ),
        const Album(
          id: 'alb-3',
          serverId: 'srv-1',
          artistId: 'art-3',
          artistName: 'Artist Three',
          name: 'Album Three',
          coverArtId: 'alb-cov-3',
        ),
      ];

      when(mockDao.getAllArtists('srv-1')).thenAnswer((_) async => artists);
      when(mockDao.getAllAlbums('srv-1')).thenAnswer((_) async => albums);
      when(mockDao.artistsFetchedAt('srv-1')).thenAnswer((_) async => null);
      when(mockCache.getFileFromCache(any)).thenAnswer((_) async => null);

      final summary = await service.getSummary(testServer, mockDao);

      // Total artist bios should include reconciled artists from albums (3, not 1)
      expect(summary.artistInfoTotal, 3);
      expect(summary.artistInfoCached, 1);
      // When artistsFetchedAt is null, artistArtTotal should reflect full discovered count
      expect(summary.artistArtTotal, 3);
      expect(summary.isFullyCached, isFalse);
    },
  );

  test(
    'MetadataCacheSummary respects disabled configuration in isFullyCached',
    () {
      const disabledConfig = MetadataCacheConfig(
        albumArtQuality: MetadataQuality.disabled,
        artistArtQuality: MetadataQuality.disabled,
        cacheArtistInfo: false,
      );
      const summary = MetadataCacheSummary(
        albumArtCached: 0,
        albumArtTotal: 10,
        artistArtCached: 0,
        artistArtTotal: 10,
        artistInfoCached: 0,
        artistInfoTotal: 10,
        config: disabledConfig,
      );
      expect(summary.isFullyCached, isTrue);
    },
  );
}

final providerElementProvider = Provider<Ref>((ref) => ref);
