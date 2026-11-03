// FullScreenAwareWindow (macos/Runner/FullScreenAwareWindow.swift) against
// real AppKit windows, with real animation timing. Needs a macOS session with
// a window server, such as a GitHub macOS runner:
//
//   swiftc -parse-as-library macos/Runner/FullScreenAwareWindow.swift \
//     test/macos/full_screen_aware_window_probe.swift -o /tmp/probe && /tmp/probe
//
// Part 1 checks the AppKit behavior that test/macos/window_mode_coordinator_test.swift
// fakes. If macOS changes it, this fails, and the fake has to follow.
// Part 2 plays every combination of starting state, request, and how far into
// the animation the next request lands, and checks where the window ends up.

import AppKit

func spin(_ seconds: Double) {
  RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

@discardableResult
func waitUntil(_ timeout: Double = 8, _ condition: () -> Bool) -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if condition() { return true }
    spin(0.05)
  }
  return condition()
}

/// Tracks a window's full-screen transitions from its notifications.
final class TransitionLog {
  private(set) var transitioning = false
  private(set) var willEnterCount = 0
  private var observers: [NSObjectProtocol] = []

  init(_ window: NSWindow) {
    let center = NotificationCenter.default
    for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification] {
      observers.append(center.addObserver(forName: name, object: window, queue: nil) { [weak self] n in
        self?.transitioning = true
        if n.name == NSWindow.willEnterFullScreenNotification { self?.willEnterCount += 1 }
      })
    }
    for name in [
      NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
      NSWindow.didFailToEnterFullScreenNotification, NSWindow.didFailToExitFullScreenNotification,
    ] {
      observers.append(center.addObserver(forName: name, object: window, queue: nil) { [weak self] _ in
        self?.transitioning = false
      })
    }
  }

  deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

/// MainFlutterWindow's setup, without Flutter.
final class TestWindow: FullScreenAwareWindow {
  func hideTrafficLights() {
    for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
      super.standardWindowButton(type)?.isHidden = true
    }
  }

  override func becomeKey() {
    super.becomeKey()
    hideTrafficLights()
  }
}

func makeWindow(aware: Bool) -> NSWindow {
  let rect = NSRect(x: 200, y: 200, width: 640, height: 420)
  let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .fullSizeContentView]
  let w: NSWindow = aware
    ? TestWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
    : NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
  w.titlebarAppearsTransparent = true
  w.titleVisibility = .hidden
  w.isReleasedWhenClosed = false
  w.collectionBehavior.insert(.fullScreenPrimary)
  w.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
  spin(0.5)
  return w
}

var failures: [String] = []
var passes = 0

func expect(_ ok: Bool, _ what: String) {
  if ok {
    passes += 1
    print("  ok    \(what)")
  } else {
    failures.append(what)
    print("  FAIL  \(what)")
  }
}

func isFullScreen(_ w: NSWindow) -> Bool { w.styleMask.contains(.fullScreen) }

/// Take a window out of full screen and the Dock, and close it.
func dispose(_ w: NSWindow, _ log: TransitionLog) {
  if w.isMiniaturized { w.deminiaturize(nil); waitUntil { !w.isMiniaturized } }
  waitUntil { !log.transitioning }
  if isFullScreen(w) {
    if let aware = w as? FullScreenAwareWindow { aware.toggleFullScreen(nil) } else { w.toggleFullScreen(nil) }
    waitUntil { !isFullScreen(w) && !log.transitioning }
  }
  w.close()
  spin(0.5)
}

// MARK: - Part 1: what AppKit does, which the Linux test's fake assumes

func appKitFacts() {
  print("AppKit behavior the coordinator relies on:")

  do {
    let w = makeWindow(aware: false)
    let log = TransitionLog(w)
    w.toggleFullScreen(nil)
    expect(log.willEnterCount == 1, "willEnterFullScreen is posted before toggleFullScreen returns")
    w.miniaturize(nil)
    spin(1.5)
    expect(!w.isMiniaturized, "miniaturize during the enter animation is dropped")
    waitUntil { !log.transitioning }
    expect(isFullScreen(w), "the window still reaches full screen")
    w.miniaturize(nil)
    spin(1.5)
    expect(!w.isMiniaturized, "miniaturize in full screen is dropped")
    dispose(w, log)
  }

  do {
    let w = makeWindow(aware: false)
    let log = TransitionLog(w)
    w.toggleFullScreen(nil)
    spin(0.1)
    w.toggleFullScreen(nil)
    waitUntil { !log.transitioning }
    spin(1)
    expect(isFullScreen(w) && log.willEnterCount == 1,
           "toggleFullScreen during the enter animation is dropped")
    dispose(w, log)
  }
}

