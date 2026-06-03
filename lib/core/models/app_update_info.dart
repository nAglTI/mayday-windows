class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;

  static AppVersion? tryParse(String value) {
    final match = RegExp(
      r'(^|[^\d])(\d+)\.(\d+)(?:\.(\d+))?(?:\+(\d+))?',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    int parseGroup(int index, {int defaultValue = 0}) {
      final raw = match.group(index);
      if (raw == null || raw.isEmpty) {
        return defaultValue;
      }
      return int.parse(raw);
    }

    return AppVersion(
      major: parseGroup(2),
      minor: parseGroup(3),
      patch: parseGroup(4),
      buildNumber: parseGroup(5),
    );
  }

  String get displayVersion {
    final version = '$major.$minor.$patch';
    return buildNumber == 0 ? version : '$version+$buildNumber';
  }

  @override
  int compareTo(AppVersion other) {
    final left = [major, minor, patch, buildNumber];
    final right = [other.major, other.minor, other.patch, other.buildNumber];
    for (var index = 0; index < left.length; index += 1) {
      final comparison = left[index].compareTo(right[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  @override
  String toString() => displayVersion;

  @override
  bool operator ==(Object other) {
    return other is AppVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        buildNumber == other.buildNumber;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseUrl,
  });

  final AppVersion currentVersion;
  final AppVersion latestVersion;
  final String releaseName;
  final String releaseUrl;
}
