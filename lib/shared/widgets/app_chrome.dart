import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kBackMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/updater/update_button.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/updater/mobile_update_coordinator.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/services/updater/whats_new_provider.dart';
import 'package:flax/shared/input/back_swipe.dart';
import 'package:flax/shared/input/global_keys.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';
import 'package:flax/shared/widgets/in_window_toaster.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Window controls, drag strip, debug badge, and the global "/" shortcut,
/// wrapped around every route.
///
/// These used to live in ShellScaffold, which meant any screen outside the shell
/// had none of them: the server setup screen had no way to minimise, maximise or
/// close the window at all, and neither did the now-playing screen. Doing it once
/// here covers every route, including ones added later.
class AppChrome extends ConsumerStatefulWidget {
  const AppChrome({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppChrome> createState() => _AppChromeState();
}

class _AppChromeState extends ConsumerState<AppChrome>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Ask the server whether the library changed whenever the window comes
    // back to the foreground. This is one 285-byte `getScanStatus` against
    // Navidrome, so it is cheap enough to do on every focus — and with a
    // library that has not been rescanned it does nothing at all.
    //
    // AppChrome is the only widget that wraps every route, which makes it the
    // one place this can live without being duplicated per screen.
    WidgetsBinding.instance.addObserver(this);
    // A keyboard handler rather than a Shortcuts widget.
    //
    // Shortcuts only sees keys that bubble up through the focused node's
    // ancestors. Clicking empty space in the sidebar clears focus to the root
    // scope, which sits *above* any widget we can wrap the app in — so "/" never
    // reached the handler and macOS played the unhandled-key beep instead. A
    // handler on the keyboard itself is focus-independent, which is what a
    // global shortcut actually means.
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WhatsNewCoordinator.checkAndShowIfNeeded(context, ref);
        MobileUpdateCoordinator.checkAndPrompt(context, ref);
        ref.read(serverReachabilityProvider.notifier).probeServer(silent: true);
        ref.read(audioCacheServiceProvider).resumePendingDownloads();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Check for updates when coming back to the foreground on mobile (Android/iOS).
    // On desktop platforms (Linux/macOS/Windows), periodic scheduled background checks
    // run via UpdateNotifier to prevent re-querying GitHub on every window focus change.
    if (!isDesktopPlatform) {
      ref.read(updateNotifierProvider.notifier).checkForUpdates(silent: true);
      MobileUpdateCoordinator.checkAndPrompt(context, ref);
    }

    // Probe server reachability
    ref.read(serverReachabilityProvider.notifier).probeServer(silent: true);

    final isOffline = ref.read(isOfflineModeProvider);
    if (isOffline) return;

    ref.read(audioCacheServiceProvider).resumePendingDownloads();

    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    // All three are fire-and-forget. A failure is a no-op: the repository treats
    // an unanswered beacon as "assume changed" and falls back to its TTLs, so a
    // dropped check costs nothing.

    // Library content. One 285-byte call, and nothing at all if unchanged.
    repo.syncIfChanged();

    // Annotations, which the beacon cannot see — a heart added in the web UI or
    // a play on another device. Rate-limited inside the repository, because
    // getStarred2 is the expensive call here.
    repo.syncAnnotations();

    // Sweep entities the server has stopped mentioning. Nothing favorited,
    // rated, or still in a cached list is touched, so this is safe to run
    // unattended.
    repo.collectGarbage();
  }

