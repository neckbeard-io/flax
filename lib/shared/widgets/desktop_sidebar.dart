import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/nav_destinations.dart';
import 'package:flax/features/search/search_screen.dart' show searchQueryProvider;
import 'package:flax/shared/widgets/flax_input.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// Focus node for the sidebar search field, exposed so the global "/" shortcut
/// can put the caret there from anywhere in the app.
final searchFieldFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'sidebar search');
  ref.onDispose(node.dispose);
  return node;
});

/// Desktop navigation rail: search, then the top-level destinations.
///
/// Replaces the bottom navigation bar on macOS and Windows. Phones keep the
/// bottom bar — a 220px sidebar would eat a third of the screen, and thumb
/// reach argues for the bottom there anyway.
class DesktopSidebar extends ConsumerStatefulWidget {
  const DesktopSidebar({super.key, this.width = 220});

  final double width;

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Keep the field in step with the query when it is changed elsewhere (the
    // search screen has its own field, and "/" can be pressed at any time).
    _controller.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    // Typing in the sidebar should take you to the results, wherever you were.
    if (GoRouterState.of(context).uri.path != '/search') {
      context.go('/search');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    final selected = navIndexForLocation(location);

    // Mirror external changes to the query without fighting the user's caret.
    final query = ref.watch(searchQueryProvider);
    if (query != _controller.text && !ref.read(searchFieldFocusProvider).hasFocus) {
      _controller.text = query;
    }

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leaves room for the window's drag strip and traffic lights.
          SizedBox(height: MediaQuery.of(context).padding.top + 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SearchField(
              controller: _controller,
              focusNode: ref.watch(searchFieldFocusProvider),
              onSubmitted: _submit,
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'MY LIBRARY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var i = 0; i < navDestinations.length; i++)
            _SidebarItem(
              destination: navDestinations[i],
              selected: i == selected,
              onTap: () => context.go(navDestinations[i].path),
            ),
          const Spacer(),
          _SidebarItem(
            destination: const NavDestination(
              path: '/settings',
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
            ),
            selected: location.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium,
      decoration: flaxInputDecoration(
        context,
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search, size: 18),
      ).copyWith(
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: HoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 12),
              Text(
                destination.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
