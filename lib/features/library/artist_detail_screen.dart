import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/musicbrainz/musicbrainz_service.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/country_chip.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/star_rating.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

// ── Sort enum ─────────────────────────────────────────────────────────

enum AlbumSortMode { yearAsc, yearDesc, title, rating }

// ── Providers ─────────────────────────────────────────────────────────

final artistDetailProvider =
    FutureProvider.family<Artist, String>((ref, id) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) throw Exception('No server');
  return client.getArtist(id);
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  final artist = await client.getArtist(artistId);
  final result = await client.search(artist.name,
      albumCount: 50, songCount: 0, artistCount: 0);
  return result.albums
      .where((a) => a.artistId == artistId || a.artistName == artist.name)
      .toList();
});

final artistInfoProvider =
    FutureProvider.family<ArtistInfo?, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return null;
  return client.getArtistInfoParsed(artistId);
});

final musicBrainzInfoProvider =
    FutureProvider.family<MusicBrainzArtistInfo?, String>((ref, artistId) async {
  // First try to get the MusicBrainz ID from Subsonic artist info
  final artistInfo = await ref.watch(artistInfoProvider(artistId).future);
  if (artistInfo?.musicBrainzId != null) {
    return MusicBrainzService.getArtistInfo(artistInfo!.musicBrainzId!);
  }
  // Fallback: search by artist name
  final artist = await ref.watch(artistDetailProvider(artistId).future);
  return MusicBrainzService.searchArtist(artist.name);
});

final _albumSortProvider = StateProvider<AlbumSortMode>((ref) => AlbumSortMode.yearAsc);

// ── Screen ────────────────────────────────────────────────────────────

