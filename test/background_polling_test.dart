import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/app_in_use_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/shared/widgets/app_chrome.dart';

/// Polling that wakes the radio stops while nobody is using flax. #192.

class _Repo extends Fake implements LibraryRepository {
  int checks = 0;

  @override
  Future<bool> syncIfChanged() async {
    checks++;
    return false;
  }

  @override
  Future<void> syncAnnotations({bool force = false}) async {}

  @override
  Future<int> collectGarbage() async => 0;
}

class _Cache extends Fake implements AudioCacheService {
  var repairs = 0;

  @override
  Future<void> resumePendingDownloads() async {}

  @override
  Future<int> repairOfflineLineage() async {
    repairs++;
    return 0;
  }
}

class _Reachable extends StateNotifier<ServerReachability>
    implements ServerReachabilityNotifier {
  _Reachable() : super(const ServerReachability(isReachable: true));

  @override
  Future<bool> probeServer({bool silent = false, Duration? timeout}) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoUpdates extends StateNotifier<UpdateState> implements UpdateNotifier {
  _NoUpdates() : super(const UpdateState());

  @override
  Future<void> checkForUpdates({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Counts pings to a server that never answers.
class _DeadServer extends Fake implements SubsonicClient {
  int pings = 0;

  @override
  Future<void> whenTargetChosen() async {}

  @override
  Future<String?> tryPing({Duration? timeout}) async {
    pings++;
    return 'Connection timed out';
  }
}

const _server = Server(
  id: 'srv-1',
  name: 'Test Server',
  url: 'http://localhost:4533',
  username: 'admin',
  tokenHash: 'secret',
  salt: 'salt123',
);

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> steps,
) async {
  for (final step in steps) {
    tester.binding.handleAppLifecycleStateChanged(step);
  }
  await tester.pump();
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the library check', () {
    late _Repo repo;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester) async {
      repo = _Repo();
      container = ProviderContainer(
        overrides: [
          serverReachabilityProvider.overrideWith((ref) => _Reachable()),
          updateNotifierProvider.overrideWith((ref) => _NoUpdates()),
          libraryRepositoryProvider.overrideWithValue(repo),
          audioCacheServiceProvider.overrideWithValue(_Cache()),
          isOfflineModeProvider.overrideWithValue(false),
          isCarConnectedProvider.overrideWith((ref) => CarConnectionNotifier()),
          platformOfflinePolicyProvider.overrideWithValue(
            const AndroidOfflinePolicy(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => AppChrome(child: child!),
            home: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('runs every five minutes while flax is on screen', (
      tester,
    ) async {
      await pump(tester);
      final atStart = repo.checks;

      await tester.pump(const Duration(minutes: 5));
      expect(repo.checks, atStart + 1);
    });

    testWidgets('stops while the screen is off, and checks on return', (
      tester,
    ) async {
      await pump(tester);
      await _lifecycle(tester, _toBackground);
      expect(container.read(appVisibleProvider), isFalse);
      final atLock = repo.checks;

      await tester.pump(const Duration(hours: 1));
      expect(repo.checks, atLock, reason: 'no checks with nobody looking');

      await _lifecycle(tester, _toForeground);
      expect(container.read(appVisibleProvider), isTrue);
      expect(repo.checks, atLock + 1, reason: 'coming back checks at once');

      await tester.pump(const Duration(minutes: 5));
      expect(repo.checks, atLock + 2, reason: 'and the schedule resumes');
    });

    testWidgets('keeps running while music plays with the screen off', (
      tester,
    ) async {
      await pump(tester);
      await _lifecycle(tester, _toBackground);
      container.read(playbackActiveProvider.notifier).state = true;
      final atLock = repo.checks;

      await tester.pump(const Duration(minutes: 5));
      expect(repo.checks, atLock + 1);
    });
  });

  group('the reachability retry', () {
    late _DeadServer server;
    late ProviderContainer container;

    Future<void> goUnreachable() async {
      server = _DeadServer();
      container = ProviderContainer(
        overrides: [
          platformOfflinePolicyProvider.overrideWithValue(
            const AndroidOfflinePolicy(),
          ),
          activeServerProvider.overrideWithValue(_server),
          subsonicClientProvider.overrideWithValue(server),
          isCarConnectedProvider.overrideWith((ref) => CarConnectionNotifier()),
        ],
      );
      final reachable = await container
          .read(serverReachabilityProvider.notifier)
          .probeServer();
      expect(reachable, isFalse);
      expect(server.pings, 1);
    }

    testWidgets('keeps pinging while flax is in use', (tester) async {
      await goUnreachable();

      // 4s, 8s, 15s, then every 30s.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 30));
      expect(server.pings, 5);
      container.dispose();
    });

    testWidgets('stops while nobody is using flax', (tester) async {
      await goUnreachable();
      container.read(appVisibleProvider.notifier).state = false;

      await tester.pump(const Duration(hours: 1));
      expect(server.pings, 1, reason: 'not 120 pings an hour in a pocket');

      // Coming back to the foreground probes, which starts the retry again.
      container.read(appVisibleProvider.notifier).state = true;
      await container
          .read(serverReachabilityProvider.notifier)
          .probeServer(silent: true);
      await tester.pump(const Duration(seconds: 4));
      expect(server.pings, 3);
      container.dispose();
    });

    testWidgets('keeps pinging in the car with the screen off', (tester) async {
      await goUnreachable();
      container.read(appVisibleProvider.notifier).state = false;
      container.read(isCarConnectedProvider.notifier).setCarConnected(true);

      await tester.pump(const Duration(seconds: 4));
      expect(server.pings, 2);
      container.dispose();
    });
  });
}
