enum SplitTunnelMode {
  disabled,
  onlySelected,
  excludeSelected;

  String? get wireValue {
    switch (this) {
      case SplitTunnelMode.disabled:
        return null;
      case SplitTunnelMode.onlySelected:
        return 'whitelist';
      case SplitTunnelMode.excludeSelected:
        return 'blacklist';
    }
  }

  static SplitTunnelMode fromWireValue(
    String? raw, {
    required bool enabled,
  }) {
    if (!enabled) {
      return SplitTunnelMode.disabled;
    }

    switch (raw?.trim().toLowerCase()) {
      case 'whitelist':
        return SplitTunnelMode.onlySelected;
      case 'blacklist':
        return SplitTunnelMode.excludeSelected;
      default:
        return SplitTunnelMode.disabled;
    }
  }
}
