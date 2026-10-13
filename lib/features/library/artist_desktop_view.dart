import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/release_group.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_detail_screen.dart'
    show formatDuration;
import 'package:flax/features/library/album_sort.dart';
import 'package:flax/features/library/artist_albums_view.dart';
import 'package:flax/features/library/artist_songs.dart';
import 'package:flax/features/library/artist_widgets.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/album_grid_tile.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/genre_chips.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/similar_artist_tile.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';
import 'package:flax/shared/widgets/star_rating.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

/// Content width from which the artist page puts Popular and Similar artists
/// in a rail beside the discography. With the 220px sidebar that is a 1320px
/// window — a portrait 1440p monitor at 1x clears it.
const kArtistRailBreakpoint = 1100.0;

/// Width of that rail.
const kArtistRailWidth = 340.0;

const _railGap = 32.0;
const _gridSpacing = 12.0;
const _popularRowHeight = 52.0;
const _popularRows = 5;

/// The artist page on desktop: header, discography, and — when there is room
/// and a server to ask — Popular and Similar artists.
///
/// Everything that arrives late from a third party keeps its space reserved, or
/// lands in the rail, so the discography never moves under the pointer. The
/// biography, MusicBrainz details and similar artists come from slow lookups,
/// and a row moving mid-click is how a click lands on the wrong album.
class ArtistDesktopView extends ConsumerWidget {
  const ArtistDesktopView({
    super.key,
    required this.artist,
    required this.albums,
    required this.artistInfo,
    required this.mbInfo,
    required this.infoLoading,
    required this.topSongs,
    required this.offline,
  });

  final Artist artist;
  final AsyncValue<List<Album>> albums;
  final ArtistInfo? artistInfo;
  final MusicBrainzArtistInfo? mbInfo;
  final bool infoLoading;
  final AsyncValue<List<Song>> topSongs;
  final bool offline;

  static const railKey = Key('artist-rail');
  static const popularKey = Key('artist-popular');
  static const similarKey = Key('artist-similar');
  static const playKey = Key('artist-play');
  static const shuffleKey = Key('artist-shuffle');
  static const viewToggleKey = Key('artist-view-toggle');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortMode = ref.watch(albumSortProvider);
    final view = ref.watch(artistAlbumsViewProvider);
    final albumList = albums.valueOrNull;
    final groups = albumList == null
        ? const <(ReleaseGroup, List<Album>)>[]
        : groupReleases(sortAlbums(albumList, sortMode));
    final ordered = albumList == null
        ? null
        : [for (final (_, group) in groups) ...group];

    final songs = offline ? const <Song>[] : topSongs.valueOrNull ?? const [];
    final songsLoading = !offline && topSongs.isLoading && !topSongs.hasValue;
    final similar = offline
        ? const <SimilarArtist>[]
        : artistInfo?.similarInLibrary ?? const <SimilarArtist>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Decided from the width and offline state alone, never from what the
        // lookups return: the rail collapsing once they came back empty would
        // re-flow the whole discography under the pointer.
        final wide = !offline && constraints.maxWidth >= kArtistRailBreakpoint;

        final header = SliverToBoxAdapter(
          child: _DesktopHeader(
            artist: artist,
            albums: ordered,
            artistInfo: artistInfo,
            mbInfo: mbInfo,
            infoLoading: infoLoading,
            offline: offline,
          ),
        );
        final popular = (songsLoading || songs.isNotEmpty)
            ? _PopularSection(
                key: popularKey,
                songs: songs,
                loading: songsLoading,
                columnar: !wide,
              )
            : null;