// MARK: - Part 2: FullScreenAwareWindow, every combination

enum Request: String, CaseIterable {
  case minimizeButton = "minimize button"
  case commandM = "Cmd-M"
  case maximize = "maximize"

  func send(to w: FullScreenAwareWindow) {
    switch self {
    case .minimizeButton: w.miniaturize(nil)  // what the com.flax/window channel calls
    case .commandM: w.performMiniaturize(nil)
    case .maximize: w.toggleFullScreen(nil)
    }
  }
}

/// How long after the first maximize the second request lands.
enum Delay: Double, CaseIterable {
  case immediately = 0
  case earlyInAnimation = 0.1
  case midAnimation = 0.4
  case afterAnimation = -1

  var label: String {
    switch self {
    case .immediately: return "immediately"
    case .earlyInAnimation: return "0.1s in"
    case .midAnimation: return "0.4s in"
    case .afterAnimation: return "after the animation"
    }
  }
}

func combinations() {
  print("FullScreenAwareWindow:")

  // Without full screen: minimize, restore, minimize again.
  for request in [Request.minimizeButton, .commandM] {
    let w = makeWindow(aware: true) as! TestWindow
    w.observeFullScreenTransitions()
    let log = TransitionLog(w)
    var ok = true
    for _ in 1...3 {
      request.send(to: w)
      ok = ok && waitUntil { w.isMiniaturized }
      w.deminiaturize(nil)
      ok = ok && waitUntil { !w.isMiniaturized }
      spin(0.5)
    }
    expect(ok, "windowed: \(request.rawValue), restore, three times over")
    dispose(w, log)
  }

  // Windowed or full screen, maximize, then a second request at each delay.
  for startFullScreen in [false, true] {
    for delay in Delay.allCases {
      for second in Request.allCases {
        let start = startFullScreen ? "from full screen" : "from windowed"
        let name = "\(start): maximize, then \(second.rawValue) \(delay.label)"
        let w = makeWindow(aware: true) as! TestWindow
        w.observeFullScreenTransitions()
        let log = TransitionLog(w)
        if startFullScreen {
          w.toggleFullScreen(nil)
          guard waitUntil({ isFullScreen(w) && !log.transitioning }) else {
            expect(false, "\(name): could not reach full screen to start")
            dispose(w, log)
            continue
          }
          spin(0.5)
        }

        Request.maximize.send(to: w)
        if delay == .afterAnimation {
          waitUntil { !log.transitioning }
          spin(0.3)
        } else {
          spin(delay.rawValue)
        }
        second.send(to: w)

        if second == .maximize {
          // Two flips: back where it started, and not stuck mid-way.
          spin(1)
          let settled = waitUntil(12) { !log.transitioning && isFullScreen(w) == startFullScreen }
          expect(settled && !w.isMiniaturized, name)
        } else {
          let minimized = waitUntil(12) { w.isMiniaturized }
          var again = false
          if minimized {
            // And it keeps working once restored.
            w.deminiaturize(nil)
            waitUntil { !w.isMiniaturized }
            spin(0.5)
            second.send(to: w)
            again = waitUntil(12) { w.isMiniaturized }
          }
          expect(minimized && again && !isFullScreen(w), name + ", then again after restoring")
        }
        dispose(w, log)
      }
    }
  }
}

@main
struct FullScreenAwareWindowProbe {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.finishLaunching()
    app.activate(ignoringOtherApps: true)

    appKitFacts()
    combinations()

    print("\(passes) passed, \(failures.count) failed")
    if !failures.isEmpty {
      failures.forEach { print("FAIL: " + $0) }
      exit(1)
    }
  }
}
