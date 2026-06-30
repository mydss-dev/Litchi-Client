import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_launch_options.dart';

void main() {
  test('recognizes silent launch aliases case-insensitively', () {
    expect(AppLaunchOptions.parse(['--silent']).silent, isTrue);
    expect(AppLaunchOptions.parse([' --START-MINIMIZED ']).silent, isTrue);
    expect(AppLaunchOptions.parse(const []).silent, isFalse);
  });
}
