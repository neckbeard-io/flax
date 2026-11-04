import 'package:flutter/material.dart';

import 'package:flax/domain/models/song.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

/// A run of consecutive tracks from one album in a list of mixed tracks.
class AlbumGroup {
  AlbumGroup({
    required this.albumKey,
    this.albumName,
    this.artistName,
    this.coverArtId,
    this.year,
    required this.songs,
  });

  final String albumKey;
  final String? albumName;
  final String? artistName;
  final String? coverArtId;
  final int? year;
  final List<Song> songs;

  int get totalDuration => songs.fold(0, (sum, s) => sum + s.duration);
}

/// Splits [songs] wherever the album changes, keeping their order. An album that
/// comes back later in the list starts a new group.
List<AlbumGroup> groupByAlbum(List<Song> songs) {
  final groups = <AlbumGroup>[];
  AlbumGroup? current;

  for (final song in songs) {
    final albumKey = song.albumId ?? song.albumName ?? '';
    if (current == null || current.albumKey != albumKey) {
      current = AlbumGroup(
        albumKey: albumKey,
        albumName: song.albumName,
        artistName: song.artistName,
        coverArtId: song.coverArtId,
        year: song.year,
        songs: [],
      );
      groups.add(current);
    }
    current.songs.add(song);
  }

  return groups;
}

/// The inline break above an [AlbumGroup]: cover, album, artist, length and year.
class AlbumGroupHeader extends StatelessWidget {
  const AlbumGroupHeader({
    super.key,
    required this.group,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 6),
    this.coverSize = 32,
    this.detailsBelow = false,
  });

  final AlbumGroup group;
  final EdgeInsetsGeometry padding;
  final double coverSize;

  /// Puts the length and year on a line under the artist, rather than in a
  /// column at the right edge. Across a wide table that column sits too far
  /// from the album it describes.
  final bool detailsBelow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
    );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: coverSize,
              height: coverSize,
              child: CoverArtImage(
                coverArtId: group.coverArtId,
                size: coverSize * 2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.albumName ?? l10n?.unknownAlbum ?? 'Unknown Album',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  group.artistName ?? l10n?.unknownArtist ?? 'Unknown Artist',
                  style: detailStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detailsBelow)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (group.year != null) '${group.year}',
                        _hms(group.totalDuration),
                      ].join(' · '),
                      style: detailStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (!detailsBelow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_hms(group.totalDuration), style: detailStyle),
                if (group.year != null)
                  Text('${group.year}', style: detailStyle),
              ],
            ),
        ],
      ),
    );
  }

  /// Always with hours, so a column of these lines up.
  static String _hms(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
}
