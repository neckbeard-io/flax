import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_sort.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/shared/widgets/caching_snack_bar.dart';
import 'package:flax/shared/widgets/country_chip.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/star_rating.dart';

/// Placeholder occupying the space a not-yet-loaded value will fill.
class ArtistLoadingBar extends StatelessWidget {
  const ArtistLoadingBar({super.key, required this.width, this.height = 12});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Country and active-years chips, shared by the desktop header and the phone
/// info panel so the two cannot present the same metadata differently.
///
/// [leading] goes first in the same run, so a count can share the line.
class ArtistInfoChips extends StatelessWidget {
  const ArtistInfoChips({super.key, this.mbInfo, this.artist, this.leading});

  final MusicBrainzArtistInfo? mbInfo;
  final Artist? artist;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final country = artist?.countryLabel ?? mbInfo?.countryLabel;
    final countryCode = artist?.countryCode ?? mbInfo?.countryCode;
    final years = artist?.activeYears ?? mbInfo?.activeYears;
    if (leading == null && country == null && years == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      clipBehavior: Clip.hardEdge,
      children: [
        ?leading,
        if (country != null)
          InfoChip(
            label: country,
            icon: Icons.public,
            countryCode: countryCode,
          ),
        if (years != null) InfoChip(label: years, icon: Icons.calendar_today),
      ],
    );
  }
}

/// The artist-page album order, as an icon button with a menu.
class AlbumSortMenuButton extends ConsumerWidget {
  const AlbumSortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(albumSortProvider);
    return PopupMenuButton<AlbumSortMode>(
      icon: const Icon(Icons.sort, size: 20),
      tooltip: 'Sort albums',
      onSelected: (mode) => ref.read(albumSortProvider.notifier).setMode(mode),
      itemBuilder: (_) => [
        for (final mode in AlbumSortMode.values)
          PopupMenuItem(
            value: mode,
            child: Row(
              children: [
                if (mode == current)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 16),
                  ),
                Text(mode.label),
              ],
            ),
          ),
      ],
    );
  }
}

/// Star rating and favorite for an artist, writing straight through and
/// refreshing the artist so the server stays the source of truth.
class ArtistRatingRow extends ConsumerWidget {
  const ArtistRatingRow({
    super.key,
    required this.artist,
    required this.artistId,
    this.size = 22,
  });

  final Artist artist;
  final String artistId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadedArtistIds =
        ref.watch(downloadedArtistIdsProvider).valueOrNull ?? const {};
    final anyDownloadedArtistIds =
        ref.watch(anyDownloadedArtistIdsProvider).valueOrNull ?? const {};
    final isFullyCached = downloadedArtistIds.contains(artist.id);
    final hasCachedContent = anyDownloadedArtistIds.contains(artist.id);
    final isPartiallyCached = hasCachedContent && !isFullyCached;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Both write through the repository: local first, then pushed, and the
        // stream carries the change back here. No invalidate — that refetched
        // the whole artist to see one flag change.
        StarRating(
          rating: artist.userRating ?? 0,
          size: size,
          onRatingChanged: (rating) async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setRating(
                  EntityRef(EntityType.artist, artist.id),
                  rating: rating,
                );
          },
        ),
        const SizedBox(width: 8),
        FavoriteButton(
          isFavorite: artist.starred,
          size: size,
          onToggle: () async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setFavorite(
                  EntityRef(EntityType.artist, artist.id),
                  favorite: !artist.starred,
                );
          },
        ),
        const SizedBox(width: 8),
        if (isFullyCached)
          HoverIcon(
            icon: Icons.offline_pin,
            size: size,
            color: theme.colorScheme.primary,
            tooltip: 'Remove artist from cache',
            onTap: () {
              ref.read(audioCacheServiceProvider).removeCachedArtist(artist.id);
              showCacheRemovedSnackBar(
                context,
                message: 'Removed "${artist.name}" from offline cache',
              );
            },
          )
        else if (isPartiallyCached) ...[
          HoverIcon(
            icon: Icons.download_for_offline_outlined,
            size: size,
            color: theme.colorScheme.primary,
            tooltip: 'Complete caching all albums',
            onTap: () {
              ref.read(audioCacheServiceProvider).cacheArtist(artist.id);
              showCachingSnackBar(
                context,
                message: 'Caching all albums for "${artist.name}"...',
              );
            },
          ),
          const SizedBox(width: 8),
          HoverIcon(
            icon: Icons.delete_outline,
            size: size,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: 'Remove cached albums',
            onTap: () {
              ref.read(audioCacheServiceProvider).removeCachedArtist(artist.id);
              showCacheRemovedSnackBar(
                context,
                message: 'Removed "${artist.name}" from offline cache',
              );
            },
          ),
        ] else
          HoverIcon(
            icon: Icons.download,
            size: size,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: 'Cache artist offline',
            onTap: () {
              ref.read(audioCacheServiceProvider).cacheArtist(artist.id);
              showCachingSnackBar(
                context,
                message: 'Caching all albums for "${artist.name}"...',
              );
            },
          ),
      ],
    );
  }
}
