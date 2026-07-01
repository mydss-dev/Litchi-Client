import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/auto_start.dart';

void main() {
  test('macOS launch agent starts the tenant executable silently', () {
    final plist = AutoStart.macLaunchAgentPlist(
      label: 'com.client.demo.autostart',
      executable: '/Applications/A&B.app/Contents/MacOS/Client',
      silent: true,
    );

    expect(plist, contains('com.client.demo.autostart'));
    expect(plist, contains('/Applications/A&amp;B.app/Contents/MacOS/Client'));
    expect(plist, contains('<string>--silent</string>'));
    expect(plist, contains('<key>RunAtLoad</key>'));
  });

  test('visible startup omits the silent argument on desktop', () {
    final plist = AutoStart.macLaunchAgentPlist(
      label: 'com.client.demo.autostart',
      executable: '/Applications/Client.app/Contents/MacOS/Client',
      silent: false,
    );

    expect(plist, isNot(contains('--silent')));
    expect(
      AutoStart.windowsRunCommand(
        executable: r'C:\Program Files\Client\Client.exe',
        silent: false,
      ),
      r'"C:\Program Files\Client\Client.exe"',
    );
    expect(
      AutoStart.windowsRunCommand(executable: r'C:\Client.exe', silent: true),
      r'"C:\Client.exe" --silent',
    );
  });
}
