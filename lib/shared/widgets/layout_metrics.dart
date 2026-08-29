import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Override for testing mobile layouts on desktop hosts.
bool? debugOverrideIsDesktopPlatform;

/// Whether the current operating system is a desktop platform (macOS, Windows, or Linux).
bool get isDesktopPlatform =>
    debugOverrideIsDesktopPlatform ??
    (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Layout scale for artwork-heavy grids and carousels.
///
/// The original sizes were chosen for a phone: a 180px grid extent fills a phone
/// screen with two columns of reasonably large art, but on a desktop window it
/// produces a dense field of small thumbnails, and the art is the point. Desktop
/// gets larger tiles, which also means a larger image is fetched — see
/// CoverArtImage, which derives resolution from the laid-out size.
bool isDesktopLayout(BuildContext context) =>
    isDesktopPlatform && MediaQuery.of(context).size.width >= 700;

/// Maximum width of one album/artist tile in a grid.
double artGridExtent(BuildContext context) =>
    isDesktopLayout(context) ? 240 : 180;

/// Width of one item in a horizontally scrolling shelf.
double artShelfExtent(BuildContext context) =>
    isDesktopLayout(context) ? 200 : 140;

/// Room a grid tile leaves under its art for the name and artist lines.
///
/// A fixed height, not a share of the tile. The labels are two lines of a fixed
/// text style, so anything that scales them with the tile width hands the slack
/// to the art instead — which is exactly how the album grid came to draw every
/// square cover into a taller-than-wide box and crop it top and bottom.
double artGridLabelExtent(BuildContext context) =>
    44 * MediaQuery.textScalerOf(context).scale(1);

/// Width one tile actually gets, laying [maxExtent]-wide tiles across [width]
/// with [spacing] between them.
///
/// Mirrors `SliverGridDelegateWithMaxCrossAxisExtent`'s own arithmetic, because
/// the tile width has to be known before the grid is built: album art is square,
/// so a tile is one width of art plus [artGridLabelExtent], and that is a height
/// rather than a ratio.
double artGridTileWidth(double width, double maxExtent, double spacing) {
  final columns = math.max(1, (width / (maxExtent + spacing)).ceil());
  final usable = math.max(0.0, width - spacing * (columns - 1));
  return usable / columns;
}
