import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// The artist column: who is playing, and what the server knows about them.
///
/// Deliberately wraps [ArtistPanelView] to separate Riverpod state from
/// presentational layout.
class ArtistPanel extends ConsumerWidget {
  const ArtistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((s) => s.currentSong));

    if (song == null || song.artistId == null) {
      return ArtistPanelView(
        artistName: song?.artistName ?? '',
        artistId: null,
      );
    }

    final artistId = song.artistId!;
    final artist = ref.watch(artistDetailProvider(artistId)).valueOrNull;
    final info = ref.watch(artistInfoProvider(artistId)).valueOrNull;

    return ArtistPanelView(
      artistName: song.artistName ?? artist?.name ?? '',
      artistId: artistId,
      imageUrl: info?.bestImageUrl ?? artist?.imageUrl,
      coverArtId: artist?.coverArtId,
      biography: info?.biography ?? artist?.biography,
      similarArtists: info?.similarArtists ?? const [],
      onArtistTap: (id) => context.push('/artists/$id'),
    );
  }
}

/// The presentational view for the artist panel.
///
/// Deliberately free of Riverpod providers or routers, so its layout, hover
/// affordances, and interaction can be tested directly without standing up
/// an audio engine or Subsonic server.
class ArtistPanelView extends StatelessWidget {
  final String artistName;
  final String? artistId;
  final String? imageUrl;
  final String? coverArtId;
  final String? biography;
  final List<SimilarArtist> similarArtists;
  final ValueChanged<String>? onArtistTap;

  const ArtistPanelView({
    super.key,
    required this.artistName,
    this.artistId,
    this.imageUrl,
    this.coverArtId,
    this.biography,
    this.similarArtists = const [],
    this.onArtistTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (artistId == null) {
      return Center(
        child: Text(
          artistName,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final hasBio = biography != null && biography!.trim().isNotEmpty;
    final hasSimilar = similarArtists.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: HoverArtwork(
            onTap: onArtistTap != null ? () => onArtistTap!(artistId!) : null,
            borderRadius: BorderRadius.circular(10),
            child: _buildHeroImage(imageUrl, coverArtId),
          ),
        ),
        const SizedBox(height: 12),
        HoverLink(
          text: artistName,
          maxLines: 2,
          onTap: onArtistTap != null ? () => onArtistTap!(artistId!) : null,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (hasBio) ...[
          const SizedBox(height: 12),
          Text(
            _stripMarkup(biography!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
        if (hasSimilar) ...[
          const SizedBox(height: 20),
          Text(
            'Similar Artists',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: similarArtists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final similar = similarArtists[index];
                return _SimilarArtistItem(
                  artist: similar,
                  onTap: onArtistTap != null
                      ? () => onArtistTap!(similar.id)
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroImage(String? imageUrl, String? coverArtId) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => coverArtId != null
            ? CoverArtImage(coverArtId: coverArtId, size: 600)
            : const _ArtistPlaceholder(),
        errorWidget: (_, _, _) => coverArtId != null
            ? CoverArtImage(coverArtId: coverArtId, size: 600)
            : const _ArtistPlaceholder(),
      );
    }
    if (coverArtId != null && coverArtId.isNotEmpty) {
      return CoverArtImage(coverArtId: coverArtId, size: 600);
    }
    return const _ArtistPlaceholder();
  }

  /// Biographies arrive with a trailing "Read more on Last.fm" anchor. Strip
  /// tags rather than render them — this panel has no room for a link farm.
  static String _stripMarkup(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+\n'), '\n')
      .trim();
}

class _ArtistPlaceholder extends StatelessWidget {
  const _ArtistPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SimilarArtistItem extends StatelessWidget {
  final SimilarArtist artist;
  final VoidCallback? onTap;

  const _SimilarArtistItem({required this.artist, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: HoverArtwork(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: _buildArtwork(artist.coverArtId),
            ),
          ),
          const SizedBox(height: 6),
          HoverLink(
            text: artist.name,
            maxLines: 2,
            onTap: onTap,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(String? coverArtId) {
    if (coverArtId == null || coverArtId.isEmpty) {
      return const CoverArtImage(size: 80);
    }
    if (coverArtId.startsWith('http://') || coverArtId.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: coverArtId,
        fit: BoxFit.cover,
        placeholder: (_, _) => const CoverArtImage(size: 80),
        errorWidget: (_, _, _) => const CoverArtImage(size: 80),
      );
    }
    return CoverArtImage(coverArtId: coverArtId, size: 80);
  }
}
