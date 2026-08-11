import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/app/nav_destinations.dart';
import 'package:flax/features/player/mini_player.dart';
import 'package:flax/features/player/now_playing_panels.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

/// Below this width the sidebar is dropped for the bottom bar even on desktop —
/// a 220px rail out of a narrow window leaves too little for content.
const _sidebarMinWidth = 700.0;

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static bool _isDesktop() => Platform.isMacOS || Platform.isWindows;

  /// Routes that take the whole window, with no navigation chrome around them.
  ///
  /// Only the phone now-playing screen: it is a full-bleed cover with its own
  /// transport and its own way out, so a mini player repeating the transport
  /// and a nav bar under it would be two of everything. At panel widths it is
  /// an ordinary screen and keeps the shell.
  static bool isImmersiveRoute(String location, double width) =>
      location == '/now-playing' && !NowPlayingLayout.fitsAt(width);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = navIndexForLocation(location);
    final width = MediaQuery.of(context).size.width;
    final wideEnough = width >= _sidebarMinWidth;
    final useSidebar = _isDesktop() && wideEnough;
    final immersive = isImmersiveRoute(location, width);

    if (immersive) return child;

    final content = Row(
      children: [
        if (useSidebar) const DesktopSidebar(),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      body: content,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          // With the sidebar showing, the destinations live there; keeping the
          // bottom bar too would duplicate them.
          if (!useSidebar)
            NavigationBar(
              height: 56,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: index,
              destinations: [
                for (final d in navDestinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
              onDestinationSelected: (i) => context.go(navDestinations[i].path),
            ),
        ],
      ),
    );
  }
}
