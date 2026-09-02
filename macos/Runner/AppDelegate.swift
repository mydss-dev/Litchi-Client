import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Dock-click / app re-open should always bring an existing tray-hidden or
  /// minimized Flutter window back to the foreground. This complements Dart's
  /// windowManager.hide() behavior without creating a second NSWindow.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if let window = mainFlutterWindow() {
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.makeKeyAndOrderFront(nil)
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  /// Cmd+Q / Dock > Quit terminates immediately by default, killing the
  /// in-process sing-box core before the system proxy is restored. Route the
  /// quit through Dart's `_quit()` cleanup path first.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let controller = firstFlutterViewController() else {
      return .terminateNow
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    let channel = FlutterMethodChannel(
      name: "litchi/quit",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod("quit", arguments: nil)
    return .terminateLater
  }

  private func mainFlutterWindow() -> NSWindow? {
    return NSApp.windows.first { window in
      window.contentViewController is FlutterViewController
    }
  }

  private func firstFlutterViewController() -> FlutterViewController? {
    return mainFlutterWindow()?.contentViewController as? FlutterViewController
  }
}
