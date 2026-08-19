import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flax/shared/widgets/window_buttons.dart';

/// The three columns of the desktop now-playing screen.
enum NowPlayingPanel {
  artist('Artist', Icons.person_outline),
  lyrics('Lyrics', Icons.lyrics_outlined),
  queue('Queue', Icons.queue_music);

  const NowPlayingPanel(this.label, this.icon);

  final String label;
  final IconData icon;
}

// ── Breakpoints ───────────────────────────────────────────────────────
//
// Measured against the window, not the panel area, so the answer does not
// change when the shell sidebar appears. Deliberately widths rather than
// platforms: a tablet in landscape is as entitled to three panels as a Mac.

/// Below this the phone now-playing screen is used unchanged.
const double kNowPlayingPanelsMinWidth = 700;

/// Below this only one panel is shown at a time, with a switcher.
const double kNowPlayingSinglePanelMaxWidth = 1100;

/// At or above this the artist panel starts open; below it starts collapsed,
/// because lyrics and queue together already want the room.
const double kNowPlayingArtistOpenMinWidth = 1400;

const double kQueuePanelWidth = 340;
const double kArtistPanelDefaultWidth = 280;
const double kArtistPanelMinWidth = 200;
const double kArtistPanelMaxWidth = 460;

/// How the now-playing screen arranges itself at a given window width.
///
/// A plain value rather than a scatter of `if (width > ...)` in build methods,
/// so the rules can be asserted directly.
class NowPlayingLayout {
  /// One panel at a time, chosen with a switcher.
  final bool singlePanel;

  /// Whether the artist panel starts open. Only a default — the user's toggle
  /// wins from then on.
  final bool artistOpenByDefault;

  const NowPlayingLayout({
    required this.singlePanel,
    required this.artistOpenByDefault,
  });

  factory NowPlayingLayout.forWidth(double width) => NowPlayingLayout(
    singlePanel: width < kNowPlayingSinglePanelMaxWidth,
    artistOpenByDefault: width >= kNowPlayingArtistOpenMinWidth,
  );

  /// Whether [width] gets panels at all, as opposed to the phone screen.
  static bool fitsAt(double width) => width >= kNowPlayingPanelsMinWidth;
}

/// Arranges the artist, lyrics and queue panels.
///
/// Deliberately knows nothing about what is in them: it takes three widgets
/// and lays them out. That keeps the geometry — which panel is on screen, how
/// wide it is, what collapsing gives back to the lyrics — testable without
/// standing up a player, a server or a router.
class NowPlayingPanels extends StatelessWidget {
  const NowPlayingPanels({
    super.key,
    required this.layout,
    required this.artist,
    required this.lyrics,
    required this.queue,
    required this.artistOpen,
    required this.onArtistOpenChanged,
    required this.selected,
    required this.onSelected,
    this.artistWidth = kArtistPanelDefaultWidth,
    this.onArtistWidthChanged,
    this.leading,
  });

  final NowPlayingLayout layout;

  final Widget artist;
  final Widget lyrics;
  final Widget queue;

  /// Whether the artist column is showing, in three-panel mode.
  final bool artistOpen;
  final ValueChanged<bool> onArtistOpenChanged;

  /// The panel on screen in single-panel mode.
  final NowPlayingPanel selected;
  final ValueChanged<NowPlayingPanel> onSelected;

  final double artistWidth;
  final ValueChanged<double>? onArtistWidthChanged;

  /// Screen-level control for the header's left edge, normally a back button.
  final Widget? leading;

  static const artistKey = Key('now-playing-panel-artist');
  static const lyricsKey = Key('now-playing-panel-lyrics');
  static const queueKey = Key('now-playing-panel-queue');

