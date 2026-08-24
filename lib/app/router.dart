import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/library/artists_screen.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/search/search_screen.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/features/settings/audio_output_screen.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/features/settings/transcoding_screen.dart';
import 'package:flax/features/settings/autoeq_screen.dart';
import 'package:flax/features/settings/hotkeys_screen.dart';
import 'package:flax/features/settings/metadata_caching_screen.dart';
import 'package:flax/features/player/now_playing_screen.dart';
import 'package:flax/shared/widgets/shell_scaffold.dart';

/// Route to open on launch instead of home, for debug builds only.
///
/// Set with `--dart-define=FLAX_ROUTE=/artists/<id>`, or via
/// `tool/run_flax.sh --route <path>`. Screens buried behind navigation are
/// otherwise unreachable without clicking, which makes verifying them by
/// screenshot impossible — synthetic clicks do not reach a Flutter window, so
/// there was no way to look at an artist or album page at all.
const _debugInitialRoute = String.fromEnvironment('FLAX_ROUTE');

/// Key used in SharedPreferences to persist the last visited route.
const lastRouteStorageKey = 'flax_last_route';

/// Provider holding the last persisted route read at startup.
final savedRouteProvider = StateProvider<String?>((ref) => null);

/// Where the app opens.
///
/// Pulled out as a plain function so the rule can be tested without standing up
/// a router or touching the machine's real preferences — the bug this guards
/// looked exactly like a saved server having been forgotten.
///
/// [debugRoute] comes from FLAX_ROUTE. /add-server is refused as a destination
/// whenever a server exists: a build with that route compiled in reopened setup
/// on every launch, and with a server already configured, starting at setup is
/// never right.
String initialLocationFor({
  required bool hasServer,
  String debugRoute = '',
  bool allowDebugRoute = false,
  String? savedRoute,
}) {
  if (!hasServer) return '/add-server';
  final wantsSetup = debugRoute.startsWith('/add-server');
  if (allowDebugRoute && debugRoute.isNotEmpty && !wantsSetup) {
    return debugRoute;
  }
  if (savedRoute != null &&
      savedRoute.isNotEmpty &&
      !savedRoute.startsWith('/add-server')) {
    return savedRoute;
  }
  // Albums is the default fallback if no route was saved.
  return '/albums';
}

void _persistRoute(String location) {
  if (location.isEmpty || location.startsWith('/add-server')) return;
  SharedPreferences.getInstance()
      .then((prefs) {
        prefs.setString(lastRouteStorageKey, location);
      })
      .catchError((_) {
        // Best-effort persistence.
      });
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final hasServer = ref.watch(serverListProvider.select((s) => s.isNotEmpty));
  final savedRoute = ref.read(savedRouteProvider);

  final start = initialLocationFor(
    hasServer: hasServer,
    debugRoute: _debugInitialRoute,
    allowDebugRoute: kDebugMode,
    savedRoute: savedRoute,
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: start,
    redirect: (context, state) {
      final location = state.uri.toString();
      if (location.isNotEmpty && !location.startsWith('/add-server')) {
        _persistRoute(location);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/add-server',
        builder: (context, state) => const AddServerScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          // Inside the shell, not beside it. The desktop layout wants the
          // sidebar and the mini player's transport, and a second ShellScaffold
          // of its own meant two sidebars alive at once — two text fields
          // sharing one FocusNode, which broke the "/" shortcut entirely.
          // ShellScaffold drops its own chrome at phone widths, so the phone
          // now-playing screen still fills the window.
          GoRoute(
            path: '/now-playing',
            builder: (context, state) => const NowPlayingScreen(),
          ),
          GoRoute(
            path: '/artists',
            builder: (context, state) => const ArtistsScreen(),
          ),
          GoRoute(
            path: '/artists/:id',
            builder: (context, state) =>
                ArtistDetailScreen(artistId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/albums',
            builder: (context, state) => const AlbumsScreen(),
          ),
          GoRoute(
            path: '/albums/:id',
            builder: (context, state) =>
                AlbumDetailScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/songs', redirect: (context, state) => '/albums'),
          GoRoute(
            path: '/search',
            builder: (context, state) => SearchScreen(
              // Keyed on the query so arriving from quick search a second
              // time, with different words, rebuilds the screen rather than
              // reusing the old state and showing the old query.
              key: ValueKey(state.uri.queryParameters['q'] ?? ''),
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'audio',
                builder: (context, state) => const AudioOutputScreen(),
              ),
              GoRoute(
                path: 'equalizer',
                builder: (context, state) => const EqualizerScreen(),
              ),
              GoRoute(
                path: 'transcoding',
                builder: (context, state) => const TranscodingScreen(),
              ),
              GoRoute(
                path: 'autoeq',
                builder: (context, state) => const AutoEqScreen(),
              ),
              GoRoute(
                path: 'metadata-cache',
                builder: (context, state) => const MetadataCachingScreen(),
              ),
              GoRoute(
                path: 'hotkeys',
                builder: (context, state) => const HotkeysScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
