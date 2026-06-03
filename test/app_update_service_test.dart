import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/app_metadata.dart';
import 'package:mayday_windows/core/models/app_update_info.dart';
import 'package:mayday_windows/core/services/app_update_service.dart';

void main() {
  test('debug default app version mirrors pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(MaydayAppMetadata.version, version);
  });

  test('app version parser accepts release tags and build metadata', () {
    expect(
      AppVersion.tryParse('v2.1.0+4'),
      const AppVersion(major: 2, minor: 1, patch: 0, buildNumber: 4),
    );
    expect(
      AppVersion.tryParse('mayday-windows-3.2'),
      const AppVersion(major: 3, minor: 2, patch: 0, buildNumber: 0),
    );
    expect(AppVersion.tryParse('release-2026'), isNull);
  });

  test('returns update info when latest GitHub release is newer', () async {
    final service = AppUpdateService(
      releaseLoader: () async => const GitHubRelease(
        tagName: 'v2.2.0',
        name: 'Mayday 2.2.0',
        htmlUrl: 'https://github.com/nAglTI/mayday-windows/releases/tag/v2.2.0',
        draft: false,
        prerelease: false,
      ),
    );

    final update = await service.checkForUpdate(currentVersion: '2.1.0+1');

    expect(update, isNotNull);
    expect(update!.latestVersion.displayVersion, '2.2.0');
    expect(update.releaseName, 'Mayday 2.2.0');
  });

  test('ignores same, older, draft, and prerelease GitHub releases', () async {
    Future<AppUpdateInfo?> check(GitHubRelease release) {
      return AppUpdateService(releaseLoader: () async => release)
          .checkForUpdate(currentVersion: '2.1.0+1');
    }

    expect(
      await check(
        const GitHubRelease(
          tagName: 'v2.1.0',
          name: '',
          htmlUrl: '',
          draft: false,
          prerelease: false,
        ),
      ),
      isNull,
    );
    expect(
      await check(
        const GitHubRelease(
          tagName: 'v2.0.9',
          name: '',
          htmlUrl: '',
          draft: false,
          prerelease: false,
        ),
      ),
      isNull,
    );
    expect(
      await check(
        const GitHubRelease(
          tagName: 'v2.2.0',
          name: '',
          htmlUrl: '',
          draft: true,
          prerelease: false,
        ),
      ),
      isNull,
    );
    expect(
      await check(
        const GitHubRelease(
          tagName: 'v2.2.0',
          name: '',
          htmlUrl: '',
          draft: false,
          prerelease: true,
        ),
      ),
      isNull,
    );
  });

  test('opens release page through injected opener', () async {
    String? openedUrl;
    final service = AppUpdateService(
      releasePageOpener: (url) async {
        openedUrl = url;
      },
    );

    await service.openReleasePage(
      'https://github.com/nAglTI/mayday-windows/releases',
    );

    expect(openedUrl, 'https://github.com/nAglTI/mayday-windows/releases');
  });
}