  @override
  Widget build(BuildContext context) {
    // Opaque, and that is the whole job of this Material.
    //
    // These panels are the only screen in the app that is not a Scaffold — the
    // shell already supplies one — and so they were the only route with no
    // background of its own. During the push transition the outgoing screen is
    // still on stage underneath, and an album grid was plainly visible through
    // the lyrics until the animation finished and the old route was removed.
    // The queue column hid it better than the others only because its rows are
    // dense enough to read as solid.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _Header(
            layout: layout,
            artistOpen: artistOpen,
            onArtistOpenChanged: onArtistOpenChanged,
            selected: selected,
            onSelected: onSelected,
            leading: leading,
          ),
          Expanded(
            child: layout.singlePanel ? _buildSingle() : _buildColumns(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSingle() {
    return switch (selected) {
      NowPlayingPanel.artist => KeyedSubtree(key: artistKey, child: artist),
      NowPlayingPanel.lyrics => KeyedSubtree(key: lyricsKey, child: lyrics),
      NowPlayingPanel.queue => KeyedSubtree(key: queueKey, child: queue),
    };
  }

  Widget _buildColumns(BuildContext context) {
    final width = artistWidth.clamp(kArtistPanelMinWidth, kArtistPanelMaxWidth);

    return Row(
      children: [
        if (artistOpen) ...[
          SizedBox(key: artistKey, width: width, child: artist),
          _ResizeHandle(
            onDelta: onArtistWidthChanged == null
                ? null
                : (dx) => onArtistWidthChanged!(
                    (width + dx).clamp(
                      kArtistPanelMinWidth,
                      kArtistPanelMaxWidth,
                    ),
                  ),
          ),
        ],
        // Lyrics take whatever the other two leave, so collapsing the artist
        // panel hands its width straight to them rather than to dead space.
        Expanded(
          child: KeyedSubtree(key: lyricsKey, child: lyrics),
        ),
        const _PanelSeparator(),
        SizedBox(key: queueKey, width: kQueuePanelWidth, child: queue),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.layout,
    required this.artistOpen,
    required this.onArtistOpenChanged,
    required this.selected,
    required this.onSelected,
    this.leading,
  });

  final NowPlayingLayout layout;
  final bool artistOpen;
  final ValueChanged<bool> onArtistOpenChanged;
  final NowPlayingPanel selected;
  final ValueChanged<NowPlayingPanel> onSelected;
  final Widget? leading;

  /// Width reserved at each end: a back button and the panel toggle on the
  /// leading side, the window controls on the trailing one. The larger of the
  /// two wins for both, so the middle is really the middle.
  double get _sideWidth =>
      math.max(2 * 48, windowButtonsReservedWidth + 48).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      // Both sides reserve the same width so the switcher sits in the middle
      // of the window. Spacers alone center it in whatever the controls leave
      // over, and the trailing side is heavier by the room the window controls
      // need — enough to read as crooked.
      child: Row(
        children: [
          SizedBox(
            width: _sideWidth,
            child: Row(
              children: [
                ?leading,
                if (!layout.singlePanel)
                  IconButton(
                    icon: Icon(
                      artistOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                    ),
                    tooltip: artistOpen
                        ? 'Hide artist panel'
                        : 'Show artist panel',
                    onPressed: () => onArtistOpenChanged(!artistOpen),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: layout.singlePanel
                  ? LayoutBuilder(
                      builder: (context, constraints) => _PanelSwitcher(
                        selected: selected,
                        onSelected: onSelected,
                        // Below this the labels no longer fit beside their
                        // icons, and SegmentedButton wraps them mid-word
                        // rather than shrinking: "Artis / t". Drop to icons
                        // and let the tooltips carry the names.
                        showLabels:
                            constraints.maxWidth >= _switcherLabelMinWidth,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // The window controls are painted over this corner by AppChrome.
          SizedBox(width: _sideWidth),
        ],
      ),
    );
  }
}

/// Width the switcher needs before its labels fit beside their icons.
///
/// The labelled form measures about 416pt, so this is that plus a little room
/// for a larger text scale. Set it below the real width and the fallback never
/// fires, which is exactly how the wrapping survived the first fix.
const double _switcherLabelMinWidth = 440;

/// Artist / Lyrics / Queue picker for single-panel widths.
class _PanelSwitcher extends StatelessWidget {
  const _PanelSwitcher({
    required this.selected,
    required this.onSelected,
    required this.showLabels,
  });

  final NowPlayingPanel selected;
  final ValueChanged<NowPlayingPanel> onSelected;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NowPlayingPanel>(
      showSelectedIcon: false,
      segments: [
        for (final panel in NowPlayingPanel.values)
          ButtonSegment(
            value: panel,
            icon: Icon(panel.icon, size: 18),
            tooltip: panel.label,
            label: showLabels
                ? Text(
                    panel.label,
                    // A label that wraps is worse than one that clips: the
                    // header has a fixed height, so wrapping pushes the text
                    // out of the button rather than making room.
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  )
                : null,
          ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSelected(s.first),
    );
  }
}

/// Hairline between two panels.
class _PanelSeparator extends StatelessWidget {
  const _PanelSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

/// Draggable divider that widens or narrows the artist panel.
///
/// Wider than the hairline it draws: a 1px grab target is unhittable, so the
/// handle is 8px of transparent padding around the line.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({this.onDelta});

  final ValueChanged<double>? onDelta;

  @override
  Widget build(BuildContext context) {
    final line = Center(
      child: Container(
        width: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
    );

    if (onDelta == null) return SizedBox(width: 9, child: line);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDelta!(d.delta.dx),
        child: SizedBox(width: 9, child: line),
      ),
    );
  }
}
