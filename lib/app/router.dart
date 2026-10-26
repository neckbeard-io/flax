import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/library/artists_screen.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/library/downloads_screen.dart';
import 'package:flax/features/library/genre_screen.dart';
import 'package:flax/features/search/search_screen.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/features/settings/audio_output_screen.dart';
import 'package:flax/features/settings/audio_devices_screen.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/features/settings/theme_settings_screen.dart';
import 'package:flax/features/settings/transcoding_screen.dart';
import 'package:flax/features/settings/autoeq_screen.dart';
import 'package:flax/features/settings/hotkeys_screen.dart';
import 'package:flax/features/settings/metadata_caching_screen.dart';
import 'package:flax/features/settings/server_connection_screen.dart';
import 'package:flax/features/settings/android_auto_screen.dart';
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

/// Validates whether a location string corresponds to a known valid route in the app.
///
/// Prevents blank screens and navigation traps caused by invalid or empty routes (e.g. '/'),
/// which can be delivered by background services or stale preferences. The
/// router's redirect sends anything this rejects to /albums.
///
/// Derived from [appRoutes]: a literal segment must match exactly, and a
/// `:param` segment matches any non-empty one. It used to be a hand-kept list,
/// and a screen added to the routes but not to it opened Albums (#176).
bool isValidRoute(String location) {
  if (location.isEmpty || location == '/') return false;
  final uri = Uri.tryParse(location);
  if (uri == null) return false;
  final segments = _segments(uri.path);
  if (segments == null) return false;
  return _routePatterns.any((pattern) => _matches(pattern, segments));
}

/// Every path [routes] register, joined onto their parents' paths. Path-less
/// routes such as the shell only contribute their children.
@visibleForTesting
List<String> routePaths(List<RouteBase> routes, [String parent = '']) => [
  for (final route in routes)
    ...switch (route) {
      GoRoute(:final path) when path.startsWith('/') => [
        path,
        ...routePaths(route.routes, path),
      ],
      GoRoute(:final path) => [
        '$parent/$path',
        ...routePaths(route.routes, '$parent/$path'),
      ],
      _ => routePaths(route.routes, parent),
    },
];

/// [appRoutes] as segments. '/' is left out: it only redirects to /albums.
final List<List<String>> _routePatterns = [
  for (final path in routePaths(appRoutes))
    if (path != '/') _segments(path)!,
];

/// [path]'s segments, keeping empty ones so '/albums/' never reads as
/// '/albums'; null when it is not an absolute path.
List<String>? _segments(String path) {
  if (!path.startsWith('/') || path.length < 2) return null;
  return path.substring(1).split('/');
}

bool _matches(List<String> pattern, List<String> segments) {
  if (pattern.length != segments.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    final literal = !pattern[i].startsWith(':');
    if (literal ? pattern[i] != segments[i] : segments[i].isEmpty) {
      return false;
    }
  }
  return true;
}

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
  if (allowDebugRoute &&
      debugRoute.isNotEmpty &&
      !wantsSetup &&
      isValidRoute(debugRoute)) {
    return debugRoute;
  }
  if (savedRoute != null &&
      savedRoute.isNotEmpty &&
      isValidRoute(savedRoute) &&
      !savedRoute.startsWith('/add-server')) {
    return savedRoute;
  }
  // Albums is the default fallback if no route was saved or if savedRoute is invalid.
  return '/albums';
}

void _persistRoute(String location) {
  if (!isValidRoute(location) || location.startsWith('/add-server')) return;
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
    errorBuilder: (context, state) {
      AppLogger.w(
        'Router',
        'Unmatched route "${state.uri}", falling back to /albums',
      );
      return const ShellScaffold(child: AlbumsScreen());
    },
    redirect: (context, state) {
      if (!hasServer) {
        return '/add-server';
      }
      final location = state.uri.toString();
      final path = state.uri.path;
      if (path == '/' || path.isEmpty || !isValidRoute(location)) {
        return '/albums';
      }
      if (!location.startsWith('/add-server')) {
        _persistRoute(location);
      }
      return null;
    },
    routes: appRoutes,
  );
});

/// Every screen in the app. [isValidRoute] is derived from this list, so a
/// route added here is accepted everywhere with no other change.
final List<RouteBase> appRoutes = [
  GoRoute(path: '/', redirect: (context, state) => '/albums'),
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
      GoRoute(
        path: '/genres/:name',
        builder: (context, state) =>
            GenreScreen(genre: state.pathParameters['name']!),
      ),
      GoRoute(path: '/songs', redirect: (context, state) => '/albums'),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
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
            path: 'audio-devices',
            builder: (context, state) => const AudioDevicesScreen(),
          ),
          GoRoute(
            path: 'equalizer',
            builder: (context, state) => const EqualizerScreen(),
            routes: [
              GoRoute(
                path: 'autoeq',
                builder: (context, state) => const AutoEqScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'autoeq',
            redirect: (context, state) => '/settings/equalizer/autoeq',
          ),
          GoRoute(
            path: 'transcoding',
            builder: (context, state) => const TranscodingScreen(),
          ),
          GoRoute(
            path: 'metadata-cache',
            builder: (context, state) => const MetadataCachingScreen(),
          ),
          GoRoute(
            path: 'server-connection',
            builder: (context, state) => ServerConnectionScreen(
              serverId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: 'hotkeys',
            builder: (context, state) => const HotkeysScreen(),
          ),
          GoRoute(
            path: 'theme',
            builder: (context, state) => const ThemeSettingsScreen(),
          ),
          GoRoute(
            path: 'android-auto',
            builder: (context, state) => const AndroidAutoScreen(),
          ),
        ],
      ),
    ],
  ),
];
