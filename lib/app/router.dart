import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/features/auth/add_server_screen.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/library/artists_screen.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/library/songs_screen.dart';
import 'package:flax/features/home/home_screen.dart';
import 'package:flax/features/search/search_screen.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/features/settings/audio_output_screen.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/features/settings/transcoding_screen.dart';
import 'package:flax/features/settings/autoeq_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final hasServer = ref.watch(activeServerProvider) != null;

  // Ignored in release builds even if the define is set, so a stray define
  // cannot ship an app that opens somewhere unexpected.
  final start = (kDebugMode && _debugInitialRoute.isNotEmpty && hasServer)
      ? _debugInitialRoute
      : (hasServer ? '/home' : '/add-server');

  return GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/add-server',
        builder: (context, state) => const AddServerScreen(),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (context, state) => const NowPlayingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/artists',
            builder: (context, state) => const ArtistsScreen(),
          ),
          GoRoute(
            path: '/artists/:id',
            builder: (context, state) => ArtistDetailScreen(
              artistId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/albums',
            builder: (context, state) => const AlbumsScreen(),
          ),
          GoRoute(
            path: '/albums/:id',
            builder: (context, state) => AlbumDetailScreen(
              albumId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/songs',
            builder: (context, state) => const SongsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
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
            ],
          ),
        ],
      ),
    ],
  );
});
