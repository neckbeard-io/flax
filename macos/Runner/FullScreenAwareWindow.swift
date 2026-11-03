// Minimize and full screen, made to work from any point in AppKit's
// full-screen cycle.
//
// On macOS flax's maximize button is full screen. AppKit will not minimize a
// full-screen window, and while the full-screen animation runs it ignores
// both miniaturize(_:) and toggleFullScreen(_:), without an error either way.
// So "maximize, then minimize right away" did nothing. Every request goes
// through WindowModeCoordinator instead, which remembers what was last asked
// for and carries it out once the window can: leaving full screen first when
// a minimize needs it.
//
// The coordinator is plain Swift with no AppKit, so every ordering of
// requests and transitions is checked on Linux by
// test/macos/window_mode_coordinator_test.swift. FullScreenAwareWindow, the
// AppKit half, is checked against real windows on a macOS runner by
// test/macos/full_screen_aware_window_probe.swift.

/// Decides what a minimize or full-screen request does, given where the window
/// is in the full-screen cycle. Holds the latest request until the window can
/// carry it out.
struct WindowModeCoordinator {
  enum Phase: Equatable {
    case windowed, entering, fullScreen, exiting
  }

  enum Event: Equatable, CaseIterable {
    case minimizeRequested, toggleFullScreenRequested
    case willEnterFullScreen, didEnterFullScreen, didFailToEnterFullScreen
    case willExitFullScreen, didExitFullScreen, didFailToExitFullScreen
  }

  /// What the window should ask AppKit for. Only ever returned when AppKit
  /// will act on it: never mid-transition, never a minimize in full screen.
  enum Action: Equatable {
    case miniaturize, toggleFullScreen
  }

  private enum Intent: Equatable {
    case minimize
    case fullScreen(Bool)
  }

  private(set) var phase: Phase
  private var intent: Intent?

  init(isFullScreen: Bool) {
    phase = isFullScreen ? .fullScreen : .windowed
  }

  /// Where the window will end up if nothing more is asked. The latest
  /// request decides, and a pending minimize is headed out of full screen;
  /// with none, a transition already under way counts as done.
  var isHeadingFullScreen: Bool {
    switch intent {
    case .fullScreen(let target)?: return target
    case .minimize?: return false
    case nil: return phase == .entering || phase == .fullScreen
    }
  }

  /// Whether a minimize is waiting on full screen to end.
  var isMinimizePending: Bool { intent == .minimize }

  mutating func handle(_ event: Event) -> [Action] {
    switch event {
    case .minimizeRequested:
      intent = .minimize
    case .toggleFullScreenRequested:
      // The latest request wins, a pending minimize included. Pressed twice
      // during one animation, it flips the target back.
      intent = .fullScreen(!isHeadingFullScreen)
    case .willEnterFullScreen:
      phase = .entering
    case .didEnterFullScreen:
      phase = .fullScreen
    case .willExitFullScreen:
      phase = .exiting
    case .didExitFullScreen:
      phase = .windowed
    case .didFailToEnterFullScreen:
      // AppKit said no; asking again would only fail again.
      phase = .windowed
      intent = nil
    case .didFailToExitFullScreen:
      phase = .fullScreen
      intent = nil
    }
    return drive()
  }

  private mutating func drive() -> [Action] {
    guard let want = intent, phase == .windowed || phase == .fullScreen else {
      return []
    }
    switch want {
    case .minimize:
      if phase == .fullScreen { return [.toggleFullScreen] }
      intent = nil
      return [.miniaturize]
    case .fullScreen(let target):
      if (phase == .fullScreen) == target {
        intent = nil
        return []
      }
      return [.toggleFullScreen]
    }
  }
}

#if canImport(AppKit)
import AppKit

/// An NSWindow whose minimize and full-screen requests, from flax's own
/// buttons, the Window and View menus or the keyboard, go through
/// WindowModeCoordinator. MainFlutterWindow is one.
class FullScreenAwareWindow: NSWindow {
  private var coordinator = WindowModeCoordinator(isFullScreen: false)
  private var observers: [NSObjectProtocol] = []

  /// Starts following the window's full-screen transitions. Call once, after
  /// the window exists (awakeFromNib).
  func observeFullScreenTransitions() {
    coordinator = WindowModeCoordinator(isFullScreen: styleMask.contains(.fullScreen))
    let events: [(Notification.Name, WindowModeCoordinator.Event)] = [
      (NSWindow.willEnterFullScreenNotification, .willEnterFullScreen),
      (NSWindow.didEnterFullScreenNotification, .didEnterFullScreen),
      (NSWindow.didFailToEnterFullScreenNotification, .didFailToEnterFullScreen),
      (NSWindow.willExitFullScreenNotification, .willExitFullScreen),
      (NSWindow.didExitFullScreenNotification, .didExitFullScreen),
      (NSWindow.didFailToExitFullScreenNotification, .didFailToExitFullScreen),
    ]
    for (name, event) in events {
      // queue: nil delivers synchronously, so the phase has moved on before
      // toggleFullScreen(_:) returns and nothing can ask for a second toggle.
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: self, queue: nil) {
          [weak self] _ in self?.send(event)
        })
    }
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  override func miniaturize(_ sender: Any?) { send(.minimizeRequested) }

  /// Window > Minimize (Cmd-M). AppKit's own version presses the minimize
  /// button, which flax hides.
  override func performMiniaturize(_ sender: Any?) { send(.minimizeRequested) }

  override func toggleFullScreen(_ sender: Any?) { send(.toggleFullScreenRequested) }

  /// Keep Window > Minimize enabled in full screen, where AppKit greys it out:
  /// the coordinator leaves full screen first.
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(performMiniaturize(_:)) {
      return styleMask.contains(.miniaturizable)
    }
    return super.validateMenuItem(menuItem)
  }

  private func send(_ event: WindowModeCoordinator.Event) {
    for action in coordinator.handle(event) {
      switch action {
      case .miniaturize: super.miniaturize(nil)
      case .toggleFullScreen: super.toggleFullScreen(nil)
      }
    }
  }
}
#endif
