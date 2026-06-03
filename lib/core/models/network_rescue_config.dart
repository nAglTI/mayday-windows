enum NetworkRescueProfile {
  off,
  stable,
  extreme;

  String get wireValue => switch (this) {
        NetworkRescueProfile.off => 'off',
        NetworkRescueProfile.stable => 'stable',
        NetworkRescueProfile.extreme => 'extreme',
      };

  bool get enabled => this != NetworkRescueProfile.off;

  static NetworkRescueProfile fromWireValue(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'stable' => NetworkRescueProfile.stable,
      'extreme' => NetworkRescueProfile.extreme,
      _ => NetworkRescueProfile.off,
    };
  }

  static bool supportsWireValue(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return true;
    }
    return switch (value) {
      'off' || 'stable' || 'extreme' => true,
      _ => false,
    };
  }
}

class NetworkRescueConfig {
  const NetworkRescueConfig({
    this.profile = NetworkRescueProfile.off,
    this.extraFields = const {},
  });

  final NetworkRescueProfile profile;
  final Map<String, Object?> extraFields;

  bool get enabled => profile.enabled;

  NetworkRescueConfig copyWith({
    NetworkRescueProfile? profile,
    Map<String, Object?>? extraFields,
  }) {
    return NetworkRescueConfig(
      profile: profile ?? this.profile,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
