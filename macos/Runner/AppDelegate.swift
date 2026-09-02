import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    installCloseWindowMenuItemIfNeeded()
  }

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

  /// Flutter's stock macOS menu in this project has Minimize/Zoom but no Close
  /// item. Add the standard Cmd+W command and leave its target nil so AppKit
  /// routes `performClose:` through the key window. window_manager's
  /// `setPreventClose(true)` then hands the close request to Dart's existing
  /// hide-to-tray / full-quit policy rather than bypassing cleanup.
  private func installCloseWindowMenuItemIfNeeded() {
    guard let menu = NSApp.windowsMenu else { return }
    let closeSelector = Selector(("performClose:"))
    if menu.items.contains(where: { $0.action == closeSelector }) {
      return
    }

    let closeItem = NSMenuItem(
      title: "Close",
      action: closeSelector,
      keyEquivalent: "w"
    )
    closeItem.keyEquivalentModifierMask = [.command]
    closeItem.target = nil
    menu.insertItem(closeItem, at: 0)
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
