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
}

final providerElementProvider = Provider<Ref>((ref) => ref);
