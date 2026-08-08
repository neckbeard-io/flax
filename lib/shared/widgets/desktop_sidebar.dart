import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/nav_destinations.dart';
import 'package:flax/features/search/quick_search.dart';
import 'package:flax/features/search/quick_search_overlay.dart';
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
  final _link = LayerLink();
  final _panel = OverlayPortalController();

  /// Row the keyboard is on, or -1 for none. The last row is always "search
  /// everything", so the highest valid index is the result count.
  int _highlighted = -1;

  /// Held rather than read on demand: the provider outlives this widget, and
  /// `ref` is unusable by the time dispose runs.
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = ref.read(searchFieldFocusProvider);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    // The node is shared and outlasts this widget, so leaving a handler on it
    // would keep calling into a dead State.
    _focusNode.onKeyEvent = null;
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Losing focus closes the popup. Clicking a result moves focus too, but
    // the tap is delivered first, so the route change still happens.
    if (!_focusNode.hasFocus) _closePanel();
  }

  void _onChanged(String value) {
    ref.read(quickSearchProvider.notifier).setQuery(value);
    setState(() => _highlighted = -1);
    if (value.trim().length >= kQuickSearchMinChars) {
      _panel.show();
    } else {
      _panel.hide();
    }
  }

  void _closePanel() {
    if (_panel.isShowing) _panel.hide();
    if (_highlighted != -1) setState(() => _highlighted = -1);
  }

  void _dismiss() {
    _closePanel();
    _controller.clear();
    ref.read(quickSearchProvider.notifier).clear();
    _focusNode.unfocus();
  }

  void _open(QuickSearchItem item) {
    _dismiss();
    context.push(item.route);
  }

  /// Hands the query to the search screen, which is where songs and the full
  /// result set live. Pushed with the query in the URL rather than through a
  /// shared provider — that shared provider is exactly what tied these two
  /// searches together.
  void _searchEverything(String query) {
    _dismiss();
    context.push('/search?q=${Uri.encodeQueryComponent(query)}');
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_panel.isShowing) return KeyEventResult.ignored;

    final items = quickSearchItems(
      ref.read(quickSearchResultsProvider).valueOrNull ??
          QuickSearchResults.empty,
    );
    // One past the results is the "search everything" row.
    final last = items.length;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _closePanel();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        setState(() => _highlighted =
            _highlighted >= last ? 0 : _highlighted + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _highlighted =
            _highlighted <= 0 ? last : _highlighted - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // Nothing highlighted means "I typed and hit enter", which is the
        // full search — the same thing the last row does.
        if (_highlighted >= 0 && _highlighted < items.length) {
          _open(items[_highlighted]);
        } else {
          _searchEverything(_controller.text.trim());
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Widget _buildPanel(BuildContext context) {
    final async = ref.watch(quickSearchResultsProvider);
    final items = quickSearchItems(async.valueOrNull ?? QuickSearchResults.empty);

    return Stack(
      children: [
        // Clicking anywhere else puts the popup away, the way every other
        // dropdown behaves. Behind the panel so it never eats its taps.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanel,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: QuickSearchPanel(
              items: items,
              highlighted: _highlighted,
              query: _controller.text.trim(),
              loading: async.isLoading,
              onSelected: _open,
              onSearchEverything: () =>
                  _searchEverything(_controller.text.trim()),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    // Nullable on purpose: null means the open route is Now Playing or
    // Settings, and nothing in the list below should look selected.
    final selected = navDestinationIndex(location);

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
            child: CompositedTransformTarget(
              link: _link,
              child: OverlayPortal(
                controller: _panel,
                overlayChildBuilder: _buildPanel,
                child: _SearchField(
                  controller: _controller,
                  focusNode: ref.watch(searchFieldFocusProvider),
                  onChanged: _onChanged,
                  onKey: _onFieldKey,
                ),
              ),
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
          // Above the library destinations, and outside navDestinations so it
          // does not also become an extra entry in the phone bottom bar — there
          // the mini player sits
          // directly above that bar and already opens this screen.
          //
          // Always present, never gated on something playing: the screen has a
          // "Nothing playing" state, and a menu entry that comes and goes is
          // harder to aim for than one that is simply always there.
          _SidebarItem(
            destination: const NavDestination(
              path: '/now-playing',
              icon: Icons.play_circle_outline,
              selectedIcon: Icons.play_circle,
              label: 'Now Playing',
            ),
            selected: location == '/now-playing',
            onTap: () => context.go('/now-playing'),
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
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The key handler goes on the node rather than a Shortcuts wrapper: arrow
    // keys inside a TextField are consumed by the editable itself, and an
    // onKeyEvent on the node sees them first.
    focusNode.onKeyEvent = onKey;
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
              // Flexible, because the label is the one part of this row whose
              // width is not ours to decide. "Now Playing" already lands within
              // 2px of the 220px rail in the test font, and a larger text scale
              // or a translated label overflows outright.
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
