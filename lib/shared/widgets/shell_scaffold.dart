import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/features/player/mini_player.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'Artists'),
    NavigationDestination(icon: Icon(Icons.album_outlined), selectedIcon: Icon(Icons.album), label: 'Albums'),
    NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: 'Songs'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
  ];

  static const _paths = ['/home', '/artists', '/albums', '/songs', '/search'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _paths.length; i++) {
      if (location.startsWith(_paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);

    return Scaffold(
      body: Stack(
        children: [
          child,
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
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            height: 56,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: index,
            destinations: _destinations,
            onDestinationSelected: (i) => context.go(_paths[i]),
          ),
        ],
      ),
    );
  }
}
