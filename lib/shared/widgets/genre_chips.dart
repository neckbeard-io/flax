import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/shared/widgets/hover_effects.dart';

/// Where a genre's page lives.
String genreLocation(String name) => '/genres/${Uri.encodeComponent(name)}';

/// How large a genre chip is drawn.
enum GenreChipSize {
  /// Inside a table row or a panel header.
  dense(height: 22, padding: 8, fontSize: 11),

  /// Beside a heading on desktop.
  regular(height: 26, padding: 10, fontSize: 12),

  /// On a phone, where it is a finger's target.
  touch(height: 32, padding: 12, fontSize: 13);

  const GenreChipSize({
    required this.height,
    required this.padding,
    required this.fontSize,
  });

  final double height;
  final double padding;
  final double fontSize;

  /// Gap between neighboring chips.
  double get spacing => this == dense ? 4 : 6;
}

/// Genres as tappable chips, each opening its genre's page.
///
/// Wrapped, every genre shows. [singleLine] keeps to one line for places that
/// have only that much room: as many whole chips as fit, then a `+N` chip for
/// the rest — a tooltip and menu of them, or [onMore] when the caller has a
/// better way to show them all.
class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.genres,
    this.singleLine = false,
    this.size = GenreChipSize.regular,
    this.onSelected,
    this.onMore,
  });

  final List<String> genres;
  final bool singleLine;
  final GenreChipSize size;

  /// What tapping a genre does. Opens its page when null.
  final ValueChanged<String>? onSelected;

  /// What tapping `+N` does. Opens a menu of the hidden genres when null.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();

    void select(String name) {
      if (onSelected != null) {
        onSelected!(name);
      } else {
        context.push(genreLocation(name));
      }
    }

    if (!singleLine) {
      return Wrap(
        spacing: size.spacing,
        runSpacing: size.spacing,
        children: [
          for (final g in genres)
            GenreChip(name: g, size: size, onTap: () => select(g)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = _labelStyle(context, size);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        double chipWidth(String label) =>
            _measure(label, style, scaler, direction) + 2 * size.padding;

        final shown = genreChipsThatFit(
          widths: [for (final g in genres) chipWidth(g)],
          maxWidth: constraints.maxWidth,
          spacing: size.spacing,
          moreWidth: (hidden) => chipWidth('+$hidden'),
        );
        final hidden = genres.sublist(shown);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) SizedBox(width: size.spacing),
              // The first chip may shrink: when even one genre is wider than
              // the line, it ellipsizes rather than overflowing.
              if (i == 0)
                Flexible(
                  child: GenreChip(
                    name: genres[i],
                    size: size,
                    onTap: () => select(genres[i]),
                  ),
                )
              else
                GenreChip(
                  name: genres[i],
                  size: size,
                  onTap: () => select(genres[i]),
                ),
            ],
            if (hidden.isNotEmpty) ...[
              SizedBox(width: size.spacing),
              _MoreChip(
                hidden: hidden,
                size: size,
                onMore: onMore,
                onSelected: select,
              ),
            ],
          ],
        );
      },
    );
  }

  static double _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
  }
}

/// How many chips of [widths] fit on one line of [maxWidth].
///
/// Leaves room for a `+N` chip, [moreWidth] wide, whenever some are left over.
/// Never less than one: a line too narrow for even the first chip still shows
/// it, ellipsized.
@visibleForTesting
int genreChipsThatFit({
  required List<double> widths,
  required double maxWidth,
  required double spacing,
  required double Function(int hidden) moreWidth,
}) {
  for (var shown = widths.length; shown > 1; shown--) {
    var used = 0.0;
    for (var i = 0; i < shown; i++) {
      used += widths[i] + (i > 0 ? spacing : 0);
    }
    final hidden = widths.length - shown;
    if (hidden > 0) used += spacing + moreWidth(hidden);
    if (used <= maxWidth) return shown;
  }
  return math.min(1, widths.length);
}

/// One genre. Tapping it opens the genre's page unless [onTap] says otherwise.
class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.name,
    this.size = GenreChipSize.regular,
    this.onTap,
  });

  final String name;
  final GenreChipSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Genre: $name',
      excludeSemantics: true,
      child: _ChipFrame(
        label: name,
        size: size,
        border: scheme.outlineVariant,
        foreground: scheme.onSurfaceVariant,
        onTap: onTap ?? () => context.push(genreLocation(name)),
      ),
    );
  }
}

/// The `+N` that stands in for genres a single line had no room for.
class _MoreChip extends StatelessWidget {
  const _MoreChip({
    required this.hidden,
    required this.size,
    required this.onSelected,
    this.onMore,
  });

  final List<String> hidden;
  final GenreChipSize size;
  final ValueChanged<String> onSelected;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '+${hidden.length}';
    final semantics =
        '${hidden.length} more ${hidden.length == 1 ? 'genre' : 'genres'}';

    Widget chip(VoidCallback onTap) => Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Tooltip(
        message: hidden.join(', '),
        waitDuration: const Duration(milliseconds: 400),
        child: _ChipFrame(
          label: label,
          size: size,
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          onTap: onTap,
        ),
      ),
    );

    if (onMore != null) return chip(onMore!);

    return MenuAnchor(
      menuChildren: [
        for (final g in hidden)
          MenuItemButton(onPressed: () => onSelected(g), child: Text(g)),
      ],
      builder: (context, controller, _) => chip(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The shape both chips share: a rounded box around one line of label.
class _ChipFrame extends StatelessWidget {
  const _ChipFrame({
    required this.label,
    required this.size,
    required this.foreground,
    required this.onTap,
    this.border,
    this.background,
  });

  final String label;
  final GenreChipSize size;
  final Color foreground;
  final Color? border;
  final Color? background;
  final VoidCallback onTap;

  static final _radius = BorderRadius.circular(8);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: _radius,
        border: Border.all(color: border ?? Colors.transparent),
      ),
      child: HoverSurface(
        onTap: onTap,
        borderRadius: _radius,
        child: SizedBox(
          height: size.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.padding),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(context, size).copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context, GenreChipSize size) =>
    (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontSize: size.fontSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
