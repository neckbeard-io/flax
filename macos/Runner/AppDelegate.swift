import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var nowPlayingBridge: NowPlayingBridge?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let window = NSApplication.shared.windows.first ?? NSApplication.shared.mainWindow
    if let flutterViewController = window?.contentViewController as? FlutterViewController,
       nowPlayingBridge == nil {
      nowPlayingBridge = NowPlayingBridge(messenger: flutterViewController.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
