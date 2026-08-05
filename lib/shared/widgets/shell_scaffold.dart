import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/app/nav_destinations.dart';
import 'package:flax/features/player/mini_player.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Below this width the sidebar is dropped for the bottom bar even on desktop —
/// a 220px rail out of a narrow window leaves too little for content.
const _sidebarMinWidth = 700.0;

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static bool _isDesktop() => Platform.isMacOS || Platform.isWindows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = navIndexForLocation(location);
    final wideEnough = MediaQuery.of(context).size.width >= _sidebarMinWidth;
    final useSidebar = _isDesktop() && wideEnough;

    final content = Stack(
      children: [
        // The sidebar is inside the stack's first child so the window overlays
        // below still sit above everything.
        Row(
          children: [
            if (useSidebar) const DesktopSidebar(),
            Expanded(child: child),
          ],
        ),
        // Drag strip first, so the window buttons below it in the stack stay
        // on top and keep receiving their taps.
        if (Platform.isWindows)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WindowDragArea(),
          ),
        if (Platform.isMacOS || Platform.isWindows)
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 4,
            child: const WindowButtons(),
          ),
        // Below the window buttons: that row is shared with the screen's own
        // AppBar actions, and anything placed in it overlaps them.
        if (kDebugMode)
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            right: 8,
            child: const DebugBadge(),
          ),
      ],
    );

    return _SearchShortcut(
      enabled: useSidebar,
      child: Scaffold(
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
                onDestinationSelected: (i) =>
                    context.go(navDestinations[i].path),
              ),
          ],
        ),
      ),
    );
  }
}

/// Focuses the sidebar search field when "/" is pressed.
///
/// Uses [CallbackShortcuts] rather than a bare [Focus] with `onKeyEvent`: the
/// latter only sees keys that bubble through that exact node, so it did nothing
/// once focus sat anywhere else in the tree.
///
/// The [isEditing] guard is the reason this is not a one-liner. Shortcuts are
/// evaluated even while a text field has focus, so without it "/" could never be
/// typed into any field in the app — it would jump to the search box instead.
class _SearchShortcut extends ConsumerWidget {
  const _SearchShortcut({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  /// Whether a text field currently has focus.
  static bool isEditing() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    // EditableText is what every TextField ultimately focuses.
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    return FocusScope(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.slash): () {
            if (isEditing()) return;
            ref.read(searchFieldFocusProvider).requestFocus();
          },
        },
        child: child,
      ),
    );
  }
}
