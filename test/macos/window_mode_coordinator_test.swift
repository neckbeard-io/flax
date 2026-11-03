// Exhaustive test of WindowModeCoordinator (macos/Runner/FullScreenAwareWindow.swift).
//
// Plain Swift, no AppKit, so it runs on Linux:
//
//   swiftc -parse-as-library macos/Runner/FullScreenAwareWindow.swift \
//     test/macos/window_mode_coordinator_test.swift -o /tmp/wmc && /tmp/wmc
//
// The coordinator is driven by a fake window that does what AppKit does with
// each call: it drops a minimize in full screen, drops any call made while
// the full-screen animation runs, and drops a toggle made while a window that
// has just finished a transition settles. Every sequence of user requests and AppKit
// outcomes up to `maxDepth` steps is played, and each must end where the user
// expects, without the coordinator ever making a call AppKit would drop.
//
// The fake's rules are what AppKit was measured doing on GitHub's macOS
// runners by test/macos/full_screen_aware_window_probe.swift, which also plays
// the same requests against real windows.

/// What AppKit does with a window's minimize and full-screen calls.
struct FakeAppKitWindow {
  enum Phase { case windowed, entering, fullScreen, exiting }

  var phase: Phase
  var minimized = false
  /// Just finished a transition: toggles are dropped until it settles.
  var settling = false
  /// FullScreenAwareWindow has a `.retry` timer running.
  var retryPending = false
  /// Calls AppKit would silently drop and the coordinator cannot detect. It
  /// must never make one. (A dropped toggle is detected and retried.)
  var dropped: [String] = []
  var coordinator: WindowModeCoordinator

  init(fullScreen: Bool) {
    phase = fullScreen ? .fullScreen : .windowed
    coordinator = WindowModeCoordinator(isFullScreen: fullScreen)
  }

  var isTransitioning: Bool { phase == .entering || phase == .exiting }

  /// FullScreenAwareWindow.send(_:), with AppKit replaced by this fake.
  mutating func send(_ event: WindowModeCoordinator.Event) {
    for action in coordinator.handle(event) {
      switch action {
      case .miniaturize:
        miniaturize()
      case .toggleFullScreen:
        let before = coordinator.phase
        toggleFullScreen()
        if coordinator.phase == before { send(.toggleFullScreenDropped) }
      case .scheduleRetry:
        retryPending = true
      }
    }
  }

  mutating func fireRetry() {
    retryPending = false
    send(.retry)
  }

  private mutating func miniaturize() {
    guard phase == .windowed else {
      dropped.append("miniaturize while \(phase)")
      return
    }
    minimized = true
  }

  /// AppKit posts the will-notification before toggleFullScreen(_:) returns.
  private mutating func toggleFullScreen() {
    guard !minimized else {
      dropped.append("toggleFullScreen while minimized")
      return
    }
    if settling { return }  // dropped, and detected by the caller
    switch phase {
    case .windowed:
      phase = .entering
      send(.willEnterFullScreen)
    case .fullScreen:
      phase = .exiting
      send(.willExitFullScreen)
    case .entering, .exiting:
      dropped.append("toggleFullScreen while \(phase)")
    }
  }

  /// The running animation ends, as asked or refused.
  mutating func finishTransition(failed: Bool) {
    switch (phase, failed) {
    case (.entering, false):
      phase = .fullScreen
      settling = true
      send(.didEnterFullScreen)
    case (.entering, true):
      phase = .windowed
      send(.didFailToEnterFullScreen)
    case (.exiting, false):
      phase = .windowed
      settling = true
      send(.didExitFullScreen)
    case (.exiting, true):
      phase = .fullScreen
      send(.didFailToExitFullScreen)
    default:
      fatalError("no transition to finish")
    }
  }

  /// Clicking the window in the Dock. AppKit does this itself; the
  /// coordinator is not involved.
  mutating func restore() { minimized = false }
}

/// One thing that can happen next.
enum Step: CaseIterable, CustomStringConvertible {
  case minimize, maximize, animationEnds, animationFails, settles, retryFires, restoreFromDock

  var description: String {
    switch self {
    case .minimize: return "minimize"
    case .maximize: return "maximize"
    case .animationEnds: return "animation ends"
    case .animationFails: return "animation fails"
    case .settles: return "window settles"
    case .retryFires: return "retry fires"
    case .restoreFromDock: return "restore from Dock"
    }
  }
}

/// What the user expects, written without reference to the coordinator.
struct Expectation {
  /// Where the window should end up: each maximize flips it, a minimize
  /// leaves full screen, and a refused animation leaves it where it stopped.
  var fullScreen: Bool
  var minimized = false

  mutating func apply(_ step: Step, window: FakeAppKitWindow) {
    switch step {
    case .minimize: fullScreen = false; minimized = true
    case .maximize: fullScreen.toggle(); minimized = false
    case .animationEnds, .settles, .retryFires: break
    case .animationFails:
      // AppKit refused, so nothing waits on it any more. `window` is as it
      // was before the step: a refused exit stays in full screen.
      fullScreen = window.phase == .exiting
      minimized = false
    case .restoreFromDock: minimized = false
    }
  }
}

@main
struct WindowModeCoordinatorTest {
  static let maxDepth = 9
  static var sequences = 0
  static var failures: [String] = []

