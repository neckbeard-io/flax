import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flax/shared/widgets/layout_metrics.dart';

/// The letters of the index, top to bottom: `#` for anything that does not
/// start with A–Z, then A to Z.
final kIndexLetters = List<String>.unmodifiable([
  '#',
  for (var c = 0x41; c <= 0x5A; c++) String.fromCharCode(c),
]);

/// Width of the index strip. Lists under it pad their right edge by this so
/// nothing in a row ends up beneath a letter.
const kAlphabetScrollerWidth = 28.0;

/// Lists sorted by name get the index from this many items. A shorter one
/// fits in a few flicks, and the strip would only crowd it.
const kAlphabetIndexMinItems = 40;

// Accented capitals and the letters they file under, position for position.
const _accented =
    'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝĀĂĄĆĈĊČĎĒĔĖĘĚĜĞĠĢĤĨĪĬĮİĴĶĹĻĽŃŅŇŌŎŐŔŖŘŚŜŞŠŢŤŨŪŬŮŰŲŴŶŸŹŻŽØĐŁÆŒ';
const _unaccented =
    'AAAAAACEEEEIIIINOOOOOUUUUYAAACCCCDEEEEEGGGGHIIIIIJKLLLNNNOOORRRSSSSTTUUUUUUWYYZZZODLAO';

/// Navidrome's default ignored articles, which it leaves off the front of a
/// name when sorting.
const _ignoredArticles = [
  'the',
  'el',
  'la',
  'los',
  'las',
  'le',
  'les',
  'os',
  'as',
  'o',
  'a',
];

/// [name] the way the server sorts it: without a leading article. Lists in the
/// server's order put "The Wall" among the W's, so its letter is W.
String withoutLeadingArticle(String name) {
  final trimmed = name.trimLeft();
  final lower = trimmed.toLowerCase();
  for (final article in _ignoredArticles) {
    if (lower.length > article.length + 1 && lower.startsWith('$article ')) {
      return trimmed.substring(article.length + 1).trimLeft();
    }
  }
  return trimmed;
}

/// The index letter a row sorts under: the first letter of [sortKey],
/// upper-cased with any accent dropped, or `#`.
///
/// Pass the key the list is actually ordered by. Artists sort on the server's
/// sort name, which drops "The", so "The Beatles" belongs under B — filing it
/// by its display name would send T to the wrong place.
String indexLetterOf(String sortKey) {
  final trimmed = sortKey.trimLeft();
  if (trimmed.isEmpty) return '#';
  var first = trimmed[0].toUpperCase();
  final accented = _accented.indexOf(first);
  if (accented >= 0) first = _unaccented[accented];
  final code = first.codeUnitAt(0);
  return code >= 0x41 && code <= 0x5A ? first : '#';
}

/// The first row under each letter of [sortKeys], which are in display order.
Map<String, int> firstRowByLetter(Iterable<String> sortKeys) {
  final rows = <String, int>{};
  var i = 0;
  for (final key in sortKeys) {
    rows.putIfAbsent(indexLetterOf(key), () => i);
    i++;
  }
  return rows;
}

/// The row to show for [letter]: its first row, else the first row of the
/// next letter that has one, else of the nearest one before it. Null when
/// there are no rows at all.
int? rowForLetter(String letter, Map<String, int> firstRows) {
  final at = kIndexLetters.indexOf(letter);
  if (at < 0) return null;
  for (var i = at; i < kIndexLetters.length; i++) {
    final row = firstRows[kIndexLetters[i]];
    if (row != null) return row;
  }
  for (var i = at - 1; i >= 0; i--) {
    final row = firstRows[kIndexLetters[i]];
    if (row != null) return row;
  }
  return null;
}

/// An A–Z strip down the right edge of [child], for jumping through a long
/// list.
///
/// Tapping a letter or dragging along the strip calls [onLetter] with the
/// letter under the finger; finding the row is the caller's business, since
/// only it knows how the list is laid out. Letters in [available] are drawn
/// at full strength, the rest dimmed — they still answer, and the caller
/// moves to the nearest letter that has rows (see [rowForLetter]).
///
/// Holds no providers, so it can be tested without a library.
class AlphabetScroller extends StatefulWidget {
  const AlphabetScroller({
    super.key,
    required this.child,
    required this.available,
    required this.onLetter,
  });

  final Widget child;
  final Set<String> available;
  final ValueChanged<String> onLetter;

  @override
  State<AlphabetScroller> createState() => _AlphabetScrollerState();
}

class _AlphabetScrollerState extends State<AlphabetScroller> {
  /// The letter under a finger or a held mouse button, shown in the bubble.
  String? _pressed;

  /// The letter under the pointer while it hovers, without a press.
  String? _hovered;

  /// Whether the press became a drag. A drag that wins over the tap cancels
  /// the tap first, and the press has to survive that.
  bool _dragging = false;

  /// Letter slots shorter than this show every other letter, with a dot in
  /// between, so a short window does not shrink the type to nothing.
  static const _minLetterSlot = 12.0;

  String _letterAt(double dy, double height) {
    final slot = height / kIndexLetters.length;
    final i = (dy / slot).floor().clamp(0, kIndexLetters.length - 1);
    return kIndexLetters[i];
  }

  void _press(String letter) {
    if (letter == _pressed) return;
    setState(() => _pressed = letter);
    if (!isDesktopPlatform) HapticFeedback.selectionClick();
    widget.onLetter(letter);
  }

  void _release() {
    _dragging = false;
    if (_pressed != null) setState(() => _pressed = null);
  }