  /// Whether a text field currently has focus, in which case "/" is a character
  /// the user is typing and must be left alone.
  static bool _isEditing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    return switch (globalKeyAction(event, isEditing: _isEditing())) {
      GlobalKeyAction.focusSearch => _focusSearch(),
      GlobalKeyAction.togglePlayback => _togglePlayback(),
      GlobalKeyAction.none => false,
    };
  }

  bool _focusSearch() {
    final node = ref.read(searchFieldFocusProvider);
    // Nothing to focus when the sidebar is not on screen — a phone, or a window
    // too narrow for it. Returning false lets the key fall through as normal.
    if (!node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    return _handleBackNavigation();
  }

  /// Space plays and pauses, from anywhere.
  ///
  /// Claimed globally rather than left to whatever has focus. Space would
  /// otherwise press the focused button, which after clicking "next" means the
  /// spacebar skips tracks — and every other player in the world treats space
  /// as play/pause regardless of where you last clicked.
  bool _togglePlayback() {
    ref.read(playerProvider.notifier).togglePlayPause();
    return true;
  }

  /// Back, for Android system back gestures/buttons, mouse button 4, and trackpad swipe.
  ///
  /// Pops pushed routes if available; otherwise falls back up the hierarchy
  /// (e.g. /settings/metadata-cache -> /settings, /albums/123 -> /albums) when
  /// sitting on a subpage or detail screen with an upper-left back action.
  /// Returning false on root destinations (/albums, /settings) lets the OS
  /// exit or minimize the app as expected.
  bool _handleBackNavigation() {
    if (!mounted) return false;
    final router = ref.read(routerProvider);

    // 1. If GoRouter or Navigator has pushed routes to pop:
    if (router.canPop()) {
      router.pop();
      return true;
    }

    // 2. If nothing on the route stack, check the current location to see if
    // we are on a subpage/detail screen with an Up/Back action:
    final location = router.routerDelegate.currentConfiguration.uri.path;

    // Settings subpages -> /settings (or AutoEQ -> Equalizer)
    if (location.startsWith('/settings/')) {
      if (location == '/settings/autoeq') {
        router.go('/settings/equalizer');
      } else {
        router.go('/settings');
      }
      return true;
    }

    // Detail: /albums/:id -> /albums
    if (location.startsWith('/albums/')) {
      router.go('/albums');
      return true;
    }

    // Detail: /artists/:id -> /artists
    if (location.startsWith('/artists/')) {
      router.go('/artists');
      return true;
    }

    // Downloads screen -> /albums
    if (location == '/downloads') {
      router.go('/albums');
      return true;
    }

    // Phone Now Playing screen -> /albums
    if (location == '/now-playing') {
      router.go('/albums');
      return true;
    }

    // Root screens (/albums, /artists, /search, /settings, /add-server):
    return false;
  }

  void _goBack() {
    _handleBackNavigation();
  }

  final _backSwipe = BackSwipeTracker();

  void _onPointerDown(PointerDownEvent event) {
    // Mouse button 4. The browser back button on any five-button mouse, and
    // the one Windows users reach for without thinking.
    if (event.buttons & kBackMouseButton != 0) _goBack();
  }

  bool _onScroll(ScrollNotification notification) {
    // A scrollable moved during this swipe, so the swipe was a scroll.
    if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.horizontal) {
      _backSwipe.noteScrolled();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform;

    final top = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Pointer-driven navigation, wrapped around the routed screen only —
        // not the chrome overlay below, which has no business consuming a
        // swipe.
        Listener(
          onPointerDown: _onPointerDown,
          onPointerPanZoomStart: (_) => _backSwipe.start(),
          onPointerPanZoomUpdate: (event) {
            if (_backSwipe.update(event.panDelta.dx, event.panDelta.dy)) {
              _goBack();
            }
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        // The chrome gets an Overlay of its own. MaterialApp.builder runs
        // outside the router's Navigator, so anything here is a sibling of it
        // rather than a descendant — and the window buttons' tooltips need an
        // Overlay ancestor, which threw "No Overlay widget found" without this.
        //
        // Only Positioned children go inside, so the empty area does not absorb
        // pointer events and clicks still reach the screen underneath.
        Positioned.fill(
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Stack(
                  children: [
                    // Drag strip first, leaving right space so controls keep their taps.
                    if (Platform.isWindows || Platform.isLinux)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: windowButtonsReservedWidth + 120,
                        child: const WindowDragArea(),
                      ),
                    if (isDesktop)
                      Positioned(
                        top: top + 4,
                        right: 4,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OfflineModeToggle(),
                            SizedBox(width: 8),
                            UpdateButton(),
                            WindowButtons(),
                          ],
                        ),
                      ),
                    // In-window toast notices (e.g. server reachability fallback)
                    const InWindowToaster(),
                    // Upper left, well away from the window controls and any
                    // AppBar actions that sit beside them. On the shell the
                    // sidebar keeps its top strip clear, so nothing is under it
                    // there either.
                    if (kDebugMode)
                      Positioned(
                        top: top + 8,
                        left: 8,
                        child: const DebugBadge(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
