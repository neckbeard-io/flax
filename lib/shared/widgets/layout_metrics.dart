import 'dart:io';

import 'package:flutter/material.dart';

/// Layout scale for artwork-heavy grids and carousels.
///
/// The original sizes were chosen for a phone: a 180px grid extent fills a phone
/// screen with two columns of reasonably large art, but on a desktop window it
/// produces a dense field of small thumbnails, and the art is the point. Desktop
/// gets larger tiles, which also means a larger image is fetched — see
/// CoverArtImage, which derives resolution from the laid-out size.
bool isDesktopLayout(BuildContext context) =>
    (Platform.isMacOS || Platform.isWindows) &&
    MediaQuery.of(context).size.width >= 700;

/// Maximum width of one album/artist tile in a grid.
double artGridExtent(BuildContext context) =>
    isDesktopLayout(context) ? 240 : 180;

/// Width of one item in a horizontally scrolling shelf.
double artShelfExtent(BuildContext context) =>
    isDesktopLayout(context) ? 200 : 140;