  void _tapCancelled() {
    // Called before a winning drag starts; let the drag claim the press.
    scheduleMicrotask(() {
      if (mounted && !_dragging) _release();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: kAlphabetScrollerWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final slot = height / kIndexLetters.length;
              final sparse = slot < _minLetterSlot;
              final fontSize = (slot * 0.8).clamp(8.0, 12.0);
              final maxBubbleTop = math.max(0.0, height - _Bubble.size);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Mouse and touch both act on the whole strip, so a drag
                  // that wanders off one letter keeps moving the list. Hover
                  // is tracked here too: no shared hover primitive follows a
                  // pointer along a strip of targets.
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onHover: (e) => setState(
                        () => _hovered = _letterAt(e.localPosition.dy, height),
                      ),
                      onExit: (_) => setState(() => _hovered = null),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        // Start from the letter first touched, not from
                        // wherever the finger was once it counted as a drag.
                        dragStartBehavior: DragStartBehavior.down,
                        onTapDown: (d) =>
                            _press(_letterAt(d.localPosition.dy, height)),
                        onTapUp: (_) => _release(),
                        onTapCancel: _tapCancelled,
                        onVerticalDragStart: (d) {
                          _dragging = true;
                          _press(_letterAt(d.localPosition.dy, height));
                        },
                        onVerticalDragUpdate: (d) =>
                            _press(_letterAt(d.localPosition.dy, height)),
                        onVerticalDragEnd: (_) => _release(),
                        onVerticalDragCancel: _release,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _pressed != null
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              kAlphabetScrollerWidth / 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < kIndexLetters.length; i++)
                                SizedBox(
                                  height: slot,
                                  child: _Letter(
                                    letter: kIndexLetters[i],
                                    label: sparse && i.isEven && i != 0
                                        ? '•'
                                        : kIndexLetters[i],
                                    fontSize: fontSize,
                                    available: widget.available.contains(
                                      kIndexLetters[i],
                                    ),
                                    active:
                                        kIndexLetters[i] == _pressed ||
                                        kIndexLetters[i] == _hovered,
                                    onTap: () =>
                                        widget.onLetter(kIndexLetters[i]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_pressed != null)
                    Positioned(
                      right: kAlphabetScrollerWidth + 12,
                      top:
                          (kIndexLetters.indexOf(_pressed!) * slot +
                                  slot / 2 -
                                  _Bubble.size / 2)
                              .clamp(0.0, maxBubbleTop),
                      child: _Bubble(letter: _pressed!),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.label,
    required this.fontSize,
    required this.available,
    required this.active,
    required this.onTap,
  });

  final String letter;
  final String label;
  final double fontSize;
  final bool available;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active
        ? scheme.primary
        : available
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      label: letter == '#' ? 'Jump to numbers and symbols' : 'Jump to $letter',
      onTap: onTap,
      excludeSemantics: true,
      child: Center(
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: active ? fontSize + 2 : fontSize,
            height: 1,
            fontWeight: active || available ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The large letter beside the finger while the strip is held, since the
/// finger covers the strip itself.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.letter});

  static const size = 56.0;

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// A list of rows that are all one height, with the A–Z index once it holds
/// [kAlphabetIndexMinItems] rows or more.
///
/// One height is what makes a letter a jump rather than a search: a row's
/// offset is its position times the height, with nothing laid out first.
/// [prototypeItem] sets that height, so build it like the other rows.
class AlphabetIndexedList extends StatefulWidget {
  const AlphabetIndexedList({
    super.key,
    required this.sortKeys,
    required this.prototypeItem,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });

  /// What each row is sorted on, in display order: one per row.
  final List<String> sortKeys;
  final Widget prototypeItem;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  State<AlphabetIndexedList> createState() => _AlphabetIndexedListState();
}

class _AlphabetIndexedListState extends State<AlphabetIndexedList> {
  final _scroll = ScrollController();

  /// On the prototype, which the list lays out to learn every row's height.
  final _prototype = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls [letter]'s first row to the top.
  ///
  /// Row height comes from the measured prototype, and the furthest the list
  /// can go from that height, rather than from the scroll position: a list
  /// that grew below the rows on screen keeps its old length there until it
  /// next scrolls, and anything worked out from it lands short.
  void _jumpTo(String letter, Map<String, int> firstRows, EdgeInsets padding) {
    final row = rowForLetter(letter, firstRows);
    final box = _prototype.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || box == null || !box.hasSize || !_scroll.hasClients) {
      return;
    }
    final rowExtent = box.size.height;
    final length = padding.vertical + widget.sortKeys.length * rowExtent;
    final furthest = math.max(0.0, length - _scroll.position.viewportDimension);
    _scroll.jumpTo((padding.top + row * rowExtent).clamp(0.0, furthest));
  }

  @override
  Widget build(BuildContext context) {
    final indexed = widget.sortKeys.length >= kAlphabetIndexMinItems;
    final padding = indexed
        ? widget.padding.copyWith(
            right: widget.padding.right + kAlphabetScrollerWidth,
          )
        : widget.padding;
    final list = ListView.builder(
      controller: _scroll,
      padding: padding,
      prototypeItem: KeyedSubtree(key: _prototype, child: widget.prototypeItem),
      itemCount: widget.sortKeys.length,
      itemBuilder: widget.itemBuilder,
    );
    if (!indexed) return list;

    final firstRows = firstRowByLetter(widget.sortKeys);
    return AlphabetScroller(
      available: firstRows.keys.toSet(),
      onLetter: (letter) => _jumpTo(letter, firstRows, padding),
      child: list,
    );
  }
}
