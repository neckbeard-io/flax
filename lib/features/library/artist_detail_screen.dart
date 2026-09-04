import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_sort.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/musicbrainz/musicbrainz_service.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/country_chip.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/star_rating.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
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
    final cached = await repo.watchArtist(id).first;
    if (cached == null) {
      await repo.refreshArtist(id);
    } else {
      repo.refreshArtist(id);
    }
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
  if (cached.isEmpty) {
    await repo.refreshArtist(artistId);
  } else {
    repo.refreshArtist(artistId);
  }

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

final musicBrainzInfoProvider =
    FutureProvider.family<MusicBrainzArtistInfo?, String>((
      ref,
      artistId,
    ) async {
      // Order matters for latency. This used to await artistInfoProvider first,
      // which is Navidrome's getArtistInfo2 — and Navidrome fetches that from
      // Last.fm — so the MusicBrainz request could not even start until a slow
      // third-party call had returned, putting two of them in series. getArtist is
      // a plain local Navidrome lookup and already parses musicBrainzId, so start
      // from that instead and only fall back to the slow path when it is absent.
      final artist = await ref.watch(artistDetailProvider(artistId).future);
      if (artist.musicBrainzId != null) {
        return MusicBrainzService.getArtistInfo(artist.musicBrainzId!);
      }

      final artistInfo = await ref.watch(artistInfoProvider(artistId).future);
      if (artistInfo?.musicBrainzId != null) {
        return MusicBrainzService.getArtistInfo(artistInfo!.musicBrainzId!);
      }
      return MusicBrainzService.searchArtist(artist.name);
    });

// ── Screen ────────────────────────────────────────────────────────────

class ArtistDetailScreen extends ConsumerWidget {
  final String artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  static bool get _isDesktop => isDesktopPlatform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistDetailProvider(artistId));
    final albumsAsync = ref.watch(artistAlbumsProvider(artistId));
    final artistInfoAsync = ref.watch(artistInfoProvider(artistId));
    final mbInfoAsync = ref.watch(musicBrainzInfoProvider(artistId));
    final sortMode = ref.watch(albumSortProvider);

    return Scaffold(
      body: artistAsync.when(
        data: (artist) {
          final artistInfo = artistInfoAsync.valueOrNull;
          final mbInfo = mbInfoAsync.valueOrNull;

          // Desktop shows the artist image contained beside the details rather
          // than cropped into a banner behind them. A square photo stretched
          // across a wide window shows a torso and loses the face, and text and
          // controls drawn over arbitrary artwork are unreadable against light
          // images — the back button vanished entirely against a pale one.
          final infoLoading =
              artistInfoAsync.isLoading || mbInfoAsync.isLoading;
          return CustomScrollView(
            slivers: [
              if (_isDesktop)
                SliverToBoxAdapter(
                  child: _DesktopArtistHeader(
                    artist: artist,
                    artistId: artistId,
                    artistInfo: artistInfo,
                    mbInfo: mbInfo,
                    infoLoading: infoLoading,
                  ),
                ),
              if (_isDesktop)
                SliverToBoxAdapter(
                  child: _ArtistInfoPanel(
                    artist: artist,
                    artistInfo: artistInfo,
                    mbInfo: mbInfo,
                    infoLoading: infoLoading,
                  ),
                )
              else ...[
                _buildAppBar(context, artist, artistInfo),
                SliverToBoxAdapter(
                  child: _ArtistActionsBar(artist: artist, artistId: artistId),
                ),
              ],
              SliverToBoxAdapter(child: _buildSortBar(context, ref, sortMode)),
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

  Widget _buildSortBar(
    BuildContext context,
    WidgetRef ref,
    AlbumSortMode current,
  ) {
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
          PopupMenuButton<AlbumSortMode>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: 'Sort albums',
            onSelected: (mode) =>
                ref.read(albumSortProvider.notifier).setMode(mode),
            itemBuilder: (_) => [
              for (final mode in AlbumSortMode.values) _sortItem(mode, current),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<AlbumSortMode> _sortItem(
    AlbumSortMode value,
    AlbumSortMode current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == current)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check, size: 16),
            ),
          Text(value.label),
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

// ── Rich artist info panel (desktop) ──────────────────────────────────

class _ArtistInfoPanel extends StatefulWidget {
  final Artist artist;
  final ArtistInfo? artistInfo;
  final MusicBrainzArtistInfo? mbInfo;
  final bool infoLoading;

  const _ArtistInfoPanel({
    required this.artist,
    this.artistInfo,
    this.mbInfo,
    this.infoLoading = false,
  });

  @override
  State<_ArtistInfoPanel> createState() => _ArtistInfoPanelState();
}

class _ArtistInfoPanelState extends State<_ArtistInfoPanel> {
  bool _expanded = false;

  /// Height the collapsed panel always occupies: genre chips, three lines of
  /// biography, and the Read more affordance.
  ///
  /// Fixed rather than intrinsic because the two lookups feeding it are slow
  /// and arrive separately. Sizing to content meant the panel grew as each one
  /// landed and pushed the album list down — a row moving out from under the
  /// pointer mid-click. Expanding is a deliberate act and may grow past this.
  static const _collapsedHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.artistInfo;
    final mb = widget.mbInfo;

    final genres = mb?.tags ?? widget.artist.genres ?? [];

    // Clean up biography HTML
    final bio = _cleanBio(info?.biography ?? widget.artist.biography);

    // While the bio is still in flight, hold the space three lines of it will
    // occupy. Letting the panel collapse and then expand shifted the album list
    // downward mid-click, which is how a click lands on the wrong album.
    if (widget.infoLoading && (bio == null || bio.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SizedBox(
          height: _collapsedHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBar(width: 90, height: 24),
              SizedBox(height: 12),
              _LoadingBar(width: 620, height: 12),
              SizedBox(height: 10),
              _LoadingBar(width: 660, height: 12),
              SizedBox(height: 10),
              _LoadingBar(width: 420, height: 12),
            ],
          ),
        ),
      );
    }

    if (info == null && mb == null) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country and years live in the header; this panel is genres and bio.
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: genres
                .map(
                  (g) => Chip(
                    label: Text(g, style: theme.textTheme.labelSmall),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                )
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
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: _expanded
          ? content
          // Clipped to a constant height while collapsed so the panel is the
          // same size before and after its data arrives.
          : SizedBox(
              height: _collapsedHeight,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: content,
                ),
              ),
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

/// Rating and favorite for the artist.
///
/// Navidrome exposes both for artists — a 0-5 rating and a separate favorite
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
          _ArtistRatingRow(artist: artist, artistId: artistId, size: 20),
        ],
      ),
    );
  }
}