        final main = <Widget>[
          header,
          if (!wide && popular != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: popular,
              ),
            ),
          SliverToBoxAdapter(child: _DiscographyToolbar(view: view)),
          ..._discographySlivers(context, groups, view),
          if (!wide && similar.isNotEmpty)
            SliverToBoxAdapter(
              child: _SimilarArtists(
                key: similarKey,
                artists: similar,
                shelf: true,
              ),
            ),
        ];

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 24, 0),
                // See UpBackButton: pops when it can, otherwise goes up to the
                // list of artists rather than disappearing.
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: UpBackButton(fallbackLocation: '/artists'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
              sliver: wide
                  ? SliverCrossAxisGroup(
                      slivers: [
                        SliverCrossAxisExpanded(
                          flex: 1,
                          sliver: SliverMainAxisGroup(slivers: main),
                        ),
                        const SliverConstrainedCrossAxis(
                          maxExtent: _railGap,
                          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                        ),
                        SliverConstrainedCrossAxis(
                          maxExtent: kArtistRailWidth,
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              key: railKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ?popular,
                                if (similar.isNotEmpty)
                                  _SimilarArtists(
                                    key: similarKey,
                                    artists: similar,
                                    shelf: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : SliverMainAxisGroup(slivers: main),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _discographySlivers(
    BuildContext context,
    List<(ReleaseGroup, List<Album>)> groups,
    ArtistAlbumsView view,
  ) {
    if (albums.hasError && !albums.hasValue) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Error: ${albums.error}')),
          ),
        ),
      ];
    }
    if (!albums.hasValue) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final headed = groups.length > 1;
    return [
      if (view == ArtistAlbumsView.list)
        const SliverToBoxAdapter(child: _AlbumListHeader()),
      for (final (group, list) in groups) ...[
        SliverToBoxAdapter(
          child: headed
              ? _GroupHeading(group: group, count: list.length)
              : const SizedBox(height: 16),
        ),
        if (view == ArtistAlbumsView.grid)
          _AlbumGridSliver(albums: list)
        else
          _AlbumListSliver(albums: list),
      ],
    ];
  }
}

/// The artist's genres as the library tags their albums: each album counts
/// once per genre, most common first, ties alphabetical, the first spelling
/// kept.
///
/// Library genres rather than MusicBrainz tags, because these are what a
/// genre page can list.
List<String> artistLibraryGenres(List<Album> albums) {
  final counts = <String, int>{};
  final spelling = <String, String>{};
  for (final album in albums) {
    final seen = <String>{};
    for (final genre in album.displayGenres) {
      final key = genre.toLowerCase();
      if (!seen.add(key)) continue;
      spelling.putIfAbsent(key, () => genre);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final key in keys) spelling[key]!];
}

/// A biography as served, without its markup.
String? cleanArtistBio(String? html) {
  if (html == null || html.isEmpty) return null;
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
  return text.isEmpty ? null : text;
}

/// The whole biography, for when three lines in the header are not enough.
Future<void> showArtistBiography(
  BuildContext context, {
  required String artistName,
  required String biography,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.aboutEyebrow ?? 'ABOUT',
                  style: _eyebrowStyle(theme),
                ),
                const SizedBox(height: 2),
                Text(
                  artistName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      biography,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

TextStyle? _eyebrowStyle(ThemeData theme) =>
    theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
    );

TextStyle? _sectionTitleStyle(ThemeData theme) => theme.textTheme.titleMedium
    ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700);

// ── Header ────────────────────────────────────────────────────────────

/// Photo beside the artist's name, details, actions and biography.
///
/// Every row fed by a lookup has a fixed height, filled or not, so the header
/// is as tall before its data arrives as after.
class _DesktopHeader extends ConsumerStatefulWidget {
  const _DesktopHeader({
    required this.artist,
    required this.albums,
    required this.artistInfo,
    required this.mbInfo,
    required this.infoLoading,
    required this.offline,
  });

  final Artist artist;

  /// The discography in page order, or null while it loads.
  final List<Album>? albums;
  final ArtistInfo? artistInfo;
  final MusicBrainzArtistInfo? mbInfo;
  final bool infoLoading;
  final bool offline;

