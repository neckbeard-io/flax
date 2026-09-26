import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/app.dart';
import 'package:flax/app/router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/shared/widgets/shell_scaffold.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery query) =>
      Stream.value(const []);

  @override
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query}) =>
      Stream.value(const []);

  @override
  Stream<Set<String>> watchDownloadedAlbumIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchAnyDownloadedAlbumIds() => Stream.value(const {});

  @override
  Future<void> refreshAlbumList(
    AlbumListQuery query, {
    bool force = false,
  }) async {}

  @override
  Future<bool> syncIfChanged() async => false;

  @override
  Future<void> syncAnnotations({bool force = false}) async {}

  @override
  Future<int> collectGarbage() async => 0;
}

class _FakeServerReachabilityNotifier extends StateNotifier<ServerReachability>
    implements ServerReachabilityNotifier {
  _FakeServerReachabilityNotifier([bool isReachable = true])
    : super(ServerReachability(isReachable: isReachable));

  @override
  Future<bool> probeServer({Duration? timeout, bool silent = false}) async =>
      state.isReachable;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'launching with savedRoute = "/" renders AlbumsScreen cleanly on phone viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          savedRouteProvider.overrideWith((ref) => '/'),
          serverListProvider.overrideWith(
            (ref) => ServerListNotifier(
              initialServers: [
                const Server(
                  id: 'srv-1',
                  name: 'Test Server',
                  url: 'http://test',
                  username: 'user',
                  tokenHash: 'token',
                  salt: 'salt',
                  isActive: true,
                ),
              ],
            ),
          ),
          libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo()),
          serverReachabilityProvider.overrideWith(
            (ref) => _FakeServerReachabilityNotifier(),
          ),
          isOfflineModeProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const FlaxApp()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Ensure no exceptions occurred during build or route resolution
      expect(tester.takeException(), isNull);

      // Verify that AlbumsScreen and ShellScaffold rendered instead of an empty/blank view
      expect(find.byType(AlbumsScreen), findsOneWidget);
      expect(find.byType(ShellScaffold), findsOneWidget);
    },
  );

  testWidgets('GoRouter with initialLocation = "/" redirects to /albums', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        savedRouteProvider.overrideWith((ref) => '/'),
        serverListProvider.overrideWith(
          (ref) => ServerListNotifier(
            initialServers: [
              const Server(
                id: 'srv-1',
                name: 'Test Server',
                url: 'http://test',
                username: 'user',
                tokenHash: 'token',
                salt: 'salt',
                isActive: true,
              ),
            ],
          ),
        ),
        libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo()),
        serverReachabilityProvider.overrideWith(
          (ref) => _FakeServerReachabilityNotifier(),
        ),
        isOfflineModeProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/albums');
    expect(find.byType(AlbumsScreen), findsOneWidget);
  });
}
