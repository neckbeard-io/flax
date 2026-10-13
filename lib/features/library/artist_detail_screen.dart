import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_sort.dart';
import 'package:flax/features/library/artist_desktop_view.dart';
import 'package:flax/features/library/artist_widgets.dart';
import 'package:flax/services/musicbrainz/musicbrainz_service.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

// ── Providers ─────────────────────────────────────────────────────────

/// The artist, from the local database. Issue #8.
final artistDetailProvider = StreamProvider.family<Artist, String>((
  ref,
  id,
) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) throw Exception('No server');

  if (!isOffline) {
    repo.refreshArtist(id).catchError((_) {});
  }

  yield* repo.watchArtist(id).map((artist) {
    if (artist == null) throw Exception('Artist not found');
    return artist;
  });
});

/// The artist's albums.
///
/// One `getArtist` now supplies these. The previous version fetched the artist,
/// then searched the whole library for its name, then kept whatever came back
/// whose `artistId` or `artistName` matched — two requests, and it quietly
/// claimed albums belonging to any artist with an overlapping name.
final artistAlbumsProvider = StreamProvider.family<List<Album>, String>((
  ref,
  artistId,
) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  if (isOffline) {
    yield* repo.watchDownloadedArtistAlbums(artistId);
    return;
  }

  final cached = await repo.watchArtistAlbums(artistId).first;
  if (cached.isNotEmpty) {
    yield cached;
    repo.refreshArtist(artistId).catchError((_) {});
    yield* repo.watchArtistAlbums(artistId);
    return;
  }

  final downloaded = await repo.watchDownloadedArtistAlbums(artistId).first;
  if (downloaded.isNotEmpty) {
    yield downloaded;
    repo.refreshArtist(artistId).catchError((_) {});
    yield* repo.watchArtistAlbums(artistId);
    return;
  }

  yield const [];
  repo.refreshArtist(artistId).catchError((_) {});
  yield* repo.watchArtistAlbums(artistId);
});

final artistInfoProvider = FutureProvider.family<ArtistInfo?, String>((
  ref,
  artistId,
) async {
  final isOffline = ref.watch(isOfflineModeProvider);
  if (isOffline) return null;
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return null;
  return client.getArtistInfoParsed(artistId);
});

/// The artist's most popular songs, as the server ranks them: Navidrome asks
/// Last.fm and matches the answers to the library.
///
/// Online only, and not autoDispose, so an artist's list is fetched once a
/// session. Watches only the artist's name, so rating or favoriting the artist
/// does not fetch it again. Any failure is an empty list, which hides the
/// section.
final artistTopSongsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  artistId,
) async {
  if (ref.watch(isOfflineModeProvider)) return const [];
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  final name = await ref.watch(
    artistDetailProvider(artistId).selectAsync((a) => a.name),
  );
  try {
    return await client.getTopSongs(name, artistId: artistId, count: 10);
  } catch (e) {
    AppLogger.w('Artist', 'getTopSongs($artistId) failed: $e');
    return const [];
  }
});

final musicBrainzInfoProvider =
    FutureProvider.family<MusicBrainzArtistInfo?, String>((
      ref,
      artistId,
    ) async {
      final isOffline = ref.watch(isOfflineModeProvider);
      final artist = await ref.watch(artistDetailProvider(artistId).future);
      if (artist.countryCode != null ||
          artist.country != null ||
          artist.activeYears != null) {
        return MusicBrainzArtistInfo(
          country: artist.country,
          countryCode: artist.countryCode,
          explicitActiveYears: artist.activeYears,
        );
      }
      if (isOffline) return null;

      MusicBrainzArtistInfo? info;
      if (artist.musicBrainzId != null) {
        info = await MusicBrainzService.getArtistInfo(artist.musicBrainzId!);
      }

      if (info == null) {
        final artistInfo = await ref.watch(artistInfoProvider(artistId).future);
        if (artistInfo?.musicBrainzId != null) {
          info = await MusicBrainzService.getArtistInfo(
            artistInfo!.musicBrainzId!,
          );
        }
      }

      info ??= await MusicBrainzService.searchArtist(artist.name);

      if (info != null &&
          (info.country != null ||
              info.countryCode != null ||
              info.activeYears != null)) {
        final repo = ref.read(libraryRepositoryProvider);
        if (repo != null) {
          await repo.updateArtistCountry(
            artistId,
            country: info.country,
            countryCode: info.countryCode,
            activeYears: info.activeYears,
          );
        }
      }

      return info;
    });

// ── Screen ────────────────────────────────────────────────────────────

