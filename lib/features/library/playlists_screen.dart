import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/mobile_downloads_pill.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// The active server's playlists. Offline, only those with a downloaded track.
///
/// Disposed with the screen, so each visit asks the server again: a playlist
/// edited elsewhere moves nothing the library sync watches.
final playlistsProvider = StreamProvider.autoDispose<List<Playlist>>((
  ref,
) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  if (isOffline) {
    yield* repo.watchDownloadedPlaylists();
    return;
  }

  final cached = await repo.watchPlaylists().first;
  final refresh = repo.refreshPlaylists();
  // A first visit has nothing stored. Waiting keeps the spinner up instead of
  // announcing "No playlists" while they are on their way.
  if (cached.isEmpty) await refresh;
  yield* repo.watchPlaylists();
});

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isOffline = ref.watch(isOfflineModeProvider);
    final playlistsAsync = ref.watch(playlistsProvider);
    final fullyCached =
        ref.watch(downloadedPlaylistIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                isDesktopPlatform ? WindowControlsInset.of(context) + 12 : 16,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.navPlaylists ?? 'Playlists',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isDesktopPlatform) ...[
                    const MobileActiveDownloadsPill(),
                    const SizedBox(width: 8),
                    const OfflineModeToggle(),
                  ],
                ],
              ),
            ),
            const OfflineStatusBanner(),
            Expanded(
              child: playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isOffline
                              ? l10n?.noCachedPlaylists ??
                                    'No playlists cached for offline use'
                              : l10n?.noPlaylists ??
                                    'No playlists on this server',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  final list = ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) => PlaylistRow(
                      playlist: playlists[index],
                      fullyCached: fullyCached.contains(playlists[index].id),
                    ),
                  );
                  if (isOffline) return list;
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.read(libraryRepositoryProvider)?.refreshPlaylists(),
                    child: list,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('${l10n?.error ?? 'Error'}: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One playlist: cover, name, track count and length, and a marker once every
/// track is on the device.
class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.playlist,
    required this.fullyCached,
  });

  final Playlist playlist;
  final bool fullyCached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final count =
        l10n?.trackCount(playlist.songCount) ??
        '${playlist.songCount} ${playlist.songCount == 1 ? 'track' : 'tracks'}';
    return HoverSurface(
      onTap: () => context.push('/playlists/${playlist.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CoverArtImage(
                coverArtId: playlist.coverArtId,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count · ${formatDuration(playlist.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (fullyCached) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.offline_pin,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
