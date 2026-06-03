class RelayTarget {
  const RelayTarget({
    required this.id,
    required this.addr,
    required this.shortId,
    this.relayKey = '',
    this.transportPorts = const {},
    this.extraFields = const {},
  });

  final String id;
  final String addr;
  final int shortId;
  final String relayKey;
  final Map<String, List<int>> transportPorts;
  final Map<String, Object?> extraFields;

  RelayTarget copyWith({
    String? id,
    String? addr,
    int? shortId,
    String? relayKey,
    Map<String, List<int>>? transportPorts,
    Map<String, Object?>? extraFields,
  }) {
    return RelayTarget(
      id: id ?? this.id,
      addr: addr ?? this.addr,
      shortId: shortId ?? this.shortId,
      relayKey: relayKey ?? this.relayKey,
      transportPorts: transportPorts ?? this.transportPorts,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
