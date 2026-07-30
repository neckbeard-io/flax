import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  func hideTrafficLights() {
    for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
      if let button = super.standardWindowButton(type) {
        button.isHidden = true
        button.alphaValue = 0
        button.frame = .zero
      }
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

    // Titled for drag support, transparent so it blends with content
    self.styleMask = [.titled, .resizable, .fullSizeContentView]
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    // Hide traffic lights after system creates them
    DispatchQueue.main.async { [weak self] in
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

    super.awakeFromNib()
  }
}