class ArtistDetailScreen extends ConsumerWidget {
  final String artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  static bool _isDesktop(BuildContext context) =>
      isDesktopPlatform && MediaQuery.sizeOf(context).width >= 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistDetailProvider(artistId));
    final albumsAsync = ref.watch(artistAlbumsProvider(artistId));
    final artistInfoAsync = ref.watch(artistInfoProvider(artistId));
    final mbInfoAsync = ref.watch(musicBrainzInfoProvider(artistId));
    final isDesktop = _isDesktop(context);

    return Scaffold(
      body: artistAsync.when(
        data: (artist) {
          final artistInfo = artistInfoAsync.valueOrNull;
          final mbInfo = mbInfoAsync.valueOrNull;
          final infoLoading =
              artistInfoAsync.isLoading || mbInfoAsync.isLoading;

          if (isDesktop) {
            return ArtistDesktopView(
              artist: artist,
              albums: albumsAsync,
              artistInfo: artistInfo,
              mbInfo: mbInfo,
              infoLoading: infoLoading,
              topSongs: ref.watch(artistTopSongsProvider(artistId)),
              offline: ref.watch(isOfflineModeProvider),
            );
          }

          final sortMode = ref.watch(albumSortProvider);
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, artist, artistInfo),
              SliverToBoxAdapter(
                child: _ArtistActionsBar(
                  artist: artist,
                  artistId: artistId,
                  mbInfo: mbInfo,
                  infoLoading: infoLoading,
                ),
              ),
              SliverToBoxAdapter(child: _buildSortBar(context)),
              albumsAsync.when(
                data: (albums) {
                  final sorted = sortAlbums(albums, sortMode);
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _AlbumTile(album: sorted[index]),
                      childCount: sorted.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    Artist artist,
    ArtistInfo? artistInfo,
  ) {
    final bgImage = artistInfo?.bestImageUrl ?? artist.imageUrl;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(artist.name, style: const TextStyle(fontSize: 18)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (bgImage != null)
              CachedNetworkImage(
                imageUrl: bgImage,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => artist.coverArtId != null
                    ? CoverArtImage(coverArtId: artist.coverArtId, size: 600)
                    : const SizedBox.shrink(),
              )
            else if (artist.coverArtId != null)
              CoverArtImage(coverArtId: artist.coverArtId, size: 600),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            'Albums',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const AlbumSortMenuButton(),
        ],
      ),
    );
  }
}

// ── Album tile with rating ────────────────────────────────────────────

class _AlbumTile extends ConsumerWidget {
  final Album album;
  const _AlbumTile({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadedAlbumIds =
        ref.watch(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final anyDownloadedAlbumIds =
        ref.watch(anyDownloadedAlbumIdsProvider).valueOrNull ?? const {};
    final isFullyCached = downloadedAlbumIds.contains(album.id);
    final isPartiallyCached =
        anyDownloadedAlbumIds.contains(album.id) && !isFullyCached;

    return AlbumContextMenu(
      album: album,
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              HoverArtwork(
                onTap: () => context.push('/albums/${album.id}'),
                borderRadius: BorderRadius.circular(4),
                scale: 1.08,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CoverArtImage(coverArtId: album.coverArtId, size: 48),
                ),
              ),
              if (isFullyCached || isPartiallyCached)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFullyCached
                          ? Icons.offline_pin
                          : Icons.offline_pin_outlined,
                      size: 13,
                      color: isFullyCached
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(album.name),
        subtitle: Text(
          [
            if (album.year != null) '${album.year}',
            '${album.songCount} tracks',
            if (album.displayGenres.isNotEmpty) album.displayGenres.join(', '),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: album.userRating != null && album.userRating! > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < album.userRating! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: i < album.userRating!
                        ? Colors.amber
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                  ),
                ),
              )
            : null,
        onTap: () => context.push('/albums/${album.id}'),
      ),
    );
  }
}

/// Rating and favorite for the artist.
///
/// Navidrome exposes both for artists — a 0-5 rating and a separate favorite
/// flag — and Subsonic's setRating/star take an artist id like any other
/// entity, so nothing special is needed beyond a model field to read back.
class _ArtistActionsBar extends ConsumerWidget {
  const _ArtistActionsBar({
    required this.artist,
    required this.artistId,
    this.mbInfo,
    this.infoLoading = false,
  });

  final Artist artist;
  final String artistId;
  final MusicBrainzArtistInfo? mbInfo;
  final bool infoLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasCountryOrYears =
        artist.countryCode != null ||
        artist.country != null ||
        artist.activeYears != null ||
        mbInfo?.countryLabel != null ||
        mbInfo?.activeYears != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${artist.albumCount} '
                '${artist.albumCount == 1 ? "album" : "albums"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              ArtistRatingRow(artist: artist, artistId: artistId, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: infoLoading && mbInfo == null && !hasCountryOrYears
                ? const ArtistLoadingBar(width: 160)
                : ArtistInfoChips(mbInfo: mbInfo, artist: artist),
          ),
        ],
      ),
    );
  }
}
