import 'package:flutter_test/flutter_test.dart';

import '../tool/stage_runtime.dart' as runtime_stage;
import '../tool/windows_build_common.dart';

void main() {
  test('parses pubspec-style app version for Windows builds', () {
    final version = AppBuildVersion.parse('1.2.3+45');

    expect(version.buildName, '1.2.3');
    expect(version.buildNumber, '45');
    expect(version.displayVersion, '1.2.3+45');
    expect(version.windowsVersion, '1.2.3.45');
  });

  test('pads short numeric versions for Windows resources', () {
    final version = AppBuildVersion.parse('2.7');

    expect(version.buildName, '2.7.0');
    expect(version.buildNumber, '0');
    expect(version.displayVersion, '2.7.0');
    expect(version.windowsVersion, '2.7.0.0');
  });

  test('allows prerelease suffixes for test Windows builds', () {
    final version = AppBuildVersion.parse('2.1.2-hotfix-test+17');

    expect(version.buildName, '2.1.2-hotfix-test');
    expect(version.buildNumber, '17');
    expect(version.displayVersion, '2.1.2-hotfix-test+17');
    expect(version.windowsVersion, '2.1.2.17');
  });

  test('pads short versions before prerelease suffixes', () {
    final version = AppBuildVersion.parse('2.7-hotfix-test');

    expect(version.buildName, '2.7.0-hotfix-test');
    expect(version.buildNumber, '0');
    expect(version.displayVersion, '2.7.0-hotfix-test');
    expect(version.windowsVersion, '2.7.0.0');
  });

  test('macOS runtime staging accepts core release binary names', () {
    final spec = runtime_stage.RuntimeStageSpec.macos;

    expect(
      spec.runtimeFiles.first.sourceNames,
      containsAll(['mayday-core', 'mdhelper']),
    );
    expect(
      spec.runtimeFiles.last.sourceNames,
      containsAll(['maydayctl', 'mdpipectl']),
    );
  });
}
