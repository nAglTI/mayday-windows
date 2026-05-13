import 'package:flutter_test/flutter_test.dart';

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
}