  @override
  ConsumerState<_DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends ConsumerState<_DesktopHeader> {
  /// Which button is loading songs: null when neither.
  bool? _shuffling;

  Future<void> _play({required bool shuffle}) async {
    final repo = ref.read(libraryRepositoryProvider);
    final albums = widget.albums;
    if (repo == null || albums == null || albums.isEmpty) return;
    final offline = ref.read(isOfflineModeProvider);
    final autoSwitch = ref
        .read(playbackSettingsProvider)
        .autoSwitchToNowPlaying;
    final player = ref.read(playerProvider.notifier);

    setState(() => _shuffling = shuffle);
    try {
      final songs = await loadArtistSongs(repo, albums, offline: offline);
      if (songs.isEmpty) return;
      // The player's shuffle flag does not reorder anything yet, so the order
      // is shuffled here.
      if (shuffle) songs.shuffle();
      await player.replaceQueue(songs);
      if (autoSwitch && mounted) context.push('/now-playing');
    } finally {
      if (mounted) setState(() => _shuffling = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final artist = widget.artist;
    final albums = widget.albums;
    final mbInfo = widget.mbInfo;

    final count = widget.offline && albums != null
        ? l10n?.releasesDownloaded(albums.length, artist.albumCount) ??
              '${albums.length} of ${artist.albumCount} releases downloaded'
        : l10n?.releaseCount(artist.albumCount) ??
              '${artist.albumCount} releases';
    final countText = Text(
      count,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final detailsPending =
        widget.infoLoading &&
        mbInfo == null &&
        artist.countryCode == null &&
        artist.country == null &&
        artist.activeYears == null;

    final busy = _shuffling != null;
    final canPlay = albums != null && albums.isNotEmpty && !busy;
    Widget buttonIcon(IconData icon, {required bool forShuffle}) =>
        _shuffling == forShuffle
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18);

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.artistEyebrow ?? 'ARTIST', style: _eyebrowStyle(theme)),
        const SizedBox(height: 4),
        Text(
          artist.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        // Reserved whether or not MusicBrainz has answered, which can take
        // seconds; clipped so a second line can never grow it.
        SizedBox(
          height: 22,
          child: ClipRect(
            child: detailsPending
                ? Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      countText,
                      const SizedBox(
                        width: 180,
                        child: ArtistLoadingBar(width: 180),
                      ),
                    ],
                  )
                : ArtistInfoChips(
                    mbInfo: mbInfo,
                    artist: artist,
                    leading: countText,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: GenreChipSize.regular.height,
          child: GenreChips(
            genres: artistLibraryGenres(albums ?? const []),
            singleLine: true,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: ArtistDesktopView.playKey,
              onPressed: canPlay ? () => _play(shuffle: false) : null,
              icon: buttonIcon(Icons.play_arrow, forShuffle: false),
              label: Text(l10n?.play ?? 'Play'),
            ),
            OutlinedButton.icon(
              key: ArtistDesktopView.shuffleKey,
              onPressed: canPlay ? () => _play(shuffle: true) : null,
              icon: buttonIcon(Icons.shuffle, forShuffle: true),
              label: Text(l10n?.shuffle ?? 'Shuffle'),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ArtistRatingRow(artist: artist, artistId: artist.id),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Biography(
          artistName: artist.name,
          biography: cleanArtistBio(
            widget.artistInfo?.biography ?? artist.biography,
          ),
          loading: widget.infoLoading,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // A narrow window keeps more of its width for the name and buttons.
        final imageSize = constraints.maxWidth < 600 ? 160.0 : 224.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArtistImage(
              size: imageSize,
              remoteImageUrl:
                  widget.artistInfo?.bestImageUrl ?? artist.imageUrl,
              coverArtId: artist.coverArtId,
            ),
            const SizedBox(width: 24),
            Expanded(child: identity),
          ],
        );
      },
    );
  }
}

/// Three lines of biography and Read more, always the same height.
///
/// Holds three lines and the link whether the biography is there, still
/// loading, or missing altogether, so the discography under it never moves.
class _Biography extends StatelessWidget {
  const _Biography({
    required this.artistName,
    required this.biography,
    required this.loading,
  });

  final String artistName;
  final String? biography;
  final bool loading;

  static const maxWidth = 680.0;
  static const maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 20 / 13,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final text = biography;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated =
              text != null &&
              _exceedsLines(
                text,
                style,
                constraints.maxWidth,
                MediaQuery.textScalerOf(context),
                Directionality.of(context),
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // Three empty lines in the same style: the block's height.
                  Text('\n' * (maxLines - 1), style: style),
                  if (text != null)
                    Text(
                      text,
                      style: style,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (loading)
                    const Positioned.fill(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ArtistLoadingBar(width: 560),
                          ArtistLoadingBar(width: 600),
                          ArtistLoadingBar(width: 380),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Visibility(
                visible: truncated,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: HoverLink(
                  text: l10n?.readMore ?? 'Read more',
                  onTap: text == null
                      ? null
                      : () => showArtistBiography(
                          context,
                          artistName: artistName,
                          biography: text,
                        ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _exceedsLines(
    String text,
    TextStyle? style,
    double width,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }
}

/// The artist photo, contained rather than cropped.
///
/// Prefers the remote image from artist info, falling back to the server's own
/// cover art, and to a placeholder when there is neither — so the box is always
/// the same size and nothing below it moves once an image resolves. A banner
/// cropped a square publicity photo to a strip, and controls drawn over it
/// vanished against a pale one.
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

// ── Discography ───────────────────────────────────────────────────────

class _DiscographyToolbar extends ConsumerWidget {
  const _DiscographyToolbar({required this.view});

  final ArtistAlbumsView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n?.discography ?? 'Discography',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SegmentedButton<ArtistAlbumsView>(
                key: ArtistDesktopView.viewToggleKey,
                segments: [
                  ButtonSegment(
                    value: ArtistAlbumsView.grid,
                    icon: const Icon(Icons.grid_view, size: 18),
                    tooltip: l10n?.viewGrid ?? 'Grid',
                  ),
                  ButtonSegment(
                    value: ArtistAlbumsView.list,
                    icon: const Icon(Icons.view_list, size: 18),
                    tooltip: l10n?.viewList ?? 'List',
                  ),
                ],
                selected: {view},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(artistAlbumsViewProvider.notifier)
                    .setView(selection.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              const AlbumSortMenuButton(),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

String releaseGroupLabel(
  ReleaseGroup group,
  AppLocalizations? l10n,
) => switch (group) {
  ReleaseGroup.albums => l10n?.releaseGroupAlbums ?? 'Albums',
  ReleaseGroup.epsAndSingles => l10n?.releaseGroupEpsSingles ?? 'EPs & Singles',
  ReleaseGroup.live => l10n?.releaseGroupLive ?? 'Live',
  ReleaseGroup.compilations => l10n?.releaseGroupCompilations ?? 'Compilations',
  ReleaseGroup.other => l10n?.releaseGroupOther ?? 'Other releases',
};

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.group, required this.count});

  final ReleaseGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              releaseGroupLabel(group, AppLocalizations.of(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One group's covers, laid out like the Albums grid: square art plus a fixed
/// label height, so the art is never cropped.
class _AlbumGridSliver extends ConsumerWidget {
  const _AlbumGridSliver({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded =
        ref.watch(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final anyDownloaded =
        ref.watch(anyDownloadedAlbumIdsProvider).valueOrNull ?? const {};
    final maxExtent = artGridExtent(context);
    final labelExtent = artGridLabelExtent(context);

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = artGridTileWidth(
          constraints.crossAxisExtent,
          maxExtent,
          _gridSpacing,
        );
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileWidth + labelExtent,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final album = albums[index];
            final full = downloaded.contains(album.id);
            return AlbumGridTile(
              album: album,
              fullyCached: full,
              partiallyCached: anyDownloaded.contains(album.id) && !full,
              secondLine: _TileDetails(album: album),
            );
          }, childCount: albums.length),
        );
      },
    );
  }
}

/// Year and track count under a cover, with the rating when there is one.
/// The artist would be the same on every tile of this page.
class _TileDetails extends StatelessWidget {
  const _TileDetails({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rating = album.userRating ?? 0;
    final details = [
      if (album.year != null) '${album.year}',
      l10n?.trackCount(album.songCount) ?? '${album.songCount} tracks',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
        if (rating > 0) _Stars(rating: rating, size: 11),
      ],
    );
  }
}

/// A read-only rating, for places too small for [StarRating].
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final faint = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    return Semantics(
      label: '$rating / 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < rating ? Icons.star : Icons.star_border,
              size: size,
              color: i < rating ? Colors.amber : faint,
            ),
        ],
      ),
    );
  }
}

/// Which list columns fit: the title, rating and favorite always do.
class _ListColumns {
  const _ListColumns(this.year, this.counts);

  factory _ListColumns.forWidth(double width) =>
      _ListColumns(width >= 520, width >= 640);

  final bool year;
  final bool counts;

  static const art = 64.0;
  static const yearWidth = 48.0;
  static const tracksWidth = 56.0;
  static const lengthWidth = 64.0;
  static const ratingWidth = 96.0;
  static const favoriteWidth = 28.0;
  static const gap = 16.0;
}

class _AlbumListHeader extends StatelessWidget {
  const _AlbumListHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );
    // Scaled down rather than clipped: some translations run past a column.
    Widget label(String text, double width, {bool end = false}) => SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _ListColumns.forWidth(constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
          child: Row(
            children: [
              const SizedBox(width: _ListColumns.art + _ListColumns.gap),
              Expanded(child: Text(l10n?.columnTitle ?? 'TITLE', style: style)),
              if (columns.year) ...[
                const SizedBox(width: _ListColumns.gap),
                label(
                  l10n?.columnYear ?? 'YEAR',
                  _ListColumns.yearWidth,
                  end: true,
                ),
              ],
              if (columns.counts) ...[
                const SizedBox(width: _ListColumns.gap),
                label(
                  l10n?.columnTracks ?? 'TRACKS',
                  _ListColumns.tracksWidth,
                  end: true,
                ),
                const SizedBox(width: _ListColumns.gap),
                label(
                  l10n?.columnLength ?? 'LENGTH',
                  _ListColumns.lengthWidth,
                  end: true,
                ),
              ],
              const SizedBox(width: _ListColumns.gap + 8),
              label(l10n?.columnRating ?? 'RATING', _ListColumns.ratingWidth),
              const SizedBox(width: _ListColumns.favoriteWidth),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumListSliver extends ConsumerWidget {
  const _AlbumListSliver({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded =
        ref.watch(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final anyDownloaded =
        ref.watch(anyDownloadedAlbumIdsProvider).valueOrNull ?? const {};
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _ListColumns.forWidth(constraints.crossAxisExtent);
        return SliverList.builder(
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final full = downloaded.contains(album.id);
            return _AlbumListRow(
              album: album,
              columns: columns,
              fullyCached: full,
              partiallyCached: anyDownloaded.contains(album.id) && !full,
            );
          },
        );
      },
    );
  }
}

/// One release as a table row: 64px art, title, year, tracks, length, and the
/// album's own rating and favorite.
class _AlbumListRow extends ConsumerWidget {
  const _AlbumListRow({
    required this.album,
    required this.columns,
    required this.fullyCached,
    required this.partiallyCached,
  });

  final Album album;
  final _ListColumns columns;
  final bool fullyCached;
  final bool partiallyCached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final numberStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: numberStyle,
      ),
    );

    return AlbumContextMenu(
      album: album,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            // Only the part that opens the album is the hover surface: an
            // ancestor InkWell would beat the rating and heart to their taps.
            Expanded(
              child: HoverSurface(
                onTap: () => context.push('/albums/${album.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _ListArt(
                        album: album,
                        fullyCached: fullyCached,
                        partiallyCached: partiallyCached,
                      ),
                      const SizedBox(width: _ListColumns.gap),
                      Expanded(
                        child: Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (columns.year) ...[
                        const SizedBox(width: _ListColumns.gap),
                        cell(
                          album.year?.toString() ?? '',
                          _ListColumns.yearWidth,
                        ),
                      ],
                      if (columns.counts) ...[
                        const SizedBox(width: _ListColumns.gap),
                        cell('${album.songCount}', _ListColumns.tracksWidth),
                        const SizedBox(width: _ListColumns.gap),
                        cell(
                          formatDuration(album.duration),
                          _ListColumns.lengthWidth,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: _ListColumns.gap),
            SizedBox(
              width: _ListColumns.ratingWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StarRating(
                  rating: album.userRating ?? 0,
                  size: 16,
                  onRatingChanged: (rating) => ref
                      .read(libraryRepositoryProvider)
                      ?.setRating(
                        EntityRef(EntityType.album, album.id),
                        rating: rating,
                      ),
                ),
              ),
            ),
            SizedBox(
              width: _ListColumns.favoriteWidth,
              child: FavoriteButton(
                isFavorite: album.starred,
                size: 18,
                onToggle: () => ref
                    .read(libraryRepositoryProvider)
                    ?.setFavorite(
                      EntityRef(EntityType.album, album.id),
                      favorite: !album.starred,
                    ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _ListArt extends StatelessWidget {
  const _ListArt({
    required this.album,
    required this.fullyCached,
    required this.partiallyCached,
  });

  final Album album;
  final bool fullyCached;
  final bool partiallyCached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _ListColumns.art,
      height: _ListColumns.art,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CoverArtImage(
              coverArtId: album.coverArtId,
              size: _ListColumns.art,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          if (fullyCached || partiallyCached)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  fullyCached ? Icons.offline_pin : Icons.offline_pin_outlined,
                  size: 13,
                  color: fullyCached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Popular ───────────────────────────────────────────────────────────

/// The artist's most popular songs. In the rail, one column of up to ten;
/// [columnar] under the header, columns of five side by side as they fit.
class _PopularSection extends ConsumerWidget {
  const _PopularSection({
    super.key,
    required this.songs,
    required this.loading,
    required this.columnar,
  });

  final List<Song> songs;
  final bool loading;
  final bool columnar;

  static const _maxSongs = 10;
  static const _minColumnWidth = 320.0;
  static const _columnGap = 24.0;

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<Song> list,
    int index,
  ) async {
    final autoSwitch = ref
        .read(playbackSettingsProvider)
        .autoSwitchToNowPlaying;
    await ref
        .read(playerProvider.notifier)
        .playTracks(list, initialIndex: index);
    if (autoSwitch && context.mounted) context.push('/now-playing');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final list = songs.take(_maxSongs).toList();

    Widget row(int index) => loading
        ? const _PopularPlaceholder()
        : _PopularRow(
            song: list[index],
            rank: index + 1,
            onTap: () => _play(context, ref, list, index),
          );

    final Widget rows;
    if (!columnar) {
      rows = Column(
        children: [
          for (var i = 0; i < (loading ? _popularRows : list.length); i++)
            row(i),
        ],
      );
    } else {
      rows = LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 2 * _minColumnWidth + _columnGap ? 2 : 1;
          final shown = loading
              ? _popularRows * columns
              : list.length.clamp(0, _popularRows * columns);
          return ConstrainedBox(
            // Five rows' height from the start, so the songs arriving do not
            // push the discography down.
            constraints: const BoxConstraints(
              minHeight: _popularRows * _popularRowHeight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _columnGap),
                  Expanded(
                    child: Column(
                      children: [
                        for (
                          var i = c * _popularRows;
                          i < shown && i < (c + 1) * _popularRows;
                          i++
                        )
                          row(i),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.popular ?? 'Popular', style: _sectionTitleStyle(theme)),
        const SizedBox(height: 8),
        // The rows' own padding lines their text up with the heading.
        Transform.translate(offset: const Offset(-8, 0), child: rows),
      ],
    );
  }
}

class _PopularRow extends ConsumerWidget {
  const _PopularRow({
    required this.song,
    required this.rank,
    required this.onTap,
  });

  final Song song;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playing = ref.watch(
      playerProvider.select((s) => s.currentSong?.id == song.id),
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final albumName = song.albumName;
    final albumId = song.albumId;

    return SongContextMenu(
      song: song,
      child: HoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: _popularRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: playing
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.volume_up,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Text('$rank', textAlign: TextAlign.right, style: muted),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CoverArtImage(
                    coverArtId: song.coverArtId,
                    size: 40,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: playing
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: playing ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (albumName != null)
                        HoverLink(
                          text: albumName,
                          onTap: albumId == null
                              ? null
                              : () => context.push('/albums/$albumId'),
                          style: muted?.copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatDuration(song.duration), style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularPlaceholder extends StatelessWidget {
  const _PopularPlaceholder();

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.12);
    return SizedBox(
      height: _popularRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 34),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: ArtistLoadingBar(width: double.infinity),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Similar artists ───────────────────────────────────────────────────

/// Similar artists in the library: a three-across grid in the rail, or a
/// [shelf] that scrolls sideways at the foot of a narrower page.
class _SimilarArtists extends StatelessWidget {
  const _SimilarArtists({
    super.key,
    required this.artists,
    required this.shelf,
  });

  final List<SimilarArtist> artists;
  final bool shelf;

  static const _railMax = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    void open(SimilarArtist artist) => context.push('/artists/${artist.id}');

    final Widget body;
    if (shelf) {
      body = SizedBox(
        height: 136,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: artists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) => SimilarArtistTile(
            artist: artists[index],
            size: 96,
            circular: true,
            onTap: () => open(artists[index]),
          ),
        ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final cell = (constraints.maxWidth - 2 * spacing) / 3;
          return Wrap(
            spacing: spacing,
            runSpacing: 18,
            children: [
              for (final artist in artists.take(_railMax))
                SizedBox(
                  width: cell,
                  child: Center(
                    child: SimilarArtistTile(
                      artist: artist,
                      size: 88,
                      circular: true,
                      onTap: () => open(artist),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: shelf ? 36 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.similarArtists ?? 'Similar artists',
            style: _sectionTitleStyle(theme),
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}
