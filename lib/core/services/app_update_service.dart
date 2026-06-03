import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_metadata.dart';
import '../models/app_update_info.dart';

typedef GitHubReleaseLoader = Future<GitHubRelease?> Function();
typedef ReleasePageOpener = Future<void> Function(String url);

class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.draft,
    required this.prerelease,
  });

  factory GitHubRelease.fromJson(Map<String, Object?> json) {
    return GitHubRelease(
      tagName: json['tag_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
    );
  }

  final String tagName;
  final String name;
  final String htmlUrl;
  final bool draft;
  final bool prerelease;
}

class AppUpdateService {
  AppUpdateService({
    this.owner = 'nAglTI',
    this.repository = 'mayday-windows',
    this.releasesPageUrl = MaydayAppMetadata.releasePageUrl,
    Duration timeout = const Duration(seconds: 8),
    GitHubReleaseLoader? releaseLoader,
    ReleasePageOpener? releasePageOpener,
  })  : _timeout = timeout,
        _releaseLoader = releaseLoader,
        _releasePageOpener = releasePageOpener;

  final String owner;
  final String repository;
  final String releasesPageUrl;
  final Duration _timeout;
  final GitHubReleaseLoader? _releaseLoader;
  final ReleasePageOpener? _releasePageOpener;

  Future<AppUpdateInfo?> checkForUpdate({
    String currentVersion = MaydayAppMetadata.version,
  }) async {
    final current = AppVersion.tryParse(currentVersion);
    if (current == null) {
      return null;
    }

    final release = await _loadLatestRelease();
    if (release == null || release.draft || release.prerelease) {
      return null;
    }

    final latest = AppVersion.tryParse(release.tagName);
    if (latest == null || latest.compareTo(current) <= 0) {
      return null;
    }

    return AppUpdateInfo(
      currentVersion: current,
      latestVersion: latest,
      releaseName: release.name.trim().isEmpty
          ? latest.displayVersion
          : release.name.trim(),
      releaseUrl:
          release.htmlUrl.trim().isEmpty ? releasesPageUrl : release.htmlUrl,
    );
  }

  Future<void> openReleasePage(String url) async {
    final opener = _releasePageOpener;
    if (opener != null) {
      await opener(url);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw FormatException('Invalid release URL: $url');
    }

    if (Platform.isWindows) {
      await Process.start(
        'rundll32.exe',
        ['url.dll,FileProtocolHandler', uri.toString()],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    final executable = Platform.isMacOS ? 'open' : 'xdg-open';
    await Process.start(
      executable,
      [uri.toString()],
      mode: ProcessStartMode.detached,
    );
  }

  Future<GitHubRelease?> _loadLatestRelease() {
    final loader = _releaseLoader;
    if (loader != null) {
      return loader();
    }
    return _fetchLatestRelease();
  }

  Future<GitHubRelease?> _fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repository/releases/latest',
    );
    final client = HttpClient()..connectionTimeout = _timeout;

    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'mayday-windows/${MaydayAppMetadata.version}',
      );

      final response = await request.close().timeout(_timeout);
      if (response.statusCode == HttpStatus.notFound) {
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub release check failed with HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final body = await utf8.decodeStream(response).timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return GitHubRelease.fromJson(Map<String, Object?>.from(decoded));
    } finally {
      client.close(force: true);
    }
  }
}