  static func main() {
    namedScenarios()
    for start in [false, true] {
      explore(
        FakeAppKitWindow(fullScreen: start), Expectation(fullScreen: start),
        path: [start ? "start in full screen" : "start windowed"], depth: 0)
    }
    print("\(sequences) sequences explored, up to \(maxDepth) steps each")
    if failures.isEmpty {
      print("PASS")
    } else {
      print("FAIL: \(failures.count) sequences")
      failures.prefix(20).forEach { print("  " + $0) }
      exit(1)
    }
  }

  /// Steps that can happen from here. Nobody can press flax's buttons while
  /// the window is in the Dock, and an animation only ends if one runs.
  static func possibleSteps(_ w: FakeAppKitWindow) -> [Step] {
    Step.allCases.filter { step in
      switch step {
      case .minimize, .maximize: return !w.minimized
      case .animationEnds, .animationFails: return w.isTransitioning
      case .settles: return w.settling && !w.isTransitioning
      case .retryFires: return w.retryPending
      case .restoreFromDock: return w.minimized
      }
    }
  }

  static func play(_ step: Step, on w: inout FakeAppKitWindow) {
    switch step {
    case .minimize: w.send(.minimizeRequested)
    case .maximize: w.send(.toggleFullScreenRequested)
    case .animationEnds: w.finishTransition(failed: false)
    case .animationFails: w.finishTransition(failed: true)
    case .settles: w.settling = false
    case .retryFires: w.fireRetry()
    case .restoreFromDock: w.restore()
    }
  }

  static func explore(
    _ window: FakeAppKitWindow, _ expected: Expectation, path: [String], depth: Int
  ) {
    check(window, expected, path: path)
    guard depth < maxDepth else { return }
    for step in possibleSteps(window) {
      var w = window
      var e = expected
      e.apply(step, window: w)
      play(step, on: &w)
      explore(w, e, path: path + [step.description], depth: depth + 1)
    }
  }

  /// Let every animation finish, the window settle and retries fire, then
  /// compare with what the user expects.
  static func settle(_ w: inout FakeAppKitWindow) -> Bool {
    for _ in 0..<20 {
      if w.isTransitioning {
        w.finishTransition(failed: false)
      } else if w.settling {
        w.settling = false
      } else if w.retryPending {
        w.fireRetry()
      } else {
        return true
      }
    }
    return false
  }

  static func check(_ window: FakeAppKitWindow, _ expected: Expectation, path: [String]) {
    sequences += 1
    var w = window
    guard settle(&w) else {
      failures.append("never settles: " + path.joined(separator: " → "))
      return
    }
    var problems: [String] = []
    if !w.dropped.isEmpty { problems.append("AppKit would drop: \(w.dropped)") }
    if w.minimized != expected.minimized {
      problems.append(expected.minimized ? "not minimized" : "minimized")
    }
    if !w.minimized && (w.phase == .fullScreen) != expected.fullScreen {
      problems.append(expected.fullScreen ? "not in full screen" : "still in full screen")
    }
    if w.coordinator.isMinimizePending {
      problems.append("a minimize is still waiting")
    }
    if !problems.isEmpty {
      failures.append(path.joined(separator: " → ") + ": " + problems.joined(separator: ", "))
    }
  }

  /// The cases seen on a real Mac, spelled out.
  static func namedScenarios() {
    func run(_ name: String, from fullScreen: Bool = false, _ steps: [Step],
             minimized: Bool, inFullScreen: Bool) {
      var w = FakeAppKitWindow(fullScreen: fullScreen)
      for step in steps {
        // A step written for a later moment waits for the window, as a user
        // does: it settles, and pending retries fire, until the step can happen.
        while !possibleSteps(w).contains(step) && !w.isTransitioning && (w.settling || w.retryPending) {
          if w.settling { w.settling = false } else { w.fireRetry() }
        }
        if !possibleSteps(w).contains(step) && step != .animationEnds && step != .animationFails {
          _ = settle(&w)
        }
        guard possibleSteps(w).contains(step) else {
          failures.append("\(name): cannot \(step) with phase=\(w.phase) minimized=\(w.minimized)")
          return
        }
        play(step, on: &w)
      }
      _ = settle(&w)
      if w.minimized != minimized || (!w.minimized && (w.phase == .fullScreen) != inFullScreen)
        || !w.dropped.isEmpty
      {
        failures.append("\(name): minimized=\(w.minimized) phase=\(w.phase) dropped=\(w.dropped)")
      }
    }
    run("minimize", [.minimize], minimized: true, inFullScreen: false)
    run("minimize, restore, minimize", [.minimize, .restoreFromDock, .minimize],
        minimized: true, inFullScreen: false)
    run("maximize, then minimize right away", [.maximize, .minimize],
        minimized: true, inFullScreen: false)
    run("minimize as the window finishes entering full screen",
        [.maximize, .animationEnds, .minimize], minimized: true, inFullScreen: false)
    run("maximize, wait, minimize", [.maximize, .animationEnds, .minimize],
        minimized: true, inFullScreen: false)
    run("maximize, minimize, restore, minimize",
        [.maximize, .animationEnds, .minimize, .animationEnds, .restoreFromDock, .minimize],
        minimized: true, inFullScreen: false)
    run("leave full screen, then minimize right away", from: true, [.maximize, .minimize],
        minimized: true, inFullScreen: false)
    run("maximize twice quickly", [.maximize, .maximize], minimized: false, inFullScreen: false)
    run("minimize from full screen, then change mind", from: true, [.minimize, .maximize],
        minimized: false, inFullScreen: true)
  }
}

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
