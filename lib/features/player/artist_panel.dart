import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// The artist column: who is playing, and what the server knows about them.
///
/// Deliberately thin for now — image, name and biography, all from data the
/// artist screen already fetches. Where the biography *comes from* is an open
/// question (Navidrome's text is not Last.fm's), so the text is kept in one
/// place here rather than woven through the layout.
class ArtistPanel extends ConsumerWidget {
  const ArtistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    final theme = Theme.of(context);

    if (song == null || song.artistId == null) {
      return Center(
        child: Text(
          song?.artistName ?? '',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final artistId = song.artistId!;
    final info = ref.watch(artistInfoProvider(artistId)).valueOrNull;
    final imageUrl = info?.bestImageUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: HoverArtwork(
            onTap: () => context.push('/artists/$artistId'),
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        CoverArtImage(coverArtId: song.coverArtId, size: 600),
                  )
                : CoverArtImage(coverArtId: song.coverArtId, size: 600),
          ),
        ),
        const SizedBox(height: 12),
        HoverLink(
          text: song.artistName ?? '',
          maxLines: 2,
          onTap: () => context.push('/artists/$artistId'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (info?.biography != null && info!.biography!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _stripMarkup(info.biography!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  /// Biographies arrive with a trailing "Read more on Last.fm" anchor. Strip
  /// tags rather than render them — this panel has no room for a link farm.
  static String _stripMarkup(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+\n'), '\n')
      .trim();
}
