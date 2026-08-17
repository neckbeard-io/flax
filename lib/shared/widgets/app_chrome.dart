import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kBackMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/app/router.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/input/back_swipe.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/shared/input/global_keys.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';
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
    // Fire and forget. A failure here is a no-op: the repository treats an
    // unanswered beacon as "assume changed" and falls back to its TTLs, so a
    // dropped check costs nothing.
    ref.read(libraryRepositoryProvider)?.syncIfChanged();
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

  /// Back, for the mouse button and the trackpad swipe.
  ///
  /// Nothing to pop means we are at the start of the history, where a browser
  /// also does nothing. The router comes from the provider rather than the
  /// context: this widget is MaterialApp.router's builder, which sits *above*
  /// the InheritedGoRouter, so `GoRouter.of(context)` finds nothing here.
  void _goBack() {
    if (!mounted) return;
    final router = ref.read(routerProvider);
    if (router.canPop()) router.pop();
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
    final isDesktop = Platform.isMacOS || Platform.isWindows;

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
                    // Drag strip first, so the buttons above keep their taps.
                    if (Platform.isWindows)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: WindowDragArea(),
                      ),
                    if (isDesktop)
                      Positioned(
                        top: top + 4,
                        right: 4,
                        child: const WindowButtons(),
                      ),
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