class ArtistDetailScreen extends ConsumerWidget {
  final String artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  static bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  List<Album> _sortAlbums(List<Album> albums, AlbumSortMode mode) {
    final sorted = List<Album>.from(albums);
    switch (mode) {
      case AlbumSortMode.yearAsc:
        sorted.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
      case AlbumSortMode.yearDesc:
        sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case AlbumSortMode.title:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case AlbumSortMode.rating:
        sorted.sort((a, b) => (b.userRating ?? 0).compareTo(a.userRating ?? 0));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistDetailProvider(artistId));
    final albumsAsync = ref.watch(artistAlbumsProvider(artistId));
    final artistInfoAsync = ref.watch(artistInfoProvider(artistId));
    final mbInfoAsync = ref.watch(musicBrainzInfoProvider(artistId));
    final sortMode = ref.watch(_albumSortProvider);

    return Scaffold(
      body: artistAsync.when(
        data: (artist) {
          final artistInfo = artistInfoAsync.valueOrNull;
          final mbInfo = mbInfoAsync.valueOrNull;

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, artist, artistInfo),
              SliverToBoxAdapter(
                child: _ArtistActionsBar(artist: artist, artistId: artistId),
              ),
              if (_isDesktop)
                SliverToBoxAdapter(
                  child: _ArtistInfoPanel(
                    artist: artist,
                    artistInfo: artistInfo,
                    mbInfo: mbInfo,
                  ),
                ),
              SliverToBoxAdapter(
                child: _buildSortBar(context, ref, sortMode),
              ),
              albumsAsync.when(
                data: (albums) {
                  final sorted = _sortAlbums(albums, sortMode);
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
      BuildContext context, Artist artist, ArtistInfo? artistInfo) {
    final bgImage = artistInfo?.bestImageUrl;

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

  Widget _buildSortBar(
      BuildContext context, WidgetRef ref, AlbumSortMode current) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text('Albums',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          PopupMenuButton<AlbumSortMode>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: 'Sort albums',
            onSelected: (mode) =>
                ref.read(_albumSortProvider.notifier).state = mode,
            itemBuilder: (_) => [
              _sortItem(AlbumSortMode.yearAsc, 'Year (oldest first)', current),
              _sortItem(
                  AlbumSortMode.yearDesc, 'Year (newest first)', current),
              _sortItem(AlbumSortMode.title, 'Title', current),
              _sortItem(AlbumSortMode.rating, 'Rating', current),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<AlbumSortMode> _sortItem(
      AlbumSortMode value, String label, AlbumSortMode current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == current)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check, size: 16),
            ),
          Text(label),
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
    return AlbumContextMenu(
      album: album,
      child: ListTile(
        leading: HoverArtwork(
          onTap: () => context.push('/albums/${album.id}'),
          borderRadius: BorderRadius.circular(4),
          scale: 1.08,
          child: SizedBox(
            width: 48,
            height: 48,
            child: CoverArtImage(coverArtId: album.coverArtId, size: 48),
          ),
        ),
        title: Text(album.name),
        subtitle: Text(
          [
            if (album.year != null) '${album.year}',
            '${album.songCount} tracks',
            if (album.genre != null) album.genre!,
          ].join(' · '),
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
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              )
            : null,
        onTap: () => context.push('/albums/${album.id}'),
      ),
    );
  }
}

// ── Rich artist info panel (desktop) ──────────────────────────────────

class _ArtistInfoPanel extends StatefulWidget {
  final Artist artist;
  final ArtistInfo? artistInfo;
  final MusicBrainzArtistInfo? mbInfo;

  const _ArtistInfoPanel({
    required this.artist,
    this.artistInfo,
    this.mbInfo,
  });

  @override
  State<_ArtistInfoPanel> createState() => _ArtistInfoPanelState();
}

class _ArtistInfoPanelState extends State<_ArtistInfoPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.artistInfo;
    final mb = widget.mbInfo;

    if (info == null && mb == null) return const SizedBox.shrink();

    final chips = <Widget>[];

    // A flag where the country resolved, the globe where only an area name did.
    final countryLabel = mb?.countryLabel;
    if (countryLabel != null) {
      chips.add(InfoChip(
        label: countryLabel,
        icon: Icons.public,
        countryCode: mb?.countryCode,
      ));
    }
    // The Group/Person designation is deliberately not shown: it adds a chip
    // without telling you anything you cannot see from the artist itself.
    if (mb?.activeYears != null) {
      chips.add(InfoChip(
        label: mb!.activeYears!,
        icon: Icons.calendar_today,
      ));
    }

    final genres = mb?.tags ?? widget.artist.genres ?? [];

    // Clean up biography HTML
    final bio = _cleanBio(info?.biography);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Wrap(
              spacing: 14,
              runSpacing: 6,
              // Centre the chips against each other, so a chip whose leading
              // glyph is a different height does not ride high or low.
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: genres
                  .map((g) => Chip(
                        label: Text(g,
                            style: theme.textTheme.labelSmall),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topLeft,
                      child: Text(
                        bio,
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: HoverLink(
                        text: _expanded ? 'Show less' : 'Read more',
                        onTap: () => setState(() => _expanded = !_expanded),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }



  String? _cleanBio(String? html) {
    if (html == null || html.isEmpty) return null;
    // Strip HTML tags
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

/// Rating and favourite for the artist.
///
/// Navidrome exposes both for artists — a 0-5 rating and a separate favourite
/// flag — and Subsonic's setRating/star take an artist id like any other
/// entity, so nothing special is needed beyond a model field to read back.
class _ArtistActionsBar extends ConsumerWidget {
  const _ArtistActionsBar({required this.artist, required this.artistId});

  final Artist artist;
  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            '${artist.albumCount} '
            '${artist.albumCount == 1 ? "album" : "albums"}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          StarRating(
            rating: artist.userRating ?? 0,
            size: 20,
            onRatingChanged: (rating) async {
              final client = ref.read(subsonicClientProvider);
              if (client == null) return;
              await client.setRating(artist.id, rating);
              ref.invalidate(artistDetailProvider(artistId));
            },
          ),
          const SizedBox(width: 8),
          FavoriteButton(
            isFavorite: artist.starred,
            size: 20,
            onToggle: () async {
              final client = ref.read(subsonicClientProvider);
              if (client == null) return;
              if (artist.starred) {
                await client.unstar(artistId: artist.id);
              } else {
                await client.star(artistId: artist.id);
              }
              ref.invalidate(artistDetailProvider(artistId));
            },
          ),
        ],
      ),
    );
  }
}
