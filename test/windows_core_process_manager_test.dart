import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/windows_core_process_manager.dart';

void main() {
  group('WindowsCoreProcessManager.buildRunArguments', () {
    test('emits every run flag in order', () {
      final args = WindowsCoreProcessManager.buildRunArguments(
        configPath: r'C:\cfg\core.json',
        workingDirectory: r'C:\data',
        controlPort: 7891,
        token: 'tok',
        parentPid: 4242,
      );

      expect(args[0], 'run');
      expect(
        args,
        containsAllInOrder([
          '--config',
          r'C:\cfg\core.json',
          '--working-directory',
          r'C:\data',
          '--control-port',
          '7891',
          '--token',
          'tok',
          '--parent-pid',
          '4242',
        ]),
      );
    });

    test('parent-pid is always a parseable integer, never "null"', () {
      final args = WindowsCoreProcessManager.buildRunArguments(
        configPath: 'cfg',
        workingDirectory: 'dir',
        controlPort: 7891,
        token: 'tok',
        parentPid: 4242,
      );

      final value = args[args.indexOf('--parent-pid') + 1];
      expect(value, isNot('null'));
      expect(int.tryParse(value), 4242);
    });
  });
}
