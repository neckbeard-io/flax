import Cocoa
import FlutterMacOS

/// Minimize and full screen go through FullScreenAwareWindow, so minimizing
/// works from full screen and in the middle of its animation.
class MainFlutterWindow: FullScreenAwareWindow {
  /// Hides the native buttons; flax draws its own (window_buttons.dart).
  ///
  /// isHidden only. AppKit disables a button whose alphaValue is 0, and a
  /// window whose minimize button is disabled ignores miniaturize(_:), so
  /// fading the buttons out killed minimize: once the window became key it
  /// would not minimize again until full screen rebuilt the buttons. Checked on
  /// GitHub's macOS 15 and 26 runners; neither isHidden nor a zero frame does it.
  func hideTrafficLights() {
    for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
      super.standardWindowButton(type)?.isHidden = true
    }
  }

  override func becomeKey() {
    super.becomeKey()
    hideTrafficLights()
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Titled for drag support, transparent so it blends with content.
    // .miniaturizable is what lets the window minimize at all: without it
    // miniaturize(_:) silently does nothing, for flax's own button and for
    // Window > Minimize (Cmd-M) alike. The traffic lights stay hidden.
    self.styleMask = [.titled, .resizable, .miniaturizable, .fullSizeContentView]
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    // Hide traffic lights after system creates them
    DispatchQueue.main.async { [weak self] in
      self?.hideTrafficLights()
    }
    observeFullScreenTransitions()
    // Leaving full screen rebuilds them, and the window may already be key.
    NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
    ) { [weak self] _ in
      self?.hideTrafficLights()
    }

    // Match the app's dark background
    self.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
    self.isOpaque = true

    // Window control method channel
    let channel = FlutterMethodChannel(
      name: "com.flax/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let window = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "close":
        NSApp.terminate(nil)
        result(nil)
      case "minimize":
        window.miniaturize(nil)
        result(nil)
      case "toggleFullScreen":
        window.toggleFullScreen(nil)
        result(nil)
      case "isFullScreen":
        let isFull = window.styleMask.contains(.fullScreen)
        result(isFull)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
       appDelegate.nowPlayingBridge == nil {
      appDelegate.nowPlayingBridge = NowPlayingBridge(messenger: flutterViewController.engine.binaryMessenger)
    }
    if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
       appDelegate.audioRouteBridge == nil {
      appDelegate.audioRouteBridge = AudioRouteBridge(messenger: flutterViewController.engine.binaryMessenger)
    }

    super.awakeFromNib()
  }
}