/// Desktop artist header: contained square image beside the details.
///
/// Replaces the full-bleed banner, which cropped a square publicity photo down
/// to a strip and forced text and buttons on top of arbitrary artwork. Against a
/// pale image the back button became invisible, and no amount of scrim tuning
/// fixes that reliably for every photo in a library.
class _DesktopArtistHeader extends ConsumerWidget {
  const _DesktopArtistHeader({
    required this.artist,
    required this.artistId,
    required this.artistInfo,
    required this.mbInfo,
    required this.infoLoading,
  });

  final Artist artist;
  final String artistId;
  final ArtistInfo? artistInfo;
  final MusicBrainzArtistInfo? mbInfo;
  final bool infoLoading;

  static const _imageSize = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remoteImage = artistInfo?.bestImageUrl ?? artist.imageUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // See UpBackButton: pops when it can, otherwise goes up to the list
          // of artists rather than disappearing.
          const UpBackButton(fallbackLocation: '/artists'),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ArtistImage(
                  size: _imageSize,
                  remoteImageUrl: remoteImage,
                  coverArtId: artist.coverArtId,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARTIST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist.name,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${artist.albumCount} '
                        '${artist.albumCount == 1 ? "album" : "albums"}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Reserved whether or not the metadata has arrived, so the
                      // album list below does not shift under the pointer when
                      // it does. Two third-party lookups feed this and either
                      // can take seconds.
                      SizedBox(
                        height: 22,
                        child: infoLoading && mbInfo == null
                            ? const _LoadingBar(width: 220)
                            : _ArtistChips(mbInfo: mbInfo),
                      ),
                      const SizedBox(height: 12),
                      _ArtistRatingRow(artist: artist, artistId: artistId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The artist photo, contained rather than cropped.
///
/// Prefers the remote image from artist info, falling back to the server's own
/// cover art, and to a placeholder when there is neither — so the box is always
/// the same size and nothing below it moves once an image resolves.
class _ArtistImage extends StatelessWidget {
  const _ArtistImage({
    required this.size,
    required this.remoteImageUrl,
    required this.coverArtId,
  });

  final double size;
  final String? remoteImageUrl;
  final String? coverArtId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);

    Widget fallback() => coverArtId != null
        ? CoverArtImage(coverArtId: coverArtId, borderRadius: radius)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: Center(
              child: Icon(
                Icons.person,
                size: size * 0.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );

    return SizedBox(
      width: size,
      height: size,
      child: remoteImageUrl == null
          ? fallback()
          : ClipRRect(
              borderRadius: radius,
              child: CachedNetworkImage(
                imageUrl: remoteImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              ),
            ),
    );
  }
}

/// Placeholder occupying the space a not-yet-loaded value will fill.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, this.height = 12});

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
class _ArtistChips extends StatelessWidget {
  const _ArtistChips({required this.mbInfo});

  final MusicBrainzArtistInfo? mbInfo;

  @override
  Widget build(BuildContext context) {
    final mb = mbInfo;
    final country = mb?.countryLabel;
    final years = mb?.activeYears;
    if (country == null && years == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (country != null)
          InfoChip(
            label: country,
            icon: Icons.public,
            countryCode: mb?.countryCode,
          ),
        if (years != null) InfoChip(label: years, icon: Icons.calendar_today),
      ],
    );
  }
}

/// Star rating and favorite for an artist, writing straight through and
/// refreshing the artist so the server stays the source of truth.
class _ArtistRatingRow extends ConsumerWidget {
  const _ArtistRatingRow({
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${artist.name}" from offline cache'),
                  duration: const Duration(seconds: 2),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Caching all albums for "${artist.name}"...'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () => context.push('/downloads'),
                  ),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${artist.name}" from offline cache'),
                  duration: const Duration(seconds: 2),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Caching all albums for "${artist.name}"...'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () => context.push('/downloads'),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
