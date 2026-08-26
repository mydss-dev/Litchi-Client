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

  /// Cmd+Q / Dock > Quit terminates immediately by default, killing the
  /// in-process sing-box core before the system proxy is restored — proxy-aware
  /// apps then lose the network until the next launch self-heals. Route the
  /// quit through Dart's `_quit()` (MethodChannel "litchi/quit"), which removes
  /// the tray icon, shuts the core down and restores the system proxy before
  /// calling exit(0). The `.terminateLater` reply is never needed on the happy
  /// path — exit(0) ends the process — but a safety timeout forces it so a hung
  /// Dart side cannot leave a headless zombie behind.
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

  private func firstFlutterViewController() -> FlutterViewController? {
    return NSApp.windows
      .compactMap { $0.contentViewController as? FlutterViewController }
      .first
  }
}
