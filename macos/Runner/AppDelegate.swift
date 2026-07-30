import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var nowPlayingBridge: NowPlayingBridge?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApplication.shared.mainWindow,
       let flutterViewController = window.contentViewController as? FlutterViewController {
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
